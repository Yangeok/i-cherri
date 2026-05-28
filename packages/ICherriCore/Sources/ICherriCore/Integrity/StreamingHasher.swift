import Foundation
import CryptoKit

// Computes SHA-256 of a file using a streaming buffer to avoid loading the full file into memory.
// Memory ceiling is bounded by bufferSize (default 4 MB), satisfying the <100 MB constraint.
public final class StreamingHasher: @unchecked Sendable {
    private let bufferSize: Int

    public init(bufferSize: Int = 4 * 1024 * 1024) {
        self.bufferSize = bufferSize
    }

    // Returns lowercase hex SHA-256 of the file at the given URL.
    public func hash(fileURL: URL) throws -> String {
        guard let stream = InputStream(url: fileURL) else {
            throw StreamingHasherError.cannotOpenFile(fileURL.path)
        }
        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            guard bytesRead > 0 else { break }
            let chunk = UnsafeRawBufferPointer(start: buffer, count: bytesRead)
            hasher.update(bufferPointer: chunk)
        }

        if let error = stream.streamError {
            throw error
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // Computes SHA-256 from an already-open InputStream without seeking.
    // The caller is responsible for opening/closing the stream.
    public func hash(stream: InputStream) throws -> String {
        var hasher = SHA256()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            guard bytesRead > 0 else { break }
            let chunk = UnsafeRawBufferPointer(start: buffer, count: bytesRead)
            hasher.update(bufferPointer: chunk)
        }

        if let error = stream.streamError {
            throw error
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public enum StreamingHasherError: Error {
    case cannotOpenFile(String)
}
