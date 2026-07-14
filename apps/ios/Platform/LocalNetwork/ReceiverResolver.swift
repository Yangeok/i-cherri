import Foundation
import Network

protocol ReceiverResolver: Sendable {
    func resolve(_ endpoint: NWEndpoint) async throws -> URL
}

public final class BonjourReceiverResolver: ReceiverResolver, Sendable {
    private final class ResolversHolder: @unchecked Sendable {
        static let shared = ResolversHolder()
        private let lock = NSLock()
        private var resolvers: [NetService: AnyObject] = [:]
        
        func add(service: NetService, delegate: AnyObject) {
            lock.lock()
            resolvers[service] = delegate
            lock.unlock()
        }
        
        func remove(service: NetService) {
            lock.lock()
            resolvers.removeValue(forKey: service)
            lock.unlock()
        }
    }
    
    public init() {}
    
    public func resolve(_ endpoint: NWEndpoint) async throws -> URL {
        guard case .service(let name, let type, let domain, _) = endpoint else {
            throw URLError(.cannotFindHost)
        }
        
        let service = NetService(domain: domain, type: type, name: name)
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                final class NetServiceDelegateImpl: NSObject, NetServiceDelegate, @unchecked Sendable {
                    private let completion: @Sendable (Result<URL, Error>) -> Void
                    private let lock = NSLock()
                    private var hasCompleted = false
                    private let service: NetService
                    
                    init(service: NetService, completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
                        self.service = service
                        self.completion = completion
                    }
                    
                    private func cleanup() {
                        ResolversHolder.shared.remove(service: service)
                    }
                    
                    func netServiceDidResolveAddress(_ sender: NetService) {
                        lock.lock()
                        guard !hasCompleted else {
                            lock.unlock()
                            return
                        }
                        hasCompleted = true
                        lock.unlock()
                        
                        defer { cleanup() }
                        
                        guard let hostName = sender.hostName else {
                            completion(.failure(URLError(.cannotFindHost)))
                            return
                        }
                        
                        let port = sender.port
                        let cleanHost = hostName.hasSuffix(".") ? String(hostName.dropLast()) : hostName
                        
                        if let url = URL(string: "http://\(cleanHost):\(port)") {
                            completion(.success(url))
                        } else {
                            completion(.failure(URLError(.badURL)))
                        }
                    }
                    
                    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
                        lock.lock()
                        guard !hasCompleted else {
                            lock.unlock()
                            return
                        }
                        hasCompleted = true
                        lock.unlock()
                        
                        cleanup()
                        completion(.failure(URLError(.cannotFindHost)))
                    }
                }
                
                let delegate = NetServiceDelegateImpl(service: service) { result in
                    continuation.resume(with: result)
                }
                
                service.delegate = delegate
                ResolversHolder.shared.add(service: service, delegate: delegate)
                service.resolve(withTimeout: 4.0)
            }
        } onCancel: {
            service.stop()
            ResolversHolder.shared.remove(service: service)
        }
    }
}
