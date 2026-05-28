import Foundation
import ICherriProtocol
import ICherriCore

// Atomically moves a verified incoming temp file to its final destination and registers it in the DB.
actor FileCommitProcessor {
    private let backupRootURL: URL
    private let dbManager: DatabaseManager
    private let hasher: StreamingHasher

    init(backupRootURL: URL, dbManager: DatabaseManager) {
        self.backupRootURL = backupRootURL
        self.dbManager = dbManager
        self.hasher = StreamingHasher()
    }

    struct CommitInput {
        let uploadID: String
        let deviceID: String
        let assetLocalID: String
        let originalFilename: String
        let mediaType: MediaType
        let creationDate: Date
        let modificationDate: Date
        let byteSize: Int64
        let pixelWidth: Int
        let pixelHeight: Int
        let quickFingerprint: String
        let durationSeconds: Double?
        let tempPath: String
        let expectedByteSize: Int64
        let expectedSHA256: String
    }

    enum CommitResult {
        case success(backupID: String, displayPath: String)
        case checksumMismatch
        case sizeMismatch
    }

    func commit(_ input: CommitInput) async throws -> CommitResult {
        let tempURL = URL(fileURLWithPath: input.tempPath)

        // Verify byte size
        let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        guard let fileSize = attributes[.size] as? Int64, fileSize == input.expectedByteSize else {
            return .sizeMismatch
        }

        // Streaming SHA-256 verification
        let computedHash = try hasher.hash(fileURL: tempURL)
        guard computedHash == input.expectedSHA256 else {
            return .checksumMismatch
        }

        // Build final destination path: YYYY/MM/filename
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: input.creationDate)
        let month = calendar.component(.month, from: input.creationDate)
        let relativeDir = String(format: "%04d/%02d", year, month)
        let destDir = backupRootURL.appendingPathComponent(relativeDir)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let destURL = uniqueDestURL(dir: destDir, filename: input.originalFilename)
        let displayPath = "\(relativeDir)/\(destURL.lastPathComponent)"

        // Atomic move
        try FileManager.default.moveItem(at: tempURL, to: destURL)

        // Register in DB
        let backupID = UUID().uuidString
        let record = BackupAssetRecord(
            id: nil,
            backupId: backupID,
            deviceId: input.deviceID,
            assetLocalId: input.assetLocalID,
            originalFilename: input.originalFilename,
            mediaType: input.mediaType.rawValue,
            creationDate: input.creationDate,
            modificationDate: input.modificationDate,
            byteSize: input.byteSize,
            durationSeconds: input.durationSeconds,
            pixelWidth: input.pixelWidth,
            pixelHeight: input.pixelHeight,
            quickFingerprint: input.quickFingerprint,
            contentSha256: computedHash,
            finalPath: displayPath,
            status: "completed",
            duplicateOfBackupId: nil,
            firstSeenAt: Date(),
            completedAt: Date(),
            lastError: nil
        )
        try await dbManager.insertBackupAsset(record)

        return .success(backupID: backupID, displayPath: displayPath)
    }

    // Returns a destination URL that doesn't collide with existing files.
    private func uniqueDestURL(dir: URL, filename: String) -> URL {
        var candidate = dir.appendingPathComponent(filename)
        var counter = 1
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(name)_\(counter)" : "\(name)_\(counter).\(ext)"
            candidate = dir.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }
}
