import Foundation
import Network

public struct DiscoveredReceiver: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let endpoint: NWEndpoint

    public init(name: String, endpoint: NWEndpoint) {
        self.id = name
        self.name = name
        self.endpoint = endpoint
    }
}

// Discovers macOS receiver instances on the local network using Bonjour (mDNS).
@MainActor
public final class BonjourBrowser: ObservableObject {
    @Published public private(set) var discoveredReceivers: [DiscoveredReceiver] = []

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.icherri.bonjour-browser", qos: .userInitiated)

    public init() {}

    public func startBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = true

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_icherri._tcp", domain: "local.")
        let browser = NWBrowser(for: descriptor, using: params)

        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleStateChange(state)
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let receivers = results.compactMap { result -> DiscoveredReceiver? in
                guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                return DiscoveredReceiver(name: name, endpoint: result.endpoint)
            }
            DispatchQueue.main.async {
                self?.discoveredReceivers = receivers
            }
        }

        browser.start(queue: queue)
        self.browser = browser
    }

    public func stopBrowsing() {
        browser?.cancel()
        browser = nil
        discoveredReceivers = []
    }

    private func handleStateChange(_ state: NWBrowser.State) {
        switch state {
        case .failed:
            stopBrowsing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.startBrowsing()
            }
        default:
            break
        }
    }
}
