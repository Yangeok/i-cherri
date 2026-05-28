import Foundation
import Network
import ICherriProtocol

// Basic HTTP request representation parsed from raw TCP bytes.
struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
    var deviceID: String? { headers["x-icherri-device-id"] }
    var trustToken: String? { headers["x-icherri-token"] }
}

// Closure-based response builder.
struct HTTPResponse {
    let statusCode: Int
    let body: Data
    let contentType: String

    static func json<T: Encodable>(_ value: T, status: Int = 200) throws -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return HTTPResponse(statusCode: status, body: data, contentType: "application/json")
    }

    static func error(code: String, message: String, status: Int = 400) -> HTTPResponse {
        let body = #"{"code":"\#(code)","message":"\#(message)"}"#
        return HTTPResponse(statusCode: status, body: Data(body.utf8), contentType: "application/json")
    }

    static let unauthorized = HTTPResponse.error(code: "unauthorized", message: "Invalid device credentials", status: 401)
    static let notFound = HTTPResponse.error(code: "not_found", message: "Endpoint not found", status: 404)
    static let methodNotAllowed = HTTPResponse.error(code: "method_not_allowed", message: "Method not allowed", status: 405)

    func serialize() -> Data {
        let statusLine = "HTTP/1.1 \(statusCode) \(reasonPhrase)\r\n"
        let headers = [
            "Content-Type: \(contentType)",
            "Content-Length: \(body.count)",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        var result = Data((statusLine + headers).utf8)
        result.append(body)
        return result
    }

    private var reasonPhrase: String {
        switch statusCode {
        case 200: return "OK"
        case 202: return "Accepted"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}

// Routes HTTP requests to registered handlers.
actor ReceiverHTTPServer {
    private var listener: NWListener?
    let port: UInt16

    // Injected route handlers
    var routeHandler: ReceiverRouteHandler?

    func setRouteHandler(_ handler: ReceiverRouteHandler) {
        self.routeHandler = handler
    }

    init(port: UInt16 = 48372) {
        self.port = port
    }

    func start() throws {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

        let hostName = Host.current().localizedName ?? "iCherri Receiver"
        let service = NWListener.Service(
            name: hostName,
            type: "_icherri._tcp",
            domain: "local."
        )
        listener.service = service

        listener.stateUpdateHandler = { state in
            if case .failed(let err) = state {
                print("[ReceiverHTTPServer] Listener failed: \(err)")
            } else if state == .ready {
                print("[ReceiverHTTPServer] Listener ready on port \(self.port) and advertising Bonjour service")
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection) }
        }

        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection Handling

    private func accept(_ connection: NWConnection) async {
        connection.start(queue: .global(qos: .userInitiated))
        guard let requestData = await receive(from: connection) else {
            connection.cancel()
            return
        }
        guard let request = parseHTTP(requestData) else {
            connection.cancel()
            return
        }

        let response: HTTPResponse
        if let handler = routeHandler {
            response = await handler.handle(request)
        } else {
            response = .notFound
        }

        await send(response.serialize(), on: connection)
        connection.cancel()
    }

    private func receive(from connection: NWConnection) async -> Data? {
        await withCheckedContinuation { continuation in
            var buffer = Data()

            func readMore() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                    if let data { buffer.append(data) }
                    if isComplete || error != nil || Self.isHTTPComplete(buffer) {
                        continuation.resume(returning: buffer.isEmpty ? nil : buffer)
                    } else {
                        readMore()
                    }
                }
            }
            readMore()
        }
    }

    private func send(_ data: Data, on connection: NWConnection) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.send(content: data, completion: .contentProcessed { _ in
                continuation.resume()
            })
        }
    }

    // Detects if headers + body are fully received.
    private static func isHTTPComplete(_ data: Data) -> Bool {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return false }
        let headerSection = String(data: data[..<headerEnd.lowerBound], encoding: .utf8) ?? ""
        let bodyStart = headerEnd.upperBound
        if let contentLengthLine = headerSection.components(separatedBy: "\r\n")
            .first(where: { $0.lowercased().hasPrefix("content-length:") }),
           let lengthStr = contentLengthLine.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces),
           let length = Int(lengthStr) {
            return data.count >= bodyStart + length
        }
        return true
    }

    // MARK: - HTTP Parser

    private func parseHTTP(_ data: Data) -> HTTPRequest? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let parts = raw.components(separatedBy: "\r\n\r\n")
        guard parts.count >= 1 else { return nil }

        let headerLines = parts[0].components(separatedBy: "\r\n")
        guard let requestLine = headerLines.first else { return nil }

        let tokens = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard tokens.count >= 2 else { return nil }

        let method = tokens[0]
        let path = tokens[1]

        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1).map(String.init)
            if pair.count == 2 {
                headers[pair[0].lowercased().trimmingCharacters(in: .whitespaces)] = pair[1].trimmingCharacters(in: .whitespaces)
            }
        }

        let bodyData: Data
        if parts.count > 1, let bodyStr = parts[1...].joined(separator: "\r\n\r\n").data(using: .utf8) {
            bodyData = bodyStr
        } else {
            bodyData = Data()
        }

        return HTTPRequest(method: method, path: path, headers: headers, body: bodyData)
    }
}

// Protocol that the route dispatcher conforms to.
protocol ReceiverRouteHandler: AnyObject, Sendable {
    func handle(_ request: HTTPRequest) async -> HTTPResponse
}
