import Foundation
import Testing
import ICherriProtocol

struct AutoBackupReceiverContractTests {

    @Test("Given upload init and commit requests when auto backup context is present then DTOs preserve run-scoped metadata")
    func preservesRunScopedContextInDTOs() {
        let device = DeviceInfo(deviceID: "device-1", deviceName: "iPhone", platform: "iOS", appVersion: "1.0")
        let asset = AssetMetadata(
            deviceID: "device-1",
            assetLocalID: "asset-1",
            originalFilename: "IMG_0001.HEIC",
            mediaType: .photo,
            creationDate: .now,
            modificationDate: .now,
            byteSize: 1_024,
            pixelWidth: 100,
            pixelHeight: 100,
            quickFingerprint: "fp-1"
        )
        let context = AutoBackupRunContext(
            backupRunID: "run-1",
            receiverID: "receiver-1",
            clientSessionID: "session-1"
        )

        let initRequest = UploadInitRequest(
            backupRunContext: context,
            device: device,
            asset: asset,
            filename: asset.originalFilename
        )
        let commitRequest = CommitUploadRequest(
            backupRunContext: context,
            uploadID: "upload-1",
            assetLocalID: asset.assetLocalID,
            finalByteSize: asset.byteSize,
            finalContentHash: "sha256"
        )

        #expect(initRequest.backupRunContext == context)
        #expect(commitRequest.backupRunContext == context)
    }
}
