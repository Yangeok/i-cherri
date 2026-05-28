import Foundation
import Network

// Advertises the macOS receiver over Bonjour (mDNS) so iOS clients can discover it.
actor BonjourAdvertiser {
    static let serviceType = "_icherri._tcp"
    static let domain = "local."

    private var listener: NWListener?
    private let port: NWEndpoint.Port
    private let receiverName: String

    var onNewConnection: ((NWConnection) -> Void)?

    init(port: UInt16, receiverName: String) {
        self.port = NWEndpoint.Port(rawValue: port)!
        self.receiverName = receiverName
    }

    func start() throws {
        let params = NWParameters.tcp
        params.includePeerToPeer = true

        let listener = try NWListener(using: params, on: port)

        let service = NWListener.Service(
            name: receiverName,
            type: BonjourAdvertiser.serviceType,
            domain: BonjourAdvertiser.domain
        )
        listener.service = service

        listener.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleStateChange(state) }
        }

        listener.newConnectionHandler = { [weak self] connection in
            Task {
                await self?.handleNewConnection(connection)
            }
        }

        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
    }

    private func handleNewConnection(_ connection: NWConnection) {
        self.onNewConnection?(connection)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            break
        case .failed(let error):
            // Restart on transient failure
            if case .posix(let code) = error, code == .EADDRINUSE {
                listener?.cancel()
            }
        default:
            break
        }
    }
}
