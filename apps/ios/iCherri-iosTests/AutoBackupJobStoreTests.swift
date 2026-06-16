import Foundation
import Testing
import ICherriProtocol
@testable import iCherri_ios

struct AutoBackupJobStoreTests {

    @Test("Given a stored run when reloading the store then the run and staged byte totals survive")
    func persistsRunsAndStagedBytes() async {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("autobackup-job-store-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("auto-backup-jobs.json")

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = AutoBackupJobStore(fileURL: fileURL)
        let run = AutoBackupRun(
            runID: "run-1",
            receiverID: "receiver-1",
            receiverName: "Mac mini",
            state: .scheduled,
            pauseReason: nil,
            createdAt: now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(60),
            assetRecords: [],
            stagedFiles: [
                StagedAssetFile(
                    stagedFileID: "stage-1",
                    assetLocalID: "asset-1",
                    localURL: tempDirectory.appendingPathComponent("asset-1.heic"),
                    byteSize: 512,
                    createdAt: now,
                    cleanupEligibleAt: now.addingTimeInterval(60),
                    usageState: .ready
                )
            ],
            uploadSessions: [],
            lastError: nil
        )

        await store.upsertRun(run)

        let reloadedStore = AutoBackupJobStore(fileURL: fileURL)
        let reloadedRun = await reloadedStore.loadRun(runID: "run-1")

        #expect(reloadedRun?.receiverID == "receiver-1")
        #expect(await reloadedStore.totalStagedBytes(runID: "run-1") == 512)
    }

    @Test("Given a receiver selection snapshot when reloading the store then receiver and trust token references survive")
    func persistsReceiverSelectionSnapshot() async {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("autobackup-selection-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("auto-backup-jobs.json")

        let store = AutoBackupJobStore(fileURL: fileURL)
        await store.saveReceiverSelection(
            AutoBackupReceiverSelection(
                receiverID: "receiver-1",
                receiverName: "Mac mini",
                receiverURLString: "http://192.168.0.4:24810",
                trustTokenStorageKey: "iCherriTrustToken"
            )
        )

        let reloadedStore = AutoBackupJobStore(fileURL: fileURL)
        let selection = await reloadedStore.loadReceiverSelection()

        #expect(selection?.receiverID == "receiver-1")
        #expect(selection?.receiverName == "Mac mini")
        #expect(selection?.trustTokenStorageKey == "iCherriTrustToken")
    }

    @Test("Given an expired run when expiring stale runs then the run state becomes expired")
    func expiresStaleRuns() async {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("autobackup-expiry-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("auto-backup-jobs.json")

        let now = Date(timeIntervalSince1970: 1_700_000_500)
        let store = AutoBackupJobStore(fileURL: fileURL)
        await store.upsertRun(
            AutoBackupRun(
                runID: "run-expired",
                receiverID: "receiver-1",
                receiverName: "Mac mini",
                state: .paused,
                pauseReason: .receiverUnavailable,
                createdAt: now.addingTimeInterval(-7200),
                updatedAt: now.addingTimeInterval(-7200),
                expiresAt: now.addingTimeInterval(-60),
                assetRecords: [],
                stagedFiles: [],
                uploadSessions: [],
                lastError: nil
            )
        )

        let expiredRunIDs = await store.expireRuns(olderThan: now)
        let expiredRun = await store.loadRun(runID: "run-expired")

        #expect(expiredRunIDs == ["run-expired"])
        #expect(expiredRun?.state == .expired)
    }
}
