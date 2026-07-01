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

        for candidate in request.candidates {
            let decision = try await classify(candidate)
            switch decision {
            case .required(let reason):
                requiredUploads.append(UploadRequirement(assetLocalID: candidate.assetLocalID, uploadReason: reason))
            case .alreadyBackedUp:
                alreadyBackedUp.append(candidate.assetLocalID)
            case .duplicate(let duplicateOfBackupID):
                duplicates.append(candidate.assetLocalID)
                // Register duplicate record in database
                try await index.registerDuplicate(candidate: candidate, duplicateOfBackupID: duplicateOfBackupID)
            }
        }

        return CheckBatchResponse(
            requiredUploads: requiredUploads,
            alreadyBackedUp: alreadyBackedUp,
            duplicates: duplicates
        )
    }

    // MARK: - 3-Stage Deduplication

    private enum Decision {
        case required(UploadReason)
        case alreadyBackedUp
        case duplicate(duplicateOfBackupID: String)
    }

    private func classify(_ candidate: AssetMetadata) async throws -> Decision {
        let exactEntry = try await index.findByDeviceAndAssetID(
            deviceID: candidate.deviceID,
            assetLocalID: candidate.assetLocalID
        )
        let fingerprintEntry = try await index.findByCandidate(candidate)

        let verdict = DeduplicationPolicy.evaluate(
            exactMatch: exactEntry,
            fingerprintMatch: fingerprintEntry
        )

        switch verdict {
        case .alreadyBackedUp:
            return .alreadyBackedUp
        case .duplicate:
            let duplicateOfBackupID = fingerprintEntry?.backupID ?? ""
            return .duplicate(duplicateOfBackupID: duplicateOfBackupID)
        case .upload:
            return .required(.notFound)
        }
    }
}
