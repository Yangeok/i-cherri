import Foundation
import Testing
import ICherriProtocol
@testable import iCherri_ios

struct AutoBackupStatusViewModelTests {
    @Test("Given automatic backup disabled when building summary then status explains it is off")
    func givenAutomaticBackupDisabled_whenBuildingSummary_thenStatusExplainsItIsOff() {
        let summary = AutoBackupStatusViewModel.make(
            isEnabled: false,
            receiverName: "Studio Mac",
            activeRun: nil,
            fallbackMessage: nil,
            latestEvent: nil
        )

        #expect(summary.title == "Automatic Backup Is Off")
        #expect(summary.detail.contains("Turn it on"))
        #expect(summary.symbolName == "bolt.slash.circle")
    }

    @Test("Given paused thermal run when building summary then status explains thermal wait")
    func givenPausedThermalRun_whenBuildingSummary_thenStatusExplainsThermalWait() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let run = AutoBackupRun(
            runID: "run-1",
            receiverID: "receiver-1",
            receiverName: "Studio Mac",
            state: .paused,
            pauseReason: .thermal,
            createdAt: now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(3600),
            assetRecords: [],
            stagedFiles: [],
            uploadSessions: [],
            lastError: nil
        )

        let summary = AutoBackupStatusViewModel.make(
            isEnabled: true,
            receiverName: "Studio Mac",
            activeRun: run,
            fallbackMessage: nil,
            latestEvent: nil
        )

        #expect(summary.title == "Automatic Backup Is Paused")
        #expect(summary.detail.contains("temperature"))
        #expect(summary.symbolName == "pause.circle.fill")
    }

    @Test("Given terminal partial run when formatting recent result then uploaded and retry counts are included")
    func givenTerminalPartialRun_whenFormattingRecentResult_thenUploadedAndRetryCountsAreIncluded() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let run = AutoBackupRun(
            runID: "run-2",
            receiverID: "receiver-1",
            receiverName: "Studio Mac",
            state: .partial,
            pauseReason: nil,
            createdAt: now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(3600),
            assetRecords: [
                AutoBackupAssetRecord(assetLocalID: "a", state: .committed, retryCount: 0, updatedAt: now),
                AutoBackupAssetRecord(assetLocalID: "b", state: .skippedDuplicate, retryCount: 0, updatedAt: now),
                AutoBackupAssetRecord(assetLocalID: "c", state: .failedRetained, retryCount: 1, updatedAt: now),
            ],
            stagedFiles: [],
            uploadSessions: [],
            lastError: nil
        )

        let recentResult = AutoBackupStatusViewModel.recentResultText(for: run)

        #expect(recentResult == "Last result: uploaded 1, skipped 1, retrying 1.")
    }
}
