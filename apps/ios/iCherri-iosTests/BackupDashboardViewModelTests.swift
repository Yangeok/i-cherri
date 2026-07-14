import Foundation
import Testing
import Network
@testable import iCherri_ios

@MainActor
struct BackupDashboardViewModelTests {
    @Test("Given BackupDashboardViewModel with successful MockResolver when resolving endpoint then it returns URL")
    func resolveEndpointSuccess() async throws {
        let expectedURL = URL(string: "http://my-macbook.local:8080")!
        let mockResolver = MockReceiverResolver(resolvedURL: expectedURL)
        
        let viewModel = BackupDashboardViewModel(resolver: mockResolver)
        
        let resolved = try await viewModel.resolveReceiverURLForBackup(
            pairedReceiver: nil,
            pairedReceiverID: nil,
            pairedReceiverName: "my-macbook",
            discoveredReceivers: [],
            storedReceiverURLString: nil
        )
        
        #expect(resolved == expectedURL)
    }

    @Test("Given BackupDashboardViewModel with failing MockResolver when resolving endpoint then it throws host not found error")
    func resolveEndpointFailure() async throws {
        let mockResolver = MockReceiverResolver()
        mockResolver.shouldFail = true
        mockResolver.errorToThrow = URLError(.cannotFindHost)
        
        let viewModel = BackupDashboardViewModel(resolver: mockResolver)
        
        await #expect(throws: Error.self) {
            try await viewModel.resolveReceiverURLForBackup(
                pairedReceiver: nil,
                pairedReceiverID: nil,
                pairedReceiverName: "my-macbook",
                discoveredReceivers: [],
                storedReceiverURLString: nil
            )
        }
    }
}
