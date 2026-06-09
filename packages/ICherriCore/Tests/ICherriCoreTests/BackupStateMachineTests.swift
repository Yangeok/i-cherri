import XCTest
import ICherriProtocol
@testable import ICherriCore

final class BackupStateMachineTests: XCTestCase {

    // MARK: - DeduplicationPolicy Tests

    func testExactMatchReturnsAlreadyBackedUp() {
        let entry = BackupIndexEntry(backupID: "b1", status: "completed", contentSHA256: "abc123")
        let result = DeduplicationPolicy.evaluate(exactMatch: entry, fingerprintMatch: nil)
        guard case .alreadyBackedUp(let id) = result else {
            return XCTFail("Expected alreadyBackedUp, got \(result)")
        }
        XCTAssertEqual(id, "b1")
    }

    func testFingerprintMatchReturnsDuplicate() {
        let entry = BackupIndexEntry(backupID: "b2", status: "completed", contentSHA256: "def456")
        let result = DeduplicationPolicy.evaluate(exactMatch: nil, fingerprintMatch: entry)
        guard case .duplicate(let id) = result else {
            return XCTFail("Expected duplicate, got \(result)")
        }
        XCTAssertEqual(id, "b2")
    }

    func testExactMatchTakesPriorityOverFingerprint() {
        let exact = BackupIndexEntry(backupID: "exact", status: "completed", contentSHA256: "aaa")
        let fp = BackupIndexEntry(backupID: "fp", status: "completed", contentSHA256: "bbb")
        let result = DeduplicationPolicy.evaluate(exactMatch: exact, fingerprintMatch: fp)
        guard case .alreadyBackedUp(let id) = result else {
            return XCTFail("Expected alreadyBackedUp, got \(result)")
        }
        XCTAssertEqual(id, "exact")
    }

    func testNoMatchReturnsUpload() {
        let result = DeduplicationPolicy.evaluate(exactMatch: nil, fingerprintMatch: nil)
        guard case .upload = result else {
            return XCTFail("Expected upload, got \(result)")
        }
    }

    func testIncompleteEntryIsIgnored() {
        let failed = BackupIndexEntry(backupID: "f1", status: "failed", contentSHA256: "")
        let result = DeduplicationPolicy.evaluate(exactMatch: failed, fingerprintMatch: nil)
        guard case .upload = result else {
            return XCTFail("Expected upload for non-completed entry, got \(result)")
        }
    }

    func testSHA256MatchAtCommitPhase() {
        let sha256Entry = BackupIndexEntry(backupID: "s1", status: "completed", contentSHA256: "deadbeef")
        let result = DeduplicationPolicy.evaluate(
            exactMatch: nil,
            fingerprintMatch: nil,
            computedSHA256: "deadbeef",
            sha256Match: sha256Entry
        )
        guard case .duplicate(let id) = result else {
            return XCTFail("Expected duplicate via SHA-256, got \(result)")
        }
        XCTAssertEqual(id, "s1")
    }

    func testSHA256MismatchReturnsUpload() {
        let sha256Entry = BackupIndexEntry(backupID: "s2", status: "completed", contentSHA256: "cafebabe")
        let result = DeduplicationPolicy.evaluate(
            exactMatch: nil,
            fingerprintMatch: nil,
            computedSHA256: "deadbeef",
            sha256Match: sha256Entry
        )
        guard case .upload = result else {
            return XCTFail("Expected upload on hash mismatch, got \(result)")
        }
    }

    // MARK: - CheckBatchProcessor Tests

    func testCheckBatchAllNew() async throws {
        let index = MockBackupIndex()
        let processor = CheckBatchProcessor(index: index)

        let device = DeviceInfo(deviceID: "d1", deviceName: "iPhone", platform: "iOS", appVersion: "1.0")
        let candidates = [
            makeAsset(deviceID: "d1", assetID: "a1", fingerprint: "fp1"),
            makeAsset(deviceID: "d1", assetID: "a2", fingerprint: "fp2")
        ]
        let request = CheckBatchRequest(device: device, candidates: candidates)
        let response = try await processor.process(request: request)

        XCTAssertEqual(response.requiredUploads.count, 2)
        XCTAssertTrue(response.alreadyBackedUp.isEmpty)
        XCTAssertTrue(response.duplicates.isEmpty)
    }

    func testCheckBatchExactMatchSkipped() async throws {
        var index = MockBackupIndex()
        index.exactEntries["d1:a1"] = BackupIndexEntry(backupID: "b1", status: "completed", contentSHA256: "abc")

        let processor = CheckBatchProcessor(index: index)
        let device = DeviceInfo(deviceID: "d1", deviceName: "iPhone", platform: "iOS", appVersion: "1.0")
        let request = CheckBatchRequest(
            device: device,
            candidates: [makeAsset(deviceID: "d1", assetID: "a1", fingerprint: "fp1")]
        )
        let response = try await processor.process(request: request)

        XCTAssertTrue(response.requiredUploads.isEmpty)
        XCTAssertEqual(response.alreadyBackedUp, ["a1"])
    }

    func testCheckBatchFingerprintMatchIsDuplicate() async throws {
        var index = MockBackupIndex()
        index.fingerprintEntries["fp1"] = BackupIndexEntry(backupID: "b1", status: "completed", contentSHA256: "abc")

        let processor = CheckBatchProcessor(index: index)
        let device = DeviceInfo(deviceID: "d1", deviceName: "iPhone", platform: "iOS", appVersion: "1.0")
        let request = CheckBatchRequest(
            device: device,
            candidates: [makeAsset(deviceID: "d1", assetID: "a1", fingerprint: "fp1")]
        )
        let response = try await processor.process(request: request)

        XCTAssertTrue(response.requiredUploads.isEmpty)
        XCTAssertEqual(response.duplicates, ["a1"])
    }

    // MARK: - Helpers

    private func makeAsset(deviceID: String, assetID: String, fingerprint: String) -> AssetMetadata {
        AssetMetadata(
            deviceID: deviceID,
            assetLocalID: assetID,
            originalFilename: "\(assetID).heic",
            mediaType: .photo,
            creationDate: Date(),
            modificationDate: Date(),
            byteSize: 1_000_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            quickFingerprint: fingerprint
        )
    }
}

// MARK: - Test Doubles

struct MockBackupIndex: BackupIndexQuerying {
    var exactEntries: [String: BackupIndexEntry] = [:]
    var fingerprintEntries: [String: BackupIndexEntry] = [:]
    var sha256Entries: [String: BackupIndexEntry] = [:]

    func findByDeviceAndAssetID(deviceID: String, assetLocalID: String) async throws -> BackupIndexEntry? {
        exactEntries["\(deviceID):\(assetLocalID)"]
    }

    func findByFingerprint(_ fingerprint: String) async throws -> BackupIndexEntry? {
        fingerprintEntries[fingerprint]
    }

    func findByCandidate(_ candidate: AssetMetadata) async throws -> BackupIndexEntry? {
        fingerprintEntries[candidate.quickFingerprint]
    }

    func findBySHA256(_ sha256: String) async throws -> BackupIndexEntry? {
        sha256Entries[sha256]
    }
}
