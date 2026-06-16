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

        let nextState = try await reevaluateRun(runID: run.runID, runtimeSnapshot: runtimeSnapshot)
        guard var updatedRun = await store.loadRun(runID: run.runID) else {
            throw AutoBackupEngineError.runNotFound
        }
        updatedRun.state = nextState
        updatedRun.updatedAt = Date()
        await store.upsertRun(updatedRun)
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
        return nextState
    }
}

enum AutoBackupEngineError: Error, Equatable {
    case runNotFound
}
