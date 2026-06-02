import Foundation
import ICherriProtocol

// Sends a single file to the receiver in sequential fixed-size chunks over local HTTP.
public actor ChunkUploadSender {
    private let receiverBaseURL: URL
    private let device: DeviceInfo
    private let trustToken: String?
    private let session: URLSession

    public weak var progressDelegate: ChunkUploadProgressDelegate?

    public init(receiverBaseURL: URL, device: DeviceInfo, trustToken: String? = nil) {
        self.receiverBaseURL = receiverBaseURL
        self.device = device
        self.trustToken = trustToken
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: config)
    }

    public func setProgressDelegate(_ delegate: ChunkUploadProgressDelegate?) {
        self.progressDelegate = delegate
    }

    // Uploads from data in memory (small files).
    public func send(
        data: Data,
        uploadID: String,
        chunkSize: Int,
        startingOffset: Int64 = 0
    ) async throws {
        let totalSize = Int64(data.count)
        var offset = startingOffset
        var chunkIndex = Int(offset / Int64(chunkSize))

        await progressDelegate?.didSendBytes(0, totalSent: offset, totalExpected: totalSize)

        while offset < totalSize {
            let end = min(offset + Int64(chunkSize), totalSize)
            let chunk = data[Int(offset)..<Int(end)]
            try await uploadChunk(Data(chunk), uploadID: uploadID, index: chunkIndex, offset: offset, total: totalSize)
            offset = end
            chunkIndex += 1
            await progressDelegate?.didSendBytes(Int64(chunk.count), totalSent: offset, totalExpected: totalSize)
        }
    }

    // Uploads from an InputStream for large files without loading all data into memory.
    public func send(
        stream: InputStream,
        uploadID: String,
        totalSize: Int64,
        chunkSize: Int,
        startingOffset: Int64 = 0
    ) async throws {
        stream.open()
        defer { stream.close() }

        if startingOffset > 0 {
            var skipped: Int64 = 0
            let skipBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
            defer { skipBuffer.deallocate() }
            while skipped < startingOffset {
                let toRead = min(chunkSize, Int(startingOffset - skipped))
                let n = stream.read(skipBuffer, maxLength: toRead)
                guard n > 0 else { break }
                skipped += Int64(n)
            }
        }

        var offset = startingOffset
        var chunkIndex = Int(offset / Int64(chunkSize))
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { buffer.deallocate() }

        await progressDelegate?.didSendBytes(0, totalSent: offset, totalExpected: totalSize)

        while stream.hasBytesAvailable {
            let n = stream.read(buffer, maxLength: chunkSize)
            guard n > 0 else { break }
            let chunk = Data(bytes: buffer, count: n)
            try await uploadChunk(chunk, uploadID: uploadID, index: chunkIndex, offset: offset, total: totalSize)
            offset += Int64(n)
            chunkIndex += 1
            await progressDelegate?.didSendBytes(Int64(n), totalSent: offset, totalExpected: totalSize)
        }
    }

    // MARK: - Private

    private func uploadChunk(_ chunk: Data, uploadID: String, index: Int, offset: Int64, total: Int64) async throws {
        let url = receiverBaseURL.appendingPathComponent("/uploads/\(uploadID)/chunks/\(index)")
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.setValue("bytes \(offset)-\(offset + Int64(chunk.count) - 1)/\(total)", forHTTPHeaderField: "Content-Range")
        req.setValue(device.deviceID, forHTTPHeaderField: "X-iCherri-Device-ID")
        if let trustToken, !trustToken.isEmpty {
            req.setValue(trustToken, forHTTPHeaderField: "X-iCherri-Token")
        }
        req.httpBody = chunk

        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw ChunkUploadError.serverError(http.statusCode)
        }
    }
}

@MainActor
public protocol ChunkUploadProgressDelegate: AnyObject {
    func didSendBytes(_ bytes: Int64, totalSent: Int64, totalExpected: Int64) async
}

public enum ChunkUploadError: Error {
    case serverError(Int)
    case streamError
}
