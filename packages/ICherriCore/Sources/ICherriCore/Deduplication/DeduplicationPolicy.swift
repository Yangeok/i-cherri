import Foundation
import ICherriProtocol

// Encapsulates the 3-stage deduplication decision logic.
public enum DeduplicationPolicy {
    public enum Result: Sendable {
        case upload
        case alreadyBackedUp(existingBackupID: String)
        // Physical file storage is skipped; only a logical record is created.
        case duplicate(originalBackupID: String)
    }

    // Stage 1: exact device + asset ID
    public static func checkExactMatch(entry: BackupIndexEntry?) -> Result? {
        guard let entry, entry.isCompleted else { return nil }
        return .alreadyBackedUp(existingBackupID: entry.backupID)
    }

    // Stage 2: metadata fingerprint (same content from different device or re-import)
    public static func checkFingerprintMatch(entry: BackupIndexEntry?) -> Result? {
        guard let entry, entry.isCompleted else { return nil }
        return .duplicate(originalBackupID: entry.backupID)
    }

    // Stage 3: SHA-256 content hash (performed at commit time on Mac)
    public static func checkHashMatch(computedHash: String, entry: BackupIndexEntry?) -> Result? {
        guard let entry, entry.isCompleted, entry.contentSHA256 == computedHash else { return nil }
        return .duplicate(originalBackupID: entry.backupID)
    }

    // Convenience: runs all 3 stages in order given optional index entries.
    public static func evaluate(
        exactMatch: BackupIndexEntry?,
        fingerprintMatch: BackupIndexEntry?,
        computedSHA256: String? = nil,
        sha256Match: BackupIndexEntry? = nil
    ) -> Result {
        if let result = checkExactMatch(entry: exactMatch) { return result }
        if let result = checkFingerprintMatch(entry: fingerprintMatch) { return result }
        if let sha256 = computedSHA256, let result = checkHashMatch(computedHash: sha256, entry: sha256Match) {
            return result
        }
        return .upload
    }
}
