import Foundation
import Testing
import ICherriProtocol
@testable import iCherri_ios

struct ResumableUploadManagerTests {
    @Test("Given receiver progress ahead of the local offset when recovering then upload resumes from the receiver offset")
    func recoveryResumesFromReceiverOffset() throws {
        let status = UploadStatusResponse(
            uploadID: "upload-1",
            status: "receiving",
            receivedBytes: 4_096,
            expiresAt: Date().addingTimeInterval(300)
        )

        let disposition = try ResumableUploadManager.recoveryDisposition(
            currentOffset: 2_048,
            totalSize: 8_192,
            status: status,
            underlyingError: ChunkUploadError.serverError(500)
        )

        #expect(disposition == .resumeFrom(4_096))
    }

    @Test("Given receiver progress equal to the local offset after a transport error when recovering then the manager retries from the same offset")
    func recoveryRetriesSameOffsetAfterTransportError() throws {
        let status = UploadStatusResponse(
            uploadID: "upload-2",
            status: "paused",
            receivedBytes: 2_048,
            expiresAt: Date().addingTimeInterval(300)
        )

        let disposition = try ResumableUploadManager.recoveryDisposition(
            currentOffset: 2_048,
            totalSize: 8_192,
            status: status,
            underlyingError: URLError(.networkConnectionLost)
        )

        #expect(disposition == .retrySameOffset)
    }

    @Test("Given a conflict response with no receiver progress when recovering then the original conflict is surfaced")
    func recoverySurfacesConflictWithoutProgress() {
        let status = UploadStatusResponse(
            uploadID: "upload-3",
            status: "receiving",
            receivedBytes: 2_048,
            expiresAt: Date().addingTimeInterval(300)
        )

        #expect(throws: ChunkUploadError.serverError(409)) {
            _ = try ResumableUploadManager.recoveryDisposition(
                currentOffset: 2_048,
                totalSize: 8_192,
                status: status,
                underlyingError: ChunkUploadError.serverError(409)
            )
        }
    }

    @Test("Given an expired receiver session when recovering then the upload fails as expired")
    func recoveryFailsExpiredSession() {
        let status = UploadStatusResponse(
            uploadID: "upload-4",
            status: "expired",
            receivedBytes: 2_048,
            expiresAt: Date().addingTimeInterval(-5)
        )

        #expect(throws: ResumableUploadError.sessionExpired) {
            _ = try ResumableUploadManager.recoveryDisposition(
                currentOffset: 2_048,
                totalSize: 8_192,
                status: status,
                underlyingError: URLError(.networkConnectionLost)
            )
        }
    }

    @Test("Given a fully received upload when recovering then the manager can commit without re-sending chunks")
    func recoveryCompletesWithoutMoreChunks() throws {
        let status = UploadStatusResponse(
            uploadID: "upload-5",
            status: "receiving",
            receivedBytes: 8_192,
            expiresAt: Date().addingTimeInterval(300)
        )

        let disposition = try ResumableUploadManager.recoveryDisposition(
            currentOffset: 4_096,
            totalSize: 8_192,
            status: status,
            underlyingError: URLError(.networkConnectionLost)
        )

        #expect(disposition == .uploadFinished)
    }
}
