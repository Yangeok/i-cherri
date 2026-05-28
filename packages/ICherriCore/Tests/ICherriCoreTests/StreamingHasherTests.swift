import XCTest
@testable import ICherriCore
import Foundation
import CryptoKit

final class StreamingHasherTests: XCTestCase {
    private var tempDir: URL!
    private let hasher = StreamingHasher()

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StreamingHasherTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Correctness

    func testHashMatchesCryptoKit() throws {
        let data = Data((0..<1024).map { _ in UInt8.random(in: 0...255) })
        let fileURL = tempDir.appendingPathComponent("test.bin")
        try data.write(to: fileURL)

        let streamedHash = try hasher.hash(fileURL: fileURL)

        let expected = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(streamedHash, expected)
    }

    func testHashEmptyFile() throws {
        let fileURL = tempDir.appendingPathComponent("empty.bin")
        try Data().write(to: fileURL)

        let hash = try hasher.hash(fileURL: fileURL)

        let expected = SHA256.hash(data: Data()).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hash, expected)
    }

    func testHashLargeFile() throws {
        // 10 MB file to verify streaming does not spike memory
        let size = 10 * 1024 * 1024
        var data = Data(count: size)
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            for i in 0..<size { ptr[i] = UInt8(i & 0xFF) }
        }
        let fileURL = tempDir.appendingPathComponent("large.bin")
        try data.write(to: fileURL)

        let streamedHash = try hasher.hash(fileURL: fileURL)
        let expected = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(streamedHash, expected)
    }

    func testDifferentFilesProduceDifferentHashes() throws {
        let data1 = Data("hello world".utf8)
        let data2 = Data("hello world!".utf8)

        let url1 = tempDir.appendingPathComponent("a.txt")
        let url2 = tempDir.appendingPathComponent("b.txt")
        try data1.write(to: url1)
        try data2.write(to: url2)

        let hash1 = try hasher.hash(fileURL: url1)
        let hash2 = try hasher.hash(fileURL: url2)
        XCTAssertNotEqual(hash1, hash2)
    }

    func testMissingFileThrows() {
        let missing = tempDir.appendingPathComponent("nonexistent.bin")
        XCTAssertThrowsError(try hasher.hash(fileURL: missing))
    }

    // MARK: - Memory

    func testCustomBufferSizeProducesSameResult() throws {
        let data = Data((0..<8192).map { _ in UInt8.random(in: 0...255) })
        let fileURL = tempDir.appendingPathComponent("buftest.bin")
        try data.write(to: fileURL)

        let smallBufferHasher = StreamingHasher(bufferSize: 512)
        let largeBufferHasher = StreamingHasher(bufferSize: 64 * 1024)

        let hash1 = try smallBufferHasher.hash(fileURL: fileURL)
        let hash2 = try largeBufferHasher.hash(fileURL: fileURL)
        XCTAssertEqual(hash1, hash2)
    }

    // MARK: - Performance

    func testHashingPerformance() throws {
        let size = 50 * 1024 * 1024  // 50 MB
        var data = Data(count: size)
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            for i in 0..<size { ptr[i] = UInt8(i & 0xFF) }
        }
        let fileURL = tempDir.appendingPathComponent("perf.bin")
        try data.write(to: fileURL)

        measure {
            _ = try? hasher.hash(fileURL: fileURL)
        }
    }
}
