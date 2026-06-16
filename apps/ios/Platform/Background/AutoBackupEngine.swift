import Foundation
import ICherriCore
import ICherriProtocol

actor AutoBackupEngine {
    static let shared = AutoBackupEngine()

    private let store: AutoBackupJobStore
    private let policyEvaluator: AutoBackupPolicyEvaluator

    init(
        store: AutoBackupJobStore = .shared,
        policyEvaluator: AutoBackupPolicyEvaluator = AutoBackupPolicyEvaluator()
    ) {
        self.store = store
        self.policyEvaluator = policyEvaluator
    }

    @discardableResult
    func handleProcessingTask(identifier: String) async -> Bool {
        _ = await store.expireRuns(olderThan: Date())
        return true
    }

    func ensureScheduledRun(receiverID: String, receiverName: String?) async -> AutoBackupRun {
        if let existingRun = await store.loadActiveRun(receiverID: receiverID) {
            return existingRun
        }

        let now = Date()
        let run = AutoBackupRun(
            runID: UUID().uuidString,
            receiverID: receiverID,
            receiverName: receiverName,
            state: .scheduled,
            pauseReason: nil,
            createdAt: now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(7 * 24 * 60 * 60),
            assetRecords: [],
            stagedFiles: [],
            uploadSessions: [],
            lastError: nil
        )
        await store.upsertRun(run)
        await recordEvent(runID: run.runID, message: "Created scheduled automatic backup run.")
        return run
    }

    @discardableResult
    func evaluateAndPrepareRun(
        receiverID: String,
        receiverName: String?,
        runtimeSnapshot: AutoBackupRuntimeSnapshot,
        runAssets: [AssetMetadata]
    ) async throws -> AutoBackupRun {
        var run = await ensureScheduledRun(receiverID: receiverID, receiverName: receiverName)
        let now = Date()
        run.assetRecords = runAssets.map { asset in
            AutoBackupAssetRecord(
                assetLocalID: asset.assetLocalID,
                state: .queued,
                retryCount: 0,
                updatedAt: now
            )
        }
        run.updatedAt = now
        await store.upsertRun(run)
        await recordEvent(
            runID: run.runID,
            message: runAssets.isEmpty
                ? "Prepared run with no changed assets."
                : "Prepared run with \(runAssets.count) changed asset(s)."
        )

        let nextState = try await reevaluateRun(runID: run.runID, runtimeSnapshot: runtimeSnapshot)
        guard var updatedRun = await store.loadRun(runID: run.runID) else {
            throw AutoBackupEngineError.runNotFound
        }
        updatedRun.state = nextState
        updatedRun.updatedAt = Date()
        await store.upsertRun(updatedRun)
        await recordEvent(runID: updatedRun.runID, message: "Run state moved to \(updatedRun.state.rawValue).")
        return updatedRun
    }

    @discardableResult
    func reevaluateRun(
        runID: String,
        runtimeSnapshot: AutoBackupRuntimeSnapshot
    ) async throws -> AutoBackupRunState {
        guard var run = await store.loadRun(runID: runID) else {
            throw AutoBackupEngineError.runNotFound
        }

        let eligibility = policyEvaluator.evaluate(
            policy: await store.loadPolicy(),
            runtimeSnapshot: runtimeSnapshot
        )

        let nextState = try AutoBackupStateMachine.transition(
            runState: run.state,
            event: .policyEvaluated(isEligible: eligibility.isEligible)
        )
        run.state = nextState
        run.updatedAt = Date()
        run.pauseReason = eligibility.reason == .thermal ? .thermal : nil
        await store.upsertRun(run)
        await recordEvent(runID: run.runID, message: eventMessage(for: nextState, reason: eligibility.reason))
        return nextState
    }

    @discardableResult
    func requeueFailedAssets(runID: String) async throws -> [String] {
        guard var run = await store.loadRun(runID: runID) else {
            throw AutoBackupEngineError.runNotFound
        }

        let now = Date()
        var requeuedAssetIDs: [String] = []
        run.assetRecords = try run.assetRecords.map { record in
            guard record.state == .failedRetained else { return record }

            requeuedAssetIDs.append(record.assetLocalID)
            let nextState = try AutoBackupStateMachine.transition(
                assetState: record.state,
                event: .requeue
            )
            return AutoBackupAssetRecord(
                assetLocalID: record.assetLocalID,
                state: nextState,
                retryCount: record.retryCount + 1,
                updatedAt: now
            )
        }
        run.updatedAt = now
        await store.upsertRun(run)
        if !requeuedAssetIDs.isEmpty {
            await recordEvent(runID: run.runID, message: "Queued \(requeuedAssetIDs.count) failed asset(s) for the next automatic pass.")
        }
        return requeuedAssetIDs
    }

    @discardableResult
    func pauseRun(runID: String, reason: RunPauseReason) async throws -> AutoBackupRunState {
        guard var run = await store.loadRun(runID: runID) else {
            throw AutoBackupEngineError.runNotFound
        }

        let nextState = try AutoBackupStateMachine.transition(
            runState: run.state,
            event: .pause(reason: reason)
        )
        run.state = nextState
        run.pauseReason = reason
        run.updatedAt = Date()
        await store.upsertRun(run)
        await recordEvent(runID: run.runID, message: pauseMessage(for: reason))
        return nextState
    }

    @discardableResult
    func resumePausedRun(runID: String, runtimeSnapshot: AutoBackupRuntimeSnapshot) async throws -> AutoBackupRunState {
        guard var run = await store.loadRun(runID: runID) else {
            throw AutoBackupEngineError.runNotFound
        }

        let eligibility = policyEvaluator.evaluate(
            policy: await store.loadPolicy(),
            runtimeSnapshot: runtimeSnapshot
        )
        guard eligibility.isEligible else {
            run.pauseReason = eligibility.reason == .thermal ? .thermal : run.pauseReason
            run.updatedAt = Date()
            await store.upsertRun(run)
            await recordEvent(runID: run.runID, message: eventMessage(for: run.state, reason: eligibility.reason))
            return run.state
        }

        let nextState = try AutoBackupStateMachine.transition(
            runState: run.state,
            event: .resume
        )
        run.state = nextState
        run.pauseReason = nil
        run.updatedAt = Date()
        await store.upsertRun(run)
        await recordEvent(runID: run.runID, message: "Automatic backup resumed unfinished assets.")
        return nextState
    }

    @discardableResult
    func stageFile(
        runID: String,
        assetLocalID: String,
        localURL: URL,
        byteSize: Int64,
        cleanupEligibleAt: Date
    ) async throws -> StagedAssetFile {
        guard var run = await store.loadRun(runID: runID) else {
            throw AutoBackupEngineError.runNotFound
        }

        if let existing = run.stagedFiles.first(where: { $0.assetLocalID == assetLocalID }),
           FileManager.default.fileExists(atPath: existing.localURL.path) {
            await recordEvent(runID: runID, message: "Reused staged file for \(assetLocalID).")
            return existing
        }

        let stagedBytesInUse = run.stagedFiles.reduce(Int64(0)) { partialResult, file in
            partialResult + max(file.byteSize, 0)
        }
        let stagedLimitBytes = await store.loadPolicy().stagedStorageLimitBytes
        guard stagedBytesInUse + max(byteSize, 0) <= stagedLimitBytes else {
            run.lastError = "staged_limit_exceeded"
            run.updatedAt = Date()
            await store.upsertRun(run)
            await recordEvent(runID: runID, message: "Paused staging because the 2 GB staged upload limit was reached.")
            throw AutoBackupEngineError.stagedStorageLimitExceeded(limitBytes: stagedLimitBytes)
        }

        let stagedFile = StagedAssetFile(
            stagedFileID: UUID().uuidString,
            assetLocalID: assetLocalID,
            localURL: localURL,
            byteSize: byteSize,
            createdAt: Date(),
            cleanupEligibleAt: cleanupEligibleAt,
            usageState: .ready
        )
        run.stagedFiles.append(stagedFile)
        run.assetRecords = try run.assetRecords.map { record in
            guard record.assetLocalID == assetLocalID else { return record }
            let nextState = record.state == .queued
                ? try AutoBackupStateMachine.transition(assetState: record.state, event: .stagePrepared)
                : record.state
            return AutoBackupAssetRecord(
                assetLocalID: record.assetLocalID,
                state: nextState,
                retryCount: record.retryCount,
                updatedAt: Date()
            )
        }
        run.lastError = nil
        run.updatedAt = Date()
        await store.upsertRun(run)
        await recordEvent(runID: runID, message: "Prepared staged file for \(assetLocalID).")
        return stagedFile
    }

    func updateStagedFileUsage(
        runID: String,
        assetLocalID: String,
        usageState: StagedFileUsageState
    ) async throws {
        guard var run = await store.loadRun(runID: runID) else {
            throw AutoBackupEngineError.runNotFound
        }

        run.stagedFiles = run.stagedFiles.map { file in
            guard file.assetLocalID == assetLocalID else { return file }
            return StagedAssetFile(
                stagedFileID: file.stagedFileID,
                assetLocalID: file.assetLocalID,
                localURL: file.localURL,
                byteSize: file.byteSize,
                createdAt: file.createdAt,
                cleanupEligibleAt: file.cleanupEligibleAt,
                usageState: usageState
            )
        }
        run.updatedAt = Date()
        await store.upsertRun(run)
    }

    func markAssetCommitted(runID: String, assetLocalID: String) async throws {
        guard var run = await store.loadRun(runID: runID) else {
            throw AutoBackupEngineError.runNotFound
        }

        run.assetRecords = try run.assetRecords.map { record in
            guard record.assetLocalID == assetLocalID else { return record }
            return AutoBackupAssetRecord(
                assetLocalID: record.assetLocalID,
                state: try AutoBackupStateMachine.transition(assetState: record.state, event: .committed),
                retryCount: record.retryCount,
                updatedAt: Date()
            )
        }
        run.updatedAt = Date()
        await store.upsertRun(run)
        await recordEvent(runID: runID, message: "Committed asset \(assetLocalID).")
    }

    func markAssetFailedRetained(runID: String, assetLocalID: String, reason: String) async throws {
        guard var run = await store.loadRun(runID: runID) else {
            throw AutoBackupEngineError.runNotFound
        }

        run.assetRecords = try run.assetRecords.map { record in
            guard record.assetLocalID == assetLocalID else { return record }
            return AutoBackupAssetRecord(
                assetLocalID: record.assetLocalID,
                state: try AutoBackupStateMachine.transition(assetState: record.state, event: .failRetained),
                retryCount: record.retryCount,
                updatedAt: Date()
            )
        }
        run.lastError = reason
        run.updatedAt = Date()
        await store.upsertRun(run)
        await recordEvent(runID: runID, message: "Retained failed asset \(assetLocalID): \(reason)")
    }

    private func recordEvent(runID: String, message: String) async {
        await store.appendEvent(
            BackupEventRecord(
                eventID: UUID().uuidString,
                runID: runID,
                message: message,
                createdAt: Date()
            )
        )
    }

    private func pauseMessage(for reason: RunPauseReason) -> String {
        switch reason {
        case .receiverUnavailable:
            return "Paused because the paired Mac receiver is unavailable."
        case .receiverChanged:
            return "Paused because the backup target changed."
        case .thermal:
            return "Paused until iPhone temperature falls."
        case .appSuspended:
            return "Paused until the next background wake."
        case .manualCancel:
            return "Paused because the current automatic run was cancelled."
        }
    }

    private func eventMessage(
        for runState: AutoBackupRunState,
        reason: AutoBackupEligibilityBlockReason?
    ) -> String {
        switch (runState, reason) {
        case (.eligibilityBlocked, .batteryBelowMinimum):
            return "Waiting for battery to reach the minimum level."
        case (.eligibilityBlocked, .wiFiUnavailable):
            return "Waiting for Wi-Fi before the next automatic backup."
        case (.eligibilityBlocked, .receiverUnavailable):
            return "Waiting for the paired Mac receiver."
        case (.eligibilityBlocked, .lowPowerMode):
            return "Waiting for Low Power Mode to turn off."
        case (.eligibilityBlocked, .thermal):
            return "Waiting for iPhone temperature to fall."
        case (.preparing, _):
            return "Run became eligible and is preparing staged assets."
        case (.uploading, _):
            return "Resuming unfinished assets for upload."
        default:
            return "Automatic backup run is \(runState.rawValue)."
        }
    }
}

enum AutoBackupEngineError: Error, Equatable {
    case runNotFound
    case stagedStorageLimitExceeded(limitBytes: Int64)
}
