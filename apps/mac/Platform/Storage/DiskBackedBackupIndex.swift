import Foundation
import AVFoundation
import ImageIO
import ICherriCore
import ICherriProtocol

// Restores dedup truth from disk when DB rows were deleted but the physical backup file still exists.
actor DiskBackedBackupIndex: BackupIndexQuerying {
    private let databaseManager: DatabaseManager
    private let backupRootURL: URL
    private let hasher = StreamingHasher()

    init(databaseManager: DatabaseManager, backupRootURL: URL) {
        self.databaseManager = databaseManager
        self.backupRootURL = backupRootURL
    }

    func findByDeviceAndAssetID(deviceID: String, assetLocalID: String) async throws -> BackupIndexEntry? {
        try await databaseManager.findByDeviceAndAssetID(deviceID: deviceID, assetLocalID: assetLocalID)
    }

    func findByFingerprint(_ fingerprint: String) async throws -> BackupIndexEntry? {
        try await databaseManager.findByFingerprint(fingerprint)
    }

    func findByCandidate(_ candidate: AssetMetadata) async throws -> BackupIndexEntry? {
        if let existing = try await databaseManager.findByFingerprint(candidate.quickFingerprint) {
            try await rehydrateIndexIfNeeded(for: candidate)
            return existing
        }

        guard let diskMatch = try findOnDisk(candidate) else { return nil }
        let rehydrated = try await rehydrateIndex(
            for: candidate,
            resolvedFileURL: diskMatch.fileURL,
            contentSHA256: diskMatch.contentSHA256,
            duplicateOfBackupID: nil
        )
        return BackupIndexEntry(
            backupID: rehydrated.backupId,
            status: rehydrated.status,
            contentSHA256: rehydrated.contentSha256
        )
    }

    func findBySHA256(_ sha256: String) async throws -> BackupIndexEntry? {
        try await databaseManager.findBySHA256(sha256)
    }

    // The default BackupIndexQuerying.fetchBatchEntries loops findByDeviceAndAssetID +
    // findByCandidate per candidate — for N candidates that's N sequential actor round-trips
    // (2+ each), which dominates checkBatch latency for large libraries. Batch the common case
    // (candidate already known by exact match or fingerprint) into two IN(...) queries, and only
    // fall back to the slower per-candidate rehydration/disk-scan paths for the subset that
    // actually needs them (cross-device dedup rehydration, or DB rows missing entirely).
    func fetchBatchEntries(
        candidates: [AssetMetadata]
    ) async throws -> (exactMatches: [String: BackupIndexEntry], fingerprintMatches: [String: BackupIndexEntry]) {
        guard !candidates.isEmpty else { return ([:], [:]) }

        let (exactMatches, batchFingerprintMatches) = try await databaseManager.fetchBatchEntries(candidates: candidates)
        var fingerprintMatches = batchFingerprintMatches

        for candidate in candidates {
            let exactKey = "\(candidate.deviceID):\(candidate.assetLocalID)"

            if fingerprintMatches[candidate.quickFingerprint] != nil {
                // Known by fingerprint. If this exact device/asset combo isn't registered yet
                // (first time this device has seen a fingerprint another device already backed
                // up), rehydrate a duplicate pointer for it.
                if exactMatches[exactKey] == nil {
                    try await rehydrateIndexIfNeeded(for: candidate)
                }
                continue
            }

            // No DB record at all for this fingerprint — rare (DB row deleted/lost but the
            // physical file survives on disk). findOnDisk is a cheap no-op (file existence
            // check) for genuinely new assets that were never backed up.
            guard let diskMatch = try findOnDisk(candidate) else { continue }
            let rehydrated = try await rehydrateIndex(
                for: candidate,
                resolvedFileURL: diskMatch.fileURL,
                contentSHA256: diskMatch.contentSHA256,
                duplicateOfBackupID: nil
            )
            fingerprintMatches[candidate.quickFingerprint] = BackupIndexEntry(
                backupID: rehydrated.backupId,
                status: rehydrated.status,
                contentSHA256: rehydrated.contentSha256
            )
        }

        return (exactMatches, fingerprintMatches)
    }

    func registerDuplicate(candidate: AssetMetadata, duplicateOfBackupID: String) async throws {
        try await databaseManager.registerDuplicate(candidate: candidate, duplicateOfBackupID: duplicateOfBackupID)
    }

    private func rehydrateIndexIfNeeded(for candidate: AssetMetadata) async throws {
        guard try await databaseManager.findByDeviceAndAssetID(deviceID: candidate.deviceID, assetLocalID: candidate.assetLocalID) == nil else {
            return
        }

        guard let source = try await databaseManager.fetchAsset(fingerprint: candidate.quickFingerprint) else {
            return
        }

        let resolvedURL = resolvedFileURL(for: source.finalPath)
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else { return }

        _ = try await rehydrateIndex(
            for: candidate,
            resolvedFileURL: resolvedURL,
            contentSHA256: source.contentSha256,
            duplicateOfBackupID: source.backupId
        )
    }

    private func rehydrateIndex(
        for candidate: AssetMetadata,
        resolvedFileURL: URL,
        contentSHA256: String,
        duplicateOfBackupID: String?
    ) async throws -> BackupAssetRecord {
        if let existing = try await databaseManager.fetchAsset(deviceId: candidate.deviceID, assetLocalId: candidate.assetLocalID) {
            return existing
        }

        let record = BackupAssetRecord(
            id: nil,
            backupId: UUID().uuidString,
            deviceId: candidate.deviceID,
            assetLocalId: candidate.assetLocalID,
            originalFilename: candidate.originalFilename,
            mediaType: candidate.mediaType.rawValue,
            creationDate: candidate.creationDate,
            modificationDate: candidate.modificationDate,
            byteSize: candidate.byteSize,
            durationSeconds: nil,
            pixelWidth: candidate.pixelWidth,
            pixelHeight: candidate.pixelHeight,
            quickFingerprint: candidate.quickFingerprint,
            contentSha256: contentSHA256,
            finalPath: relativeDisplayPath(for: resolvedFileURL),
            status: "completed",
            duplicateOfBackupId: duplicateOfBackupID,
            firstSeenAt: Date(),
            completedAt: Date(),
            lastError: nil
        )
        try await databaseManager.insertBackupAsset(record)
        return try await databaseManager.fetchAsset(deviceId: candidate.deviceID, assetLocalId: candidate.assetLocalID) ?? record
    }

    private func findOnDisk(_ candidate: AssetMetadata) throws -> DiskMatch? {
        let monthDirectory = backupMonthDirectory(for: candidate.creationDate)
        guard FileManager.default.fileExists(atPath: monthDirectory.path) else { return nil }

        let canonicalURL = monthDirectory.appendingPathComponent(candidate.originalFilename)
        if let match = try inspect(url: canonicalURL, candidate: candidate) {
            return match
        }

        return nil
    }

    private func inspect(url: URL, candidate: AssetMetadata) throws -> DiskMatch? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attrs[.size] as? Int64, fileSize == candidate.byteSize else { return nil }
        guard metadataMatches(url: url, candidate: candidate) else { return nil }
        return DiskMatch(fileURL: url, contentSHA256: try hasher.hash(fileURL: url))
    }

    private func metadataMatches(url: URL, candidate: AssetMetadata) -> Bool {
        let expectedDimensions = (candidate.pixelWidth, candidate.pixelHeight)

        switch candidate.mediaType {
        case .photo:
            guard let dimensions = imageDimensions(url: url) else { return false }
            return dimensions == expectedDimensions
        case .video:
            guard let dimensions = videoDimensions(url: url) else { return false }
            return dimensions == expectedDimensions
        case .livePhotoComponent, .unknown:
            if let imageDimensions = imageDimensions(url: url), imageDimensions == expectedDimensions {
                return true
            }
            if let videoDimensions = videoDimensions(url: url), videoDimensions == expectedDimensions {
                return true
            }
            return false
        }
    }

    private func imageDimensions(url: URL) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return (width, height)
    }

    private func videoDimensions(url: URL) -> (Int, Int)? {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return nil }
        let transformed = track.naturalSize.applying(track.preferredTransform)
        return (Int(abs(transformed.width.rounded())), Int(abs(transformed.height.rounded())))
    }

    private func backupMonthDirectory(for creationDate: Date) -> URL {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: creationDate)
        let month = calendar.component(.month, from: creationDate)
        return backupRootURL.appendingPathComponent(String(format: "%04d/%02d", year, month), isDirectory: true)
    }

    private func resolvedFileURL(for storedPath: String) -> URL {
        if (storedPath as NSString).isAbsolutePath {
            return URL(fileURLWithPath: storedPath)
        }
        return backupRootURL.appendingPathComponent(storedPath)
    }

    private func relativeDisplayPath(for resolvedFileURL: URL) -> String {
        let standardizedRoot = backupRootURL.standardizedFileURL.path
        let standardizedFile = resolvedFileURL.standardizedFileURL.path
        guard standardizedFile.hasPrefix(standardizedRoot + "/") else {
            return standardizedFile
        }
        return String(standardizedFile.dropFirst(standardizedRoot.count + 1))
    }

    private struct DiskMatch {
        let fileURL: URL
        let contentSHA256: String
    }
}
