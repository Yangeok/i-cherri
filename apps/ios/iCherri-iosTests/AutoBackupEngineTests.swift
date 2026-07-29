import Foundation
import Testing
@testable import iCherri_ios

struct AutoBackupEngineTests {

    @Test("Given a scheduled run when policy is eligible then reevaluation moves the run into preparing")
    func reevaluateRunMovesScheduledRunToPreparing() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("autobackup-engine-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let store = AutoBackupJobStore(fileURL: tempDirectory.appendingPathComponent("jobs.json"))
        await store.savePolicy(.init(isEnabled: true))

        let engine = AutoBackupEngine(store: store)
        let run = await engine.ensureScheduledRun(receiverID: "receiver-1", receiverName: "MacBook Pro")

        let nextState = try await engine.reevaluateRun(
            runID: run.runID,
            runtimeSnapshot: .previewEligible
        )

        #expect(nextState == .preparing)
    }

    @Test("Given failed retained assets when requeuing then those assets return to queued state for the next run")
    func requeueFailedAssetsReturnsThemToQueuedState() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("autobackup-engine-requeue-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let store = AutoBackupJobStore(fileURL: tempDirectory.appendingPathComponent("jobs.json"))

        let now = Date(timeIntervalSince1970: 1_700_000_100)
        await store.upsertRun(
            AutoBackupRun(
                runID: "run-1",
                receiverID: "receiver-1",
                receiverName: "MacBook Pro",
                state: .partial,
                pauseReason: nil,
                createdAt: now,
                updatedAt: now,
                expiresAt: now.addingTimeInterval(3600),
                assetRecords: [
                    AutoBackupAssetRecord(assetLocalID: "asset-failed", state: .failedRetained, retryCount: 0, updatedAt: now),
                    AutoBackupAssetRecord(assetLocalID: "asset-committed", state: .committed, retryCount: 0, updatedAt: now),
                ],
                stagedFiles: [],
                uploadSessions: [],
                lastError: nil
            )
        )

        let engine = AutoBackupEngine(store: store)
        let requeuedAssetIDs = try await engine.requeueFailedAssets(runID: "run-1")
        let updatedRun = await store.loadRun(runID: "run-1")

        #expect(requeuedAssetIDs == ["asset-failed"])
        #expect(updatedRun?.assetRecords.first(where: { $0.assetLocalID == "asset-failed" })?.state == .queued)
        #expect(updatedRun?.assetRecords.first(where: { $0.assetLocalID == "asset-failed" })?.retryCount == 1)
        #expect(updatedRun?.assetRecords.first(where: { $0.assetLocalID == "asset-committed" })?.state == .committed)
    }

    @Test("Given an active run on one receiver when scheduling for a different receiver then a new run is created instead of handing off")
    func ensureScheduledRunDoesNotHandOffAcrossReceivers() async {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("autobackup-engine-cross-mac-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let store = AutoBackupJobStore(fileURL: tempDirectory.appendingPathComponent("jobs.json"))
        let engine = AutoBackupEngine(store: store)

        let firstRun = await engine.ensureScheduledRun(receiverID: "receiver-a", receiverName: "Mac A")
        let secondRun = await engine.ensureScheduledRun(receiverID: "receiver-b", receiverName: "Mac B")

        #expect(firstRun.receiverID == "receiver-a")
        #expect(secondRun.receiverID == "receiver-b")
        #expect(firstRun.runID != secondRun.runID)
    }

    @Test("Given an uploading run when pausing for thermal state and later resuming with eligibility then the run pauses and resumes cleanly")
    func pauseAndResumeRunTransitionsCleanly() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("autobackup-engine-pause-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let store = AutoBackupJobStore(fileURL: tempDirectory.appendingPathComponent("jobs.json"))
        await store.savePolicy(.init(isEnabled: true))

        let now = Date(timeIntervalSince1970: 1_700_000_200)
        await store.upsertRun(
            AutoBackupRun(
                runID: "run-pause",
                receiverID: "receiver-1",
                receiverName: "MacBook Pro",
                state: .uploading,
                pauseReason: nil,
                createdAt: now,
                updatedAt: now,
                expiresAt: now.addingTimeInterval(3600),
                assetRecords: [],
                stagedFiles: [],
                uploadSessions: [],
                lastError: nil
            )
        )

        let engine = AutoBackupEngine(store: store)
        let pausedState = try await engine.pauseRun(runID: "run-pause", reason: .thermal)
        let resumedState = try await engine.resumePausedRun(
            runID: "run-pause",
            runtimeSnapshot: .previewEligible
        )
        let updatedRun = await store.loadRun(runID: "run-pause")

        #expect(pausedState == .paused)
        #expect(resumedState == .uploading)
        #expect(updatedRun?.pauseReason == nil)
    }

    @Test("Given a staged file for an asset when staging again then the engine reuses the existing staged file")
    func stagingReusesExistingFileForSameAsset() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("autobackup-engine-stage-reuse-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let stageURL = tempDirectory.appendingPathComponent("asset-1.heic")
        try Data([0x01, 0x02, 0x03]).write(to: stageURL)

        let store = AutoBackupJobStore(fileURL: tempDirectory.appendingPathComponent("jobs.json"))
        let now = Date(timeIntervalSince1970: 1_700_000_300)
        await store.upsertRun(
            AutoBackupRun(
                runID: "run-stage",
                receiverID: "receiver-1",
                receiverName: "MacBook Pro",
                state: .preparing,
                pauseReason: nil,
                createdAt: now,
                updatedAt: now,
                expiresAt: now.addingTimeInterval(3600),
                assetRecords: [
                    AutoBackupAssetRecord(assetLocalID: "asset-1", state: .queued, retryCount: 0, updatedAt: now)
                ],
                stagedFiles: [],
                uploadSessions: [],
                lastError: nil
            )
        )

        let engine = AutoBackupEngine(store: store)
        let firstStage = try await engine.stageFile(
            runID: "run-stage",
            assetLocalID: "asset-1",
            localURL: stageURL,
            byteSize: 3,
            cleanupEligibleAt: now.addingTimeInterval(600)
        )
        let secondStage = try await engine.stageFile(
            runID: "run-stage",
            assetLocalID: "asset-1",
            localURL: stageURL,
            byteSize: 3,
            cleanupEligibleAt: now.addingTimeInterval(600)
        )

        #expect(firstStage.stagedFileID == secondStage.stagedFileID)
        #expect(await store.totalStagedBytes(runID: "run-stage") == 3)
    }

    @Test("Given a stage request above the policy limit when staging then the engine throws a staged limit error")
    func stagingAboveLimitThrowsStagedLimitError() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("autobackup-engine-stage-limit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let store = AutoBackupJobStore(fileURL: tempDirectory.appendingPathComponent("jobs.json"))
        await store.savePolicy(.init(isEnabled: true, stagedStorageLimitBytes: 5))

        let now = Date(timeIntervalSince1970: 1_700_000_400)
        await store.upsertRun(
            AutoBackupRun(
                runID: "run-limit",
                receiverID: "receiver-1",
                receiverName: "MacBook Pro",
                state: .preparing,
                pauseReason: nil,
                createdAt: now,
                updatedAt: now,
                expiresAt: now.addingTimeInterval(3600),
                assetRecords: [
                    AutoBackupAssetRecord(assetLocalID: "asset-limit", state: .queued, retryCount: 0, updatedAt: now)
                ],
                stagedFiles: [],
                uploadSessions: [],
                lastError: nil
            )
        )

        let engine = AutoBackupEngine(store: store)

        await #expect(throws: AutoBackupEngineError.stagedStorageLimitExceeded(limitBytes: 5)) {
            try await engine.stageFile(
                runID: "run-limit",
                assetLocalID: "asset-limit",
                localURL: tempDirectory.appendingPathComponent("asset-limit.mov"),
                byteSize: 6,
                cleanupEligibleAt: now.addingTimeInterval(600)
            )
        }
    }
}
