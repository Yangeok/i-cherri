import Foundation
import ICherriProtocol
// T022: DeduplicationPolicy filter applied in classify()

// Determines which assets in a check-batch request need uploading by querying the backup index.
public protocol BackupIndexQuerying: Sendable {
    func findByDeviceAndAssetID(deviceID: String, assetLocalID: String) async throws -> BackupIndexEntry?
    func findByFingerprint(_ fingerprint: String) async throws -> BackupIndexEntry?
    func findByCandidate(_ candidate: AssetMetadata) async throws -> BackupIndexEntry?
    func findBySHA256(_ sha256: String) async throws -> BackupIndexEntry?
    func registerDuplicate(candidate: AssetMetadata, duplicateOfBackupID: String) async throws
    
    // Batch query methods to prevent sequential database round-trips
    func fetchBatchEntries(candidates: [AssetMetadata]) async throws -> (exactMatches: [String: BackupIndexEntry], fingerprintMatches: [String: BackupIndexEntry])
}

public extension BackupIndexQuerying {
    func fetchBatchEntries(candidates: [AssetMetadata]) async throws -> (exactMatches: [String: BackupIndexEntry], fingerprintMatches: [String: BackupIndexEntry]) {
        var exactMatches: [String: BackupIndexEntry] = [:]
        var fingerprintMatches: [String: BackupIndexEntry] = [:]
        for candidate in candidates {
            if let exact = try await findByDeviceAndAssetID(deviceID: candidate.deviceID, assetLocalID: candidate.assetLocalID) {
                exactMatches["\(candidate.deviceID):\(candidate.assetLocalID)"] = exact
            }
            if let fp = try await findByCandidate(candidate) {
                fingerprintMatches[candidate.quickFingerprint] = fp
            }
        }
        return (exactMatches, fingerprintMatches)
    }
}

public struct BackupIndexEntry: Sendable {
    public let backupID: String
    public let status: String
    public let contentSHA256: String

    public init(backupID: String, status: String, contentSHA256: String) {
        self.backupID = backupID
        self.status = status
        self.contentSHA256 = contentSHA256
    }

    public var isCompleted: Bool { status == "completed" }
}

public actor CheckBatchProcessor {
    private let index: any BackupIndexQuerying

    public init(index: any BackupIndexQuerying) {
        self.index = index
    }

    public func process(request: CheckBatchRequest) async throws -> CheckBatchResponse {
        var requiredUploads: [UploadRequirement] = []
        var alreadyBackedUp: [String] = []
        var duplicates: [String] = []

        // Batch fetch all exact and fingerprint entries
        let (exactMatches, fingerprintMatches) = try await index.fetchBatchEntries(candidates: request.candidates)

        for candidate in request.candidates {
            let exactEntry = exactMatches["\(candidate.deviceID):\(candidate.assetLocalID)"]
            let fingerprintEntry = fingerprintMatches[candidate.quickFingerprint]

            let verdict = DeduplicationPolicy.evaluate(
                exactMatch: exactEntry,
                fingerprintMatch: fingerprintEntry
            )

            switch verdict {
            case .alreadyBackedUp:
                alreadyBackedUp.append(candidate.assetLocalID)
            case .duplicate:
                let duplicateOfBackupID = fingerprintEntry?.backupID ?? ""
                duplicates.append(candidate.assetLocalID)
                // Register duplicate record in database
                try await index.registerDuplicate(candidate: candidate, duplicateOfBackupID: duplicateOfBackupID)
            case .upload:
                requiredUploads.append(UploadRequirement(assetLocalID: candidate.assetLocalID, uploadReason: .notFound))
            }
        }

        return CheckBatchResponse(
            requiredUploads: requiredUploads,
            alreadyBackedUp: alreadyBackedUp,
            duplicates: duplicates
        )
    }
}
