import Foundation
import ICherriProtocol

struct AutoBackupRun: Codable, Sendable, Equatable {
    var runID: String
    var receiverID: String
    var receiverName: String?
    var state: AutoBackupRunState
    var pauseReason: RunPauseReason?
    var createdAt: Date
    var updatedAt: Date
    var expiresAt: Date
    var assetRecords: [AutoBackupAssetRecord]
    var stagedFiles: [StagedAssetFile]
    var uploadSessions: [ReceiverUploadSessionRef]
    var lastError: String?
}

struct AutoBackupAssetRecord: Codable, Sendable, Equatable {
    var assetLocalID: String
    var state: AutoBackupAssetState
    var retryCount: Int
    var updatedAt: Date
}

struct StagedAssetFile: Codable, Sendable, Equatable {
    var stagedFileID: String
    var assetLocalID: String
    var localURL: URL
    var byteSize: Int64
    var createdAt: Date
    var cleanupEligibleAt: Date
    var usageState: StagedFileUsageState
}

struct ReceiverUploadSessionRef: Codable, Sendable, Equatable {
    var receiverID: String
    var uploadID: String
    var deviceID: String
    var assetLocalID: String
    var receivedBytes: Int64
    var chunkSize: Int
    var expiresAt: Date
    var status: ReceiverUploadSessionState
    var clientSessionID: String?
}

struct BackupEventRecord: Codable, Sendable, Equatable {
    var eventID: String
    var runID: String
    var message: String
    var createdAt: Date
}

private struct AutoBackupJobStoreState: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var policy = AutoBackupPolicy()
    var receiverSelection: AutoBackupReceiverSelection?
    var runsByID: [String: AutoBackupRun] = [:]
    var events: [BackupEventRecord] = []
}

struct AutoBackupReceiverSelection: Codable, Sendable, Equatable {
    var receiverID: String
    var receiverName: String?
    var receiverURLString: String?
    var trustTokenStorageKey: String
}

actor AutoBackupJobStore {
    static let shared = AutoBackupJobStore()

    private let fileURL: URL
    private var state = AutoBackupJobStoreState()

    init(fileURL: URL? = nil) {
        let resolvedURL: URL
        if let fileURL {
            resolvedURL = fileURL
        } else {
            let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let directory = baseDirectory.appendingPathComponent("iCherri", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            resolvedURL = directory.appendingPathComponent("auto-backup-jobs.json")
        }
        self.fileURL = resolvedURL
        self.state = Self.loadState(from: resolvedURL)
    }

    func loadPolicy() -> AutoBackupPolicy {
        state.policy
    }

    func savePolicy(_ policy: AutoBackupPolicy) {
        state.policy = policy
        persist()
    }

    func loadReceiverSelection() -> AutoBackupReceiverSelection? {
        state.receiverSelection
    }

    func saveReceiverSelection(_ selection: AutoBackupReceiverSelection?) {
        state.receiverSelection = selection
        persist()
    }

    func upsertRun(_ run: AutoBackupRun) {
        state.runsByID[run.runID] = run
        persist()
    }

    func loadRun(runID: String) -> AutoBackupRun? {
        state.runsByID[runID]
    }

    func loadActiveRun(receiverID: String) -> AutoBackupRun? {
        state.runsByID.values
            .filter { $0.receiverID == receiverID && $0.state != .completed && $0.state != .expired }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    func replaceAssetRecords(runID: String, assetRecords: [AutoBackupAssetRecord]) {
        guard var run = state.runsByID[runID] else { return }
        run.assetRecords = assetRecords
        run.updatedAt = Date()
        state.runsByID[runID] = run
        persist()
    }

    func replaceStagedFiles(runID: String, stagedFiles: [StagedAssetFile]) {
        guard var run = state.runsByID[runID] else { return }
        run.stagedFiles = stagedFiles
        run.updatedAt = Date()
        state.runsByID[runID] = run
        persist()
    }

    func replaceUploadSessions(runID: String, uploadSessions: [ReceiverUploadSessionRef]) {
        guard var run = state.runsByID[runID] else { return }
        run.uploadSessions = uploadSessions
        run.updatedAt = Date()
        state.runsByID[runID] = run
        persist()
    }

    func appendEvent(_ event: BackupEventRecord) {
        state.events.append(event)
        persist()
    }

    func totalStagedBytes(runID: String) -> Int64 {
        state.runsByID[runID]?.stagedFiles.reduce(0) { partialResult, file in
            partialResult + max(file.byteSize, 0)
        } ?? 0
    }

    @discardableResult
    func expireRuns(olderThan cutoffDate: Date) -> [String] {
        let expiredRunIDs = state.runsByID.values
            .filter { $0.expiresAt <= cutoffDate && $0.state != .expired }
            .map(\.runID)

        for runID in expiredRunIDs {
            guard var run = state.runsByID[runID] else { continue }
            run.state = .expired
            run.updatedAt = cutoffDate
            state.runsByID[runID] = run
        }

        if !expiredRunIDs.isEmpty {
            persist()
        }
        return expiredRunIDs
    }

    func snapshotRuns() -> [AutoBackupRun] {
        state.runsByID.values.sorted { $0.createdAt < $1.createdAt }
    }

    private static func loadState(from fileURL: URL) -> AutoBackupJobStoreState {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode(AutoBackupJobStoreState.self, from: data),
            decoded.schemaVersion == AutoBackupJobStoreState.currentSchemaVersion
        else {
            return AutoBackupJobStoreState()
        }

        return decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
