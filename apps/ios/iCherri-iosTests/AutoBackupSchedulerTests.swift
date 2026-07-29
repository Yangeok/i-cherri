import Foundation
import Testing
@testable import iCherri_ios

@MainActor
struct AutoBackupSchedulerTests {

    @Test("Given a scheduler when building the processing request then network is required and external power is optional")
    func buildProcessingRequestUsesExpectedPolicy() {
        let scheduler = AutoBackupScheduler(engine: AutoBackupEngine(store: AutoBackupJobStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))))
        let request = scheduler.buildProcessingRequest()

        #expect(request.identifier == AutoBackupScheduler.processingTaskIdentifier)
        #expect(request.requiresNetworkConnectivity)
        #expect(!request.requiresExternalPower)
    }
}
