import Foundation
import Testing
import ICherriProtocol
@testable import iCherri_Mac

struct BackupRunProgressStoreTests {

    @Test("Given already-backed-up and duplicate bytes, when snapshot requested, then overall progress includes them plus active upload bytes")
    func snapshotIncludesBackedUpAndActiveSessionBytes() async throws {
        let store = BackupRunProgressStore()
        let device = DeviceInfo(deviceID: "device-1", deviceName: "Test iPhone", platform: "iOS", appVersion: "1.0")
        let candidates = [
            asset(id: "a1", bytes: 100),
            asset(id: "a2", bytes: 200),
            asset(id: "a3", bytes: 300)
        ]
        let request = CheckBatchRequest(
            device: device,
            candidates: candidates,
            librarySnapshot: CheckBatchLibrarySnapshot(totalAssetCount: 10, totalAssetBytes: 1_000)
        )
        let response = CheckBatchResponse(
            requiredUploads: [UploadRequirement(assetLocalID: "a3", uploadReason: .notFound)],
            alreadyBackedUp: ["a1"],
            duplicates: ["a2"]
        )

        await store.recordCheckBatch(request: request, response: response)

        let activeSession = UploadSessionRecord(
            uploadId: "upload-1",
            deviceId: device.deviceID,
            assetLocalId: "a3",
            tempPath: "/tmp/a3",
            expectedByteSize: 300,
            receivedBytes: 120,
            chunkSize: 1,
            status: "receiving",
            createdAt: .now,
            updatedAt: .now,
            expiresAt: .now.addingTimeInterval(60),
            metadataJson: "{}",
            lastError: nil
        )

        let snapshot = await store.snapshot(
            activeSessions: [activeSession],
            coveredBytesByDeviceID: [device.deviceID: 700]
        )

        #expect(snapshot?.totalBytes == 1_000)
        #expect(snapshot?.completedBytes == 820)
        #expect(snapshot?.fractionCompleted == 0.82)
    }

    @Test("Given a committed upload, when active sessions disappear, then completed bytes stay counted")
    func snapshotIncludesCommittedUploadsAfterSessionRemoval() async throws {
        let store = BackupRunProgressStore()
        let device = DeviceInfo(deviceID: "device-1", deviceName: "Test iPhone", platform: "iOS", appVersion: "1.0")
        let candidates = [
            asset(id: "a1", bytes: 150),
            asset(id: "a2", bytes: 250)
        ]
        let request = CheckBatchRequest(
            device: device,
            candidates: candidates,
            librarySnapshot: CheckBatchLibrarySnapshot(totalAssetCount: 4, totalAssetBytes: 1_000)
        )
        let response = CheckBatchResponse(
            requiredUploads: [
                UploadRequirement(assetLocalID: "a1", uploadReason: .notFound),
                UploadRequirement(assetLocalID: "a2", uploadReason: .notFound)
            ]
        )

        await store.recordCheckBatch(request: request, response: response)
        await store.markUploaded(deviceID: device.deviceID, assetLocalID: "a1")

        let remainingSession = UploadSessionRecord(
            uploadId: "upload-2",
            deviceId: device.deviceID,
            assetLocalId: "a2",
            tempPath: "/tmp/a2",
            expectedByteSize: 250,
            receivedBytes: 50,
            chunkSize: 1,
            status: "receiving",
            createdAt: .now,
            updatedAt: .now,
            expiresAt: .now.addingTimeInterval(60),
            metadataJson: "{}",
            lastError: nil
        )

        let snapshot = await store.snapshot(
            activeSessions: [remainingSession],
            coveredBytesByDeviceID: [device.deviceID: 600]
        )

        #expect(snapshot?.totalBytes == 1_000)
        #expect(snapshot?.completedBytes == 800)
        #expect(snapshot?.fractionCompleted == 0.8)
    }

    private func asset(id: String, bytes: Int64) -> AssetMetadata {
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
            quickFingerprint: id
        )
    }
}
