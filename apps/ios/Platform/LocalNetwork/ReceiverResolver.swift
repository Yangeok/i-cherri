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
        
        final class SafeContinuation<T, E: Error>: @unchecked Sendable {
            private let lock = NSLock()
            private var continuation: CheckedContinuation<T, E>?
            
            init() {}
            
            func setContinuation(_ continuation: CheckedContinuation<T, E>) {
                lock.lock()
                self.continuation = continuation
                lock.unlock()
            }
            
            func resume(returning value: T) {
                lock.lock()
                if let continuation = self.continuation {
                    self.continuation = nil
                    lock.unlock()
                    continuation.resume(returning: value)
                } else {
                    lock.unlock()
                }
            }
            
            func resume(throwing error: E) {
                lock.lock()
                if let continuation = self.continuation {
                    self.continuation = nil
                    lock.unlock()
                    continuation.resume(throwing: error)
                } else {
                    lock.unlock()
                }
            }
        }

        let safeContinuation = SafeContinuation<URL, Error>()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                safeContinuation.setContinuation(continuation)
                
                final class NetServiceDelegateImpl: NSObject, NetServiceDelegate, @unchecked Sendable {
                    private let safeContinuation: SafeContinuation<URL, Error>
                    private let lock = NSLock()
                    private var hasCompleted = false
                    private let service: NetService
                    
                    init(service: NetService, safeContinuation: SafeContinuation<URL, Error>) {
                        self.service = service
                        self.safeContinuation = safeContinuation
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
                            safeContinuation.resume(throwing: URLError(.cannotFindHost))
                            return
                        }
                        
                        let port = sender.port
                        let cleanHost = hostName.hasSuffix(".") ? String(hostName.dropLast()) : hostName
                        
                        if let url = URL(string: "http://\(cleanHost):\(port)") {
                            safeContinuation.resume(returning: url)
                        } else {
                            safeContinuation.resume(throwing: URLError(.badURL))
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
                        safeContinuation.resume(throwing: URLError(.cannotFindHost))
                    }
                }
                
                let delegate = NetServiceDelegateImpl(service: service, safeContinuation: safeContinuation)
                
                service.delegate = delegate
                ResolversHolder.shared.add(service: service, delegate: delegate)
                
                if Task.isCancelled {
                    service.stop()
                    ResolversHolder.shared.remove(service: service)
                    safeContinuation.resume(throwing: URLError(.cancelled))
                    return
                }
                
                service.resolve(withTimeout: 4.0)
            }
        } onCancel: {
            service.stop()
            ResolversHolder.shared.remove(service: service)
            safeContinuation.resume(throwing: URLError(.cancelled))
        }
    }
}
