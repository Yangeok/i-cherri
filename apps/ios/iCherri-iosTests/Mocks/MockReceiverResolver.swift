import Foundation
import Network
@testable import iCherri_ios

public final class MockReceiverResolver: ReceiverResolver, Sendable {
    public var shouldFail = false
    public var delaySeconds: Double = 0.0
    public var errorToThrow: Error?
    public var resolvedURL: URL?

    public init(resolvedURL: URL? = nil) {
        self.resolvedURL = resolvedURL
    }

    @MainActor
    public func resolve(_ endpoint: NWEndpoint) async throws -> URL {
        if delaySeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }
        
        if shouldFail {
            throw errorToThrow ?? URLError(.cannotFindHost)
        }
        
        if let resolvedURL {
            return resolvedURL
        }
        
        return URL(string: "http://mock-receiver.local:8080")!
    }
}
