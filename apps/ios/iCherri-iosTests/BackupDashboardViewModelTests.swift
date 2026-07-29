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

    @Test("Given BackupDashboardViewModel with delayed MockResolver when resolving endpoint and task is cancelled then it throws cancellation error")
    func resolveEndpointCancellation() async throws {
        let mockResolver = MockReceiverResolver()
        mockResolver.delaySeconds = 3.0
        
        let viewModel = BackupDashboardViewModel(resolver: mockResolver)
        
        let task = Task {
            try await viewModel.resolveReceiverURLForBackup(
                pairedReceiver: nil,
                pairedReceiverID: nil,
                pairedReceiverName: "my-macbook",
                discoveredReceivers: [],
                storedReceiverURLString: nil
            )
        }
        
        try await Task.sleep(nanoseconds: 500_000_000)
        task.cancel()
        
        await #expect(throws: Error.self) {
            try await task.value
        }
    }

    @Test("Given BackupDashboardViewModel with extremely delayed MockResolver when resolving endpoint then it triggers timeout error")
    func resolveEndpointTimeout() async throws {
        let mockResolver = MockReceiverResolver()
        mockResolver.delaySeconds = 6.0
        
        let viewModel = BackupDashboardViewModel(resolver: mockResolver)
        
        let startTime = Date()
        
        do {
            _ = try await viewModel.resolveReceiverURLForBackup(
                pairedReceiver: nil,
                pairedReceiverID: nil,
                pairedReceiverName: "my-macbook",
                discoveredReceivers: [],
                storedReceiverURLString: nil
            )
            Issue.record("Expected timeout error to be thrown")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            #expect(elapsed >= 3.5 && elapsed <= 5.5)
            
            if let urlError = error as? URLError {
                #expect(urlError.code == .timedOut || urlError.code == .cancelled || urlError.code == .cannotFindHost)
            }
        }
    }
}
