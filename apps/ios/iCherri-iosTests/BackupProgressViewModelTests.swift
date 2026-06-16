import Foundation
import Testing
import ICherriProtocol
@testable import iCherri_ios

@MainActor
struct BackupProgressViewModelTests {
    private func makeAsset(
        id: String,
        mediaType: MediaType = .photo,
        byteSize: Int64
    ) -> AssetMetadata {
        AssetMetadata(
            deviceID: "device",
            assetLocalID: id,
            originalFilename: "\(id).jpg",
            mediaType: mediaType,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            modificationDate: Date(timeIntervalSince1970: 1_700_000_000),
            byteSize: byteSize,
            pixelWidth: 4032,
            pixelHeight: 3024,
            quickFingerprint: id,
            durationSeconds: mediaType == .video ? 12 : nil
        )
    }

    @Test("Given many small photos when choosing upload concurrency then policy scales up to four")
    func givenManySmallPhotos_whenChoosingUploadConcurrency_thenPolicyScalesUpToFour() async throws {
        // Given
        let assets = (0..<24).map { makeAsset(id: "photo-\($0)", byteSize: 3_000_000) }

        // When
        let concurrency = UploadConcurrencyPolicy.recommendedConcurrency(for: assets[...])

        // Then
        #expect(concurrency == 4)
    }

    @Test("Given videos in the queue when choosing upload concurrency then policy stays conservative")
    func givenVideosInQueue_whenChoosingUploadConcurrency_thenPolicyStaysConservative() async throws {
        // Given
        let assets = [
            makeAsset(id: "video-1", mediaType: .video, byteSize: 900_000_000),
            makeAsset(id: "video-2", mediaType: .video, byteSize: 700_000_000),
            makeAsset(id: "photo-1", byteSize: 4_000_000),
        ]

        // When
        let concurrency = UploadConcurrencyPolicy.recommendedConcurrency(for: assets[...])

        // Then
        #expect(concurrency == 2)
    }

    @Test("Given scanning phase when total library size becomes known then transfer text shows full library size")
    func givenScanningPhase_whenTotalLibrarySizeBecomesKnown_thenTransferTextShowsFullLibrarySize() async throws {
        // Given
        let viewModel = BackupProgressViewModel(totalCount: 20_173)
        viewModel.setPhase(.scanning)

        // When
        viewModel.setTotalBytes(64_321_000_000)

        // Then
        #expect(viewModel.transferStatusText == "Library size 64.3 GB")
        #expect(viewModel.trailingStatusText == "Scanning")
        #expect(viewModel.progress == 0)
    }

    @Test("Given checking phase when duplicates are already backed up then overall progress uses library count and uploaded badge stays session-only")
    func givenCheckingPhase_whenDuplicatesAlreadyBackedUp_thenOverallProgressUsesLibraryCountAndUploadedBadgeStaysSessionOnly() async throws {
        // Given
        let viewModel = BackupProgressViewModel(totalCount: 20_173)

        // When
        viewModel.update(
            filename: "Checking existing backups...",
            completed: 95,
            success: 95,
            duplicates: 5_000,
            failed: 0,
            overallBackedUpCount: 5_095,
            phase: .checking,
            bytesPerSecond: 0
        )

        // Then
        #expect(viewModel.overallBackedUpCount == 5_095)
        #expect(viewModel.sessionUploadedCount == 95)
        #expect(viewModel.duplicateCount == 5_000)
        #expect(viewModel.trailingStatusText == "Checking")
        #expect(viewModel.transferStatusText == "Comparing with Mac...")
    }

    @Test("Given uploading phase when bytes are sent then transfer text uses sent bytes and completion stays false until total count is reached")
    func givenUploadingPhase_whenBytesAreSent_thenTransferTextUsesSentBytesAndCompletionStaysFalseUntilTotalCountIsReached() async throws {
        // Given
        let viewModel = BackupProgressViewModel(totalCount: 10)
        viewModel.setTotalBytes(12_500_000)

        // When
        viewModel.update(
            filename: "IMG_1022.JPG",
            completed: 3,
            success: 1,
            duplicates: 2,
            failed: 0,
            overallBackedUpCount: 3,
            phase: .uploading,
            bytesPerSecond: 2_500_000,
            sentBytes: 3_100_000,
            totalBytes: 12_500_000,
            activeUploads: 1,
            activeUploadItems: [
                ActiveUploadProgressItem(
                    id: "upload-1",
                    assetLocalID: "asset-1",
                    filename: "IMG_1022.JPG",
                    sentBytes: 3_100_000,
                    totalBytes: 12_500_000,
                    bytesPerSecond: 2_500_000
                )
            ]
        )

        // Then
        #expect(viewModel.formattedTransfer == "3.1 MB / 12.5 MB")
        #expect(viewModel.transferStatusText == "3.1 MB / 12.5 MB")
        #expect(viewModel.trailingStatusText == "2.5 MB/s")
        #expect(viewModel.isComplete == false)
        #expect(viewModel.activeUploadCount == 1)
    }

    @Test("Given an active backup when the run fails then phase becomes failed and cancellation is disabled")
    func givenActiveBackup_whenRunFails_thenPhaseBecomesFailedAndCancellationIsDisabled() async throws {
        // Given
        let viewModel = BackupProgressViewModel(totalCount: 10)
        viewModel.setPhase(.uploading)

        // When
        viewModel.markRunFailed("Commit failed: size_mismatch.")

        // Then
        #expect(viewModel.phase == .failed)
        #expect(viewModel.errorMessage == "Commit failed: size_mismatch.")
        #expect(viewModel.isComplete)
        #expect(viewModel.canCancel == false)
        #expect(viewModel.trailingStatusText == "Failed")
    }

    @Test("Given automatic backup summary when assigning it to progress view model then the status banner state is retained")
    func givenAutomaticBackupSummary_whenAssigningItToProgressViewModel_thenTheStatusBannerStateIsRetained() async throws {
        let viewModel = BackupProgressViewModel(totalCount: 10)
        let status = AutoBackupStatusViewModel(
            title: "Automatic Backup Is Paused",
            detail: "Paused until iPhone temperature falls.",
            symbolName: "pause.circle.fill"
        )

        viewModel.setAutoBackupStatus(status)

        #expect(viewModel.autoBackupStatus == status)
    }
}
