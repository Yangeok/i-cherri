import Foundation
import CryptoKit
import ICherriProtocol

// Manages the full lifecycle of a resumable upload: init → chunk send → (resume on abort) → commit.
public actor ResumableUploadManager {
    enum UploadRecoveryDisposition: Equatable {
        case retrySameOffset
        case resumeFrom(Int64)
        case uploadFinished
    }

    private enum PreparedUpload {
        case image(data: Data, metadata: AssetMetadata, contentHash: String)
        case video(metadata: AssetMetadata, contentHash: String)
    }

    private let backupClient: BackupClient
    private let chunkSender: ChunkUploadSender
    private let scanner: PhotoLibraryScanner

    public init(backupClient: BackupClient, chunkSender: ChunkUploadSender, scanner: PhotoLibraryScanner) {
        self.backupClient = backupClient
        self.chunkSender = chunkSender
        self.scanner = scanner
    }

    public struct UploadResult: Sendable {
        public let assetLocalID: String
        public let backupID: String
        public let displayPath: String
    }

    // Performs a full upload with automatic resumption if interrupted.
    public func upload(
        assetLocalID: String,
        metadata: AssetMetadata,
        backupRunContext: AutoBackupRunContext? = nil
    ) async throws -> UploadResult {
        defer {
            Task {
                await PrehashCache.shared.remove(for: assetLocalID)
            }
        }
        let preparedUpload = try await prepareUpload(assetLocalID: assetLocalID, metadata: metadata)
        switch preparedUpload {
        case .image(let data, let normalizedMetadata, let contentHash):
            return try await uploadPreparedImage(
                assetLocalID: assetLocalID,
                data: data,
                metadata: normalizedMetadata,
                contentHash: contentHash,
                backupRunContext: backupRunContext
            )
        case .video(let normalizedMetadata, let contentHash):
            return try await uploadPreparedVideo(
                assetLocalID: assetLocalID,
                metadata: normalizedMetadata,
                contentHash: contentHash,
                backupRunContext: backupRunContext
            )
        }
    }

    private func prepareUpload(assetLocalID: String, metadata: AssetMetadata) async throws -> PreparedUpload {
        // Try to retrieve pre-hashed cache first
        if let cachedHash = await PrehashCache.shared.getHash(for: assetLocalID) {
            if metadata.mediaType == .video {
                let (_, totalSize) = try await scanner.openInputStreamWithSize(for: assetLocalID)
                let normalizedMetadata = normalized(from: metadata, byteSize: totalSize)
                return .video(metadata: normalizedMetadata, contentHash: cachedHash)
            } else if let cachedData = await PrehashCache.shared.getData(for: assetLocalID) {
                let normalizedMetadata = normalized(from: metadata, byteSize: Int64(cachedData.count))
                return .image(data: cachedData, metadata: normalizedMetadata, contentHash: cachedHash)
            }
        }

        // Fallback: If not cached, compute hash synchronously
        if metadata.mediaType == .video {
            let (_, totalSize) = try await scanner.openInputStreamWithSize(for: assetLocalID)
            let contentHash = try await hashStream(assetLocalID: assetLocalID)
            let normalizedMetadata = normalized(from: metadata, byteSize: totalSize)
            return .video(metadata: normalizedMetadata, contentHash: contentHash)
        }

        let data = try await scanner.fetchData(for: assetLocalID)
        let contentHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let normalizedMetadata = normalized(from: metadata, byteSize: Int64(data.count))
        return .image(data: data, metadata: normalizedMetadata, contentHash: contentHash)
    }

    private func uploadPreparedImage(
        assetLocalID: String,
        data: Data,
        metadata: AssetMetadata,
        contentHash: String,
        backupRunContext: AutoBackupRunContext?
    ) async throws -> UploadResult {
        let (uploadID, startOffset, chunkSize) = try await initOrResumeSession(
            metadata: metadata,
            backupRunContext: backupRunContext
        )
        try await sendWithRecovery(
            uploadID: uploadID,
            initialOffset: startOffset,
            totalSize: Int64(data.count)
        ) { offset in
            try await self.chunkSender.send(
                data: data,
                uploadID: uploadID,
                chunkSize: chunkSize,
                startingOffset: offset
            )
        }
        return try await commitAndReturn(
            uploadID: uploadID,
            assetLocalID: assetLocalID,
            metadata: metadata,
            contentHash: contentHash,
            backupRunContext: backupRunContext
        )
    }

    private func uploadPreparedVideo(
        assetLocalID: String,
        metadata: AssetMetadata,
        contentHash: String,
        backupRunContext: AutoBackupRunContext?
    ) async throws -> UploadResult {
        let (uploadID, startOffset, chunkSize) = try await initOrResumeSession(
            metadata: metadata,
            backupRunContext: backupRunContext
        )
        try await sendWithRecovery(
            uploadID: uploadID,
            initialOffset: startOffset,
            totalSize: metadata.byteSize
        ) { offset in
            let (stream, _) = try await self.scanner.openInputStreamWithSize(for: assetLocalID)
            try await self.chunkSender.send(
                stream: stream,
                uploadID: uploadID,
                totalSize: metadata.byteSize,
                chunkSize: chunkSize,
                startingOffset: offset
            )
        }
        return try await commitAndReturn(
            uploadID: uploadID,
            assetLocalID: assetLocalID,
            metadata: metadata,
            contentHash: contentHash,
            backupRunContext: backupRunContext
        )
    }

    private func normalized(from metadata: AssetMetadata, byteSize: Int64) -> AssetMetadata {
        AssetMetadata(
            deviceID: metadata.deviceID,
            assetLocalID: metadata.assetLocalID,
            originalFilename: metadata.originalFilename,
            mediaType: metadata.mediaType,
            creationDate: metadata.creationDate,
            modificationDate: metadata.modificationDate,
            byteSize: byteSize,
            pixelWidth: metadata.pixelWidth,
            pixelHeight: metadata.pixelHeight,
            quickFingerprint: FingerprintBuilder.build(
                creationDate: metadata.creationDate,
                modificationDate: metadata.modificationDate,
                byteSize: byteSize,
                pixelWidth: metadata.pixelWidth,
                pixelHeight: metadata.pixelHeight,
                durationSeconds: metadata.durationSeconds
            ),
            durationSeconds: metadata.durationSeconds
        )
    }

    private func commitAndReturn(
        uploadID: String,
        assetLocalID: String,
        metadata: AssetMetadata,
        contentHash: String,
        backupRunContext: AutoBackupRunContext?
    ) async throws -> UploadResult {

        // Commit
        let commitResponse = try await backupClient.commitUpload(
            backupRunContext: backupRunContext,
            uploadID: uploadID,
            assetLocalID: assetLocalID,
            finalByteSize: metadata.byteSize,
            finalContentHash: contentHash
        )

        guard let backupID = commitResponse.backupID, let displayPath = commitResponse.displayPath else {
            throw ResumableUploadError.commitFailed(commitResponse.status)
        }

        return UploadResult(assetLocalID: assetLocalID, backupID: backupID, displayPath: displayPath)
    }

    // MARK: - Private

    private func initOrResumeSession(
        metadata: AssetMetadata,
        backupRunContext: AutoBackupRunContext?
    ) async throws -> (uploadID: String, startOffset: Int64, chunkSize: Int) {
        // Try to find an existing paused session
        let initResponse = try await backupClient.initUpload(
            backupRunContext: backupRunContext,
            asset: metadata,
            filename: metadata.originalFilename
        )

        // If already received some bytes (server reused session), resume from there
        if initResponse.receivedBytes > 0 {
            return (initResponse.uploadID, initResponse.receivedBytes, initResponse.chunkSize)
        }

        // Check if server has partial data for a previous session with same asset
        do {
            let status = try await backupClient.uploadStatus(uploadID: initResponse.uploadID)
            if status.status == "receiving" || status.status == "paused", status.receivedBytes > 0 {
                return (initResponse.uploadID, status.receivedBytes, initResponse.chunkSize)
            }
        } catch {
            // No prior session found — start fresh
        }

        return (initResponse.uploadID, 0, initResponse.chunkSize)
    }

    private func sendWithRecovery(
        uploadID: String,
        initialOffset: Int64,
        totalSize: Int64,
        sendOperation: @escaping @Sendable (Int64) async throws -> Void
    ) async throws {
        var currentOffset = initialOffset
        var recoveryAttempts = 0
        let maxRecoveryAttempts = 4

        while true {
            do {
                try await sendOperation(currentOffset)
                return
            } catch {
                guard recoveryAttempts < maxRecoveryAttempts else {
                    throw error
                }

                let disposition = try await recoverDisposition(
                    uploadID: uploadID,
                    currentOffset: currentOffset,
                    totalSize: totalSize,
                    underlyingError: error
                )
                recoveryAttempts += 1
                switch disposition {
                case .retrySameOffset:
                    continue
                case .resumeFrom(let recoveredOffset):
                    currentOffset = recoveredOffset
                case .uploadFinished:
                    return
                }
            }
        }
    }

    private func recoverDisposition(
        uploadID: String,
        currentOffset: Int64,
        totalSize: Int64,
        underlyingError: Error
    ) async throws -> UploadRecoveryDisposition {
        let status: UploadStatusResponse
        do {
            status = try await backupClient.uploadStatus(uploadID: uploadID)
        } catch let BackupClientError.httpError(statusCode, _) where statusCode == 410 {
            throw ResumableUploadError.sessionExpired
        } catch {
            throw underlyingError
        }

        return try Self.recoveryDisposition(
            currentOffset: currentOffset,
            totalSize: totalSize,
            status: status,
            underlyingError: underlyingError
        )
    }

    static func recoveryDisposition(
        currentOffset: Int64,
        totalSize: Int64,
        status: UploadStatusResponse,
        underlyingError: Error,
        now: Date = Date()
    ) throws -> UploadRecoveryDisposition {
        if status.status == "expired" || status.expiresAt <= now {
            throw ResumableUploadError.sessionExpired
        }
        if status.receivedBytes >= totalSize {
            return .uploadFinished
        }
        if status.receivedBytes > currentOffset {
            return .resumeFrom(status.receivedBytes)
        }
        if status.receivedBytes < currentOffset {
            throw underlyingError
        }
        if isConflictError(underlyingError) {
            throw underlyingError
        }
        return .retrySameOffset
    }

    private static func isConflictError(_ error: Error) -> Bool {
        if case ChunkUploadError.serverError(let statusCode) = error {
            return statusCode == 409
        }
        if case BackupClientError.httpError(let statusCode, _) = error {
            return statusCode == 409
        }
        return false
    }

    private func hashStream(assetLocalID: String) async throws -> String {
        let (stream, _) = try await scanner.openInputStreamWithSize(for: assetLocalID)
        stream.open()
        defer { stream.close() }
        var hasher = SHA256()
        let bufSize = 65536
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buf.deallocate() }
        while stream.hasBytesAvailable {
            let n = stream.read(buf, maxLength: bufSize)
            guard n > 0 else { break }
            hasher.update(data: Data(bytes: buf, count: n))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

public enum ResumableUploadError: Error, Equatable, Sendable {
    case commitFailed(String)
    case sessionExpired
}

public actor PrehashCache {
    public static let shared = PrehashCache()
    private init() {}
    
    private var hashes: [String: String] = [:]
    private var dataCache: [String: Data] = [:]
    
    public func setHash(_ hash: String, for assetID: String) {
        hashes[assetID] = hash
    }
    
    public func getHash(for assetID: String) -> String? {
        hashes[assetID]
    }
    
    public func setData(_ data: Data, for assetID: String) {
        dataCache[assetID] = data
    }
    
    public func getData(for assetID: String) -> Data? {
        dataCache[assetID]
    }
    
    public func remove(for assetID: String) {
        hashes.removeValue(forKey: assetID)
        dataCache.removeValue(forKey: assetID)
    }
    
    public func isFull() -> Bool {
        // Limit to 2 concurrent image datas in memory to prevent OOM
        return dataCache.count >= 2
    }
}
