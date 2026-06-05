import Foundation
import Testing
import ICherriProtocol
@testable import iCherri_Mac

@Suite(.serialized)
struct DatabaseManagerBackupRunTests {

    @Test("Given a receiver snapshot with exact and fingerprint matches, when finalizing a backup run, then only truly missing assets remain")
    func finalizeBackupRunCountsCoveredAssets() async throws {
        let manager = DatabaseManager.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icherri-backup-run-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let databasePath = tempDirectory.appendingPathComponent("receiver.sqlite").path
        try await manager.open(at: databasePath)

        let now = Date()
        let device = DeviceInfo(deviceID: "device-1", deviceName: "Test iPhone", platform: "iOS", appVersion: "1.0")
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: device.deviceID,
                deviceName: device.deviceName,
                pairingStatus: "paired",
                createdAt: now,
                lastSeenAt: now,
                trustToken: "token-1"
            )
        )
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: "device-2",
                deviceName: "Another iPhone",
                pairingStatus: "paired",
                createdAt: now,
                lastSeenAt: now,
                trustToken: "token-2"
            )
        )

        try await manager.insertBackupAsset(
            backupAssetRecord(
                backupID: "backup-exact",
                deviceID: device.deviceID,
                assetLocalID: "exact",
                quickFingerprint: "fp-exact"
            )
        )
        try await manager.insertBackupAsset(
            backupAssetRecord(
                backupID: "backup-shared",
                deviceID: "device-2",
                assetLocalID: "shared",
                quickFingerprint: "fp-shared"
            )
        )

        let snapshotAssets = [
            asset(id: "exact", fingerprint: "fp-exact", bytes: 100),
            asset(id: "duplicate", fingerprint: "fp-shared", bytes: 200),
            asset(id: "missing", fingerprint: "fp-missing", bytes: 300)
        ]
        try await manager.replaceBackupRunSnapshot(
            runID: "run-1",
            device: device,
            librarySnapshot: CheckBatchLibrarySnapshot(totalAssetCount: snapshotAssets.count, totalAssetBytes: 600),
            candidates: snapshotAssets
        )

        let result = try await manager.finalizeBackupRun(runID: "run-1", deviceID: device.deviceID)

        #expect(result.totalAssetCount == 3)
        #expect(result.completedAssetCount == 2)
        #expect(result.missingAssetIDs == ["missing"])
    }

    @Test("Given the latest receiver snapshot when loading coverage summaries then the latest run reports current library coverage counts")
    func fetchLatestBackupCoverageSummariesUsesNewestRun() async throws {
        let manager = DatabaseManager.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icherri-backup-run-coverage-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let databasePath = tempDirectory.appendingPathComponent("receiver.sqlite").path
        try await manager.open(at: databasePath)

        let now = Date()
        let device = DeviceInfo(deviceID: "device-1", deviceName: "Test iPhone", platform: "iOS", appVersion: "1.0")
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: device.deviceID,
                deviceName: device.deviceName,
                pairingStatus: "paired",
                createdAt: now,
                lastSeenAt: now,
                trustToken: "token-1"
            )
        )
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: "device-2",
                deviceName: "Another iPhone",
                pairingStatus: "paired",
                createdAt: now,
                lastSeenAt: now,
                trustToken: "token-2"
            )
        )

        try await manager.insertBackupAsset(
            backupAssetRecord(
                backupID: "backup-exact",
                deviceID: device.deviceID,
                assetLocalID: "kept",
                quickFingerprint: "fp-kept"
            )
        )
        try await manager.insertBackupAsset(
            backupAssetRecord(
                backupID: "backup-shared",
                deviceID: "device-2",
                assetLocalID: "shared",
                quickFingerprint: "fp-shared"
            )
        )

        try await manager.replaceBackupRunSnapshot(
            runID: "run-old",
            device: device,
            librarySnapshot: CheckBatchLibrarySnapshot(totalAssetCount: 1, totalAssetBytes: 100),
            candidates: [asset(id: "old", fingerprint: "fp-old", bytes: 100)]
        )
        try await manager.replaceBackupRunSnapshot(
            runID: "run-new",
            device: device,
            librarySnapshot: CheckBatchLibrarySnapshot(totalAssetCount: 3, totalAssetBytes: 600),
            candidates: [
                asset(id: "kept", fingerprint: "fp-kept", bytes: 100),
                asset(id: "shared", fingerprint: "fp-shared", bytes: 200),
                asset(id: "missing", fingerprint: "fp-missing", bytes: 300),
            ]
        )

        let summaries = try await manager.fetchLatestBackupCoverageSummaries()
        let summary = try #require(summaries.first(where: { $0.deviceId == device.deviceID }))

        #expect(summary.runId == "run-new")
        #expect(summary.totalAssetCount == 3)
        #expect(summary.completedAssetCount == 2)
        #expect(summary.pendingAssetCount == 1)
        #expect(summary.status == "snapshot_recorded")
    }

    private func asset(id: String, fingerprint: String, bytes: Int64) -> AssetMetadata {
        AssetMetadata(
            deviceID: "device-1",
            assetLocalID: id,
            originalFilename: "\(id).JPG",
            mediaType: .photo,
            creationDate: .now,
            modificationDate: .now,
            byteSize: bytes,
            pixelWidth: 100,
            pixelHeight: 100,
            quickFingerprint: fingerprint
        )
    }

    private func backupAssetRecord(
        backupID: String,
        deviceID: String,
        assetLocalID: String,
        quickFingerprint: String
    ) -> BackupAssetRecord {
        BackupAssetRecord(
            id: nil,
            backupId: backupID,
            deviceId: deviceID,
            assetLocalId: assetLocalID,
            originalFilename: "\(assetLocalID).JPG",
            mediaType: MediaType.photo.rawValue,
            creationDate: .now,
            modificationDate: .now,
            byteSize: 100,
            durationSeconds: nil,
            pixelWidth: 100,
            pixelHeight: 100,
            quickFingerprint: quickFingerprint,
            contentSha256: "\(backupID)-sha",
            finalPath: "2026/06/\(assetLocalID).JPG",
            status: "completed",
            duplicateOfBackupId: nil,
            firstSeenAt: .now,
            completedAt: .now,
            lastError: nil
        )
    }
}
