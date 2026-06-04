import Foundation
import CryptoKit
import ICherriProtocol

// Manages the full lifecycle of a resumable upload: init → chunk send → (resume on abort) → commit.
public actor ResumableUploadManager {
    private final class PreparedVideoStreamBox: @unchecked Sendable {
        let stream: InputStream

        init(stream: InputStream) {
            self.stream = stream
        }
    }

    private enum PreparedUpload {
        case image(data: Data, metadata: AssetMetadata, contentHash: String)
        case video(streamBox: PreparedVideoStreamBox, metadata: AssetMetadata, contentHash: String)
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
        metadata: AssetMetadata
    ) async throws -> UploadResult {
        let preparedUpload = try await prepareUpload(assetLocalID: assetLocalID, metadata: metadata)
        switch preparedUpload {
        case .image(let data, let normalizedMetadata, let contentHash):
            return try await uploadPreparedImage(
                assetLocalID: assetLocalID,
                data: data,
                metadata: normalizedMetadata,
                contentHash: contentHash
            )
        case .video(let streamBox, let normalizedMetadata, let contentHash):
            return try await uploadPreparedVideo(
                assetLocalID: assetLocalID,
                stream: streamBox.stream,
                metadata: normalizedMetadata,
                contentHash: contentHash
            )
        }
    }

    private func prepareUpload(assetLocalID: String, metadata: AssetMetadata) async throws -> PreparedUpload {
        if metadata.mediaType == .video {
            let (stream, totalSize) = try await scanner.openInputStreamWithSize(for: assetLocalID)
            let contentHash = try await hashStream(assetLocalID: assetLocalID)
            let normalizedMetadata = normalized(from: metadata, byteSize: totalSize)
            return .video(streamBox: PreparedVideoStreamBox(stream: stream), metadata: normalizedMetadata, contentHash: contentHash)
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
        contentHash: String
    ) async throws -> UploadResult {
        let (uploadID, startOffset, chunkSize) = try await initOrResumeSession(metadata: metadata)
        try await chunkSender.send(
            data: data,
            uploadID: uploadID,
            chunkSize: chunkSize,
            startingOffset: startOffset
        )
        return try await commitAndReturn(uploadID: uploadID, assetLocalID: assetLocalID, metadata: metadata, contentHash: contentHash)
    }

    private func uploadPreparedVideo(
        assetLocalID: String,
        stream: InputStream,
        metadata: AssetMetadata,
        contentHash: String
    ) async throws -> UploadResult {
        let (uploadID, startOffset, chunkSize) = try await initOrResumeSession(metadata: metadata)
        try await chunkSender.send(
            stream: stream,
            uploadID: uploadID,
            totalSize: metadata.byteSize,
            chunkSize: chunkSize,
            startingOffset: startOffset
        )
        return try await commitAndReturn(uploadID: uploadID, assetLocalID: assetLocalID, metadata: metadata, contentHash: contentHash)
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

    private func commitAndReturn(uploadID: String, assetLocalID: String, metadata: AssetMetadata, contentHash: String) async throws -> UploadResult {

        // Commit
        let commitResponse = try await backupClient.commitUpload(
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

    private func initOrResumeSession(metadata: AssetMetadata) async throws -> (uploadID: String, startOffset: Int64, chunkSize: Int) {
        // Try to find an existing paused session
        let initResponse = try await backupClient.initUpload(asset: metadata, filename: metadata.originalFilename)

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

public enum ResumableUploadError: Error {
    case commitFailed(String)
    case sessionExpired
}
