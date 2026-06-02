import Foundation
import SwiftUI
import AppKit
import ICherriProtocol
import ICherriCore

@MainActor
final class AppCoordinator: NSObject, ObservableObject {
    static let shared = AppCoordinator()
    
    @Published var backupFolder: URL
    @Published var isServerRunning = false
    @Published var port: UInt16 = 8787 // Using 8787 as in the original Go project
    
    private var server: ReceiverHTTPServer?
    private var advertiser: BonjourAdvertiser?
    private var cleanupScheduler: CleanupScheduler?
    private var securityScopedURL: URL?
    
    private var sessionManager: SessionManager?
    private var commitProcessor: FileCommitProcessor?
    
    private var routeService: ReceiverRouteService?
    
    private override init() {
        // Resolve default path inside App Sandbox container (Documents)
        let defaultPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var resolvedFolder = defaultPath
        var resolvedScopedURL: URL? = nil
        
        // Load custom path and resolve security scoped bookmark if saved
        if let bookmarkData = UserDefaults.standard.data(forKey: "iCherriBackupFolderBookmark") {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if url.startAccessingSecurityScopedResource() {
                    resolvedScopedURL = url
                    resolvedFolder = url
                } else {
                    print("Failed to start accessing security scoped resource for saved bookmark")
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        } else if let savedPath = UserDefaults.standard.string(forKey: "iCherriBackupFolderPath") {
            resolvedFolder = URL(fileURLWithPath: savedPath)
        }
        
        self.securityScopedURL = resolvedScopedURL
        self.backupFolder = resolvedFolder
        
        super.init()
        
        // Listen to UI-driven notification center events
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenDashboardNotification), name: .openDashboard, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChangeBackupFolderNotification), name: .changeBackupFolder, object: nil)
    }
    
    func start() async {
        do {
            let backupDir = self.backupFolder
            let tmpDir = backupDir.appendingPathComponent(".tmp")

            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            
            let dbPath = backupDir.appendingPathComponent(".i-cherri.sqlite3").path
            try await DatabaseManager.shared.open(at: dbPath)
            
            let manager = SessionManager(dbManager: DatabaseManager.shared)
            self.sessionManager = manager
            
            let processor = FileCommitProcessor(backupRootURL: backupDir, dbManager: DatabaseManager.shared)
            self.commitProcessor = processor
            
            // Handlers
            let queryProcessor = CheckBatchProcessor(index: DatabaseManager.shared)
            let checkBatchHandler = CheckBatchHandler(processor: queryProcessor)
            let uploadHandler = UploadHandler(sessionManager: manager, incomingDir: tmpDir)
            let uploadStatusHandler = UploadStatusHandler(sessionManager: manager)
            let routeService = ReceiverRouteService(
                checkBatchHandler: checkBatchHandler,
                uploadHandler: uploadHandler,
                uploadStatusHandler: uploadStatusHandler,
                sessionManager: manager,
                commitProcessor: processor
            )
            self.routeService = routeService

            // HTTP Server
            let srv = ReceiverHTTPServer(port: port)
            await srv.setRouteHandler(routeService)
            try await srv.start()
            self.server = srv
            self.isServerRunning = true
            print("[AppCoordinator] HTTP Server running on port \(port)")
            // Cleanup Scheduler
            let scheduler = CleanupScheduler(sessionManager: manager, incomingDir: tmpDir)
            await scheduler.start()
            self.cleanupScheduler = scheduler
            
        } catch {
            print("[AppCoordinator] Initialization failed: \(error)")
            
            // Self-healing fallback: if we failed and were using a custom folder, revert to sandbox-safe default
            let sandboxDefault = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            if self.backupFolder != sandboxDefault {
                print("[AppCoordinator] Falling back to sandbox-safe default Documents folder")
                // Stop any accessing resource
                if let oldURL = self.securityScopedURL {
                    oldURL.stopAccessingSecurityScopedResource()
                    self.securityScopedURL = nil
                }
                self.backupFolder = sandboxDefault
                UserDefaults.standard.removeObject(forKey: "iCherriBackupFolderPath")
                UserDefaults.standard.removeObject(forKey: "iCherriBackupFolderBookmark")
                
                // Retry start
                await start()
            }
        }
    }
    
    @objc private func handleOpenDashboardNotification() {
        WindowManager.shared.showDashboard()
    }
    
    @objc private func handleChangeBackupFolderNotification() {
        selectBackupFolder()
    }
    
    func selectBackupFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose the backup root folder"
        if panel.runModal() == .OK, let url = panel.url {
            // Stop accessing old security scoped resource if any
            if let oldURL = self.securityScopedURL {
                oldURL.stopAccessingSecurityScopedResource()
            }
            
            // Start accessing new security scoped resource
            if url.startAccessingSecurityScopedResource() {
                self.securityScopedURL = url
            } else {
                print("Failed to start accessing security scoped resource for selected folder")
            }
            
            self.backupFolder = url
            UserDefaults.standard.set(url.path, forKey: "iCherriBackupFolderPath")
            print("[AppCoordinator] Backup folder changed to: \(url.path)")
            
            // Save security scoped bookmark for sandboxed access
            do {
                let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: "iCherriBackupFolderBookmark")
            } catch {
                print("Failed to save security scoped bookmark: \(error)")
            }
            
            // Restart server and other services with the new directories
            Task {
                await stopServices()
                await start()
            }
        }
    }
    
    private func stopServices() async {
        await server?.stop()
        server = nil
        isServerRunning = false
        
        await advertiser?.stop()
        advertiser = nil
        
        await cleanupScheduler?.stop()
        cleanupScheduler = nil
    }
}

private final class ReceiverRouteService: ReceiverRouteHandler, @unchecked Sendable {
    private let checkBatchHandler: CheckBatchHandler
    private let uploadHandler: UploadHandler
    private let uploadStatusHandler: UploadStatusHandler
    private let sessionManager: SessionManager
    private let commitProcessor: FileCommitProcessor

    init(
        checkBatchHandler: CheckBatchHandler,
        uploadHandler: UploadHandler,
        uploadStatusHandler: UploadStatusHandler,
        sessionManager: SessionManager,
        commitProcessor: FileCommitProcessor
    ) {
        self.checkBatchHandler = checkBatchHandler
        self.uploadHandler = uploadHandler
        self.uploadStatusHandler = uploadStatusHandler
        self.sessionManager = sessionManager
        self.commitProcessor = commitProcessor
    }

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        let path = request.path
        let method = request.method

        print("[ReceiverRouteService] HTTP Request: \(method) \(path)")

        if method == "POST" && path == "/backup/check-batch" {
            return await checkBatchHandler.handle(request)
        }

        if method == "POST" && path == "/uploads/init" {
            return await uploadHandler.handleInit(request)
        }

        if method == "GET" && path.hasPrefix("/uploads/") && path.hasSuffix("/status") {
            let components = path.split(separator: "/")
            if components.count == 3 {
                let uploadID = String(components[1])
                return await uploadStatusHandler.handle(request, uploadID: uploadID)
            }
        }

        if method == "PUT" && path.hasPrefix("/uploads/") && path.contains("/chunks/") {
            let components = path.split(separator: "/")
            if components.count == 4,
               let chunkIndex = Int(components[3]) {
                let uploadID = String(components[1])
                return await uploadHandler.handleChunk(request, uploadID: uploadID, chunkIndex: chunkIndex)
            }
        }

        if method == "POST" && path.hasPrefix("/uploads/") && path.hasSuffix("/commit") {
            let components = path.split(separator: "/")
            if components.count == 3 {
                let uploadID = String(components[1])
                return await handleCommitRequest(request, uploadID: uploadID)
            }
        }

        if method == "POST" && path == "/pair" {
            return await handlePairRequest(request)
        }

        return .notFound
    }

    private func handlePairRequest(_ request: HTTPRequest) async -> HTTPResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let body = try? decoder.decode(PairingStartRequest.self, from: request.body) else {
            return .error(code: "invalid_body", message: "Failed to parse PairingStartRequest")
        }
        
        let now = Date()
        let trustToken = UUID().uuidString
        let record = PairedDeviceRecord(
            id: nil,
            deviceId: body.deviceID,
            deviceName: body.deviceName,
            pairingStatus: "paired",
            createdAt: now,
            lastSeenAt: now,
            trustToken: trustToken
        )
        
        do {
            try await DatabaseManager.shared.upsertDevice(record)
            print("[ReceiverRouteService] Device paired: \(body.deviceName) (\(body.deviceID))")
            await MainActor.run {
                NotificationCenter.default.post(name: .receiverDataDidChange, object: nil)
            }
            
            let response = PairingConfirmResponse(status: "paired", trustToken: trustToken)
            return (try? HTTPResponse.json(response)) ?? .error(code: "encode_error", message: "Encode failed", status: 500)
        } catch {
            return .error(code: "pair_error", message: error.localizedDescription, status: 500)
        }
    }
    
    private func handleCommitRequest(_ request: HTTPRequest, uploadID: String) async -> HTTPResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let body = try? decoder.decode(CommitUploadRequest.self, from: request.body) else {
            return .error(code: "invalid_body", message: "Failed to parse CommitUploadRequest")
        }
        
        do {
            guard let session = try await sessionManager.fetchSession(uploadID: uploadID) else {
                return .error(code: "session_not_found", message: "Session not found", status: 404)
            }
            
            guard let metadataData = session.metadataJson.data(using: .utf8),
                  let metadata = try? JSONDecoder().decode(AssetMetadata.self, from: metadataData) else {
                return .error(code: "invalid_session_metadata", message: "Failed to decode session metadata", status: 500)
            }
            
            let input = FileCommitProcessor.CommitInput(
                uploadID: uploadID,
                deviceID: session.deviceID,
                assetLocalID: session.assetLocalID,
                originalFilename: metadata.originalFilename,
                mediaType: metadata.mediaType,
                creationDate: metadata.creationDate,
                modificationDate: metadata.modificationDate,
                byteSize: metadata.byteSize,
                pixelWidth: metadata.pixelWidth,
                pixelHeight: metadata.pixelHeight,
                quickFingerprint: metadata.quickFingerprint,
                durationSeconds: metadata.durationSeconds,
                tempPath: session.tempPath,
                expectedByteSize: session.expectedByteSize,
                expectedSHA256: body.finalContentHash
            )
            
            let result = try await commitProcessor.commit(input)
            switch result {
            case .success(let backupID, let displayPath):
                try await sessionManager.completeSession(uploadID: uploadID)
                await MainActor.run {
                    NotificationCenter.default.post(name: .receiverDataDidChange, object: nil)
                }
                
                let response = CommitUploadResponse.success(backupID: backupID, displayPath: displayPath)
                return (try? HTTPResponse.json(response)) ?? .error(code: "encode_error", message: "Encode failed", status: 500)
            case .checksumMismatch:
                try? FileManager.default.removeItem(atPath: session.tempPath)
                try? await sessionManager.failSession(
                    uploadID: uploadID,
                    errorCode: "checksum_mismatch",
                    errorMessage: "SHA256 checksum mismatch"
                )
                return .error(code: "checksum_mismatch", message: "SHA256 checksum mismatch", status: 400)
            case .sizeMismatch:
                try? FileManager.default.removeItem(atPath: session.tempPath)
                try? await sessionManager.failSession(
                    uploadID: uploadID,
                    errorCode: "size_mismatch",
                    errorMessage: "File size mismatch"
                )
                return .error(code: "size_mismatch", message: "File size mismatch", status: 400)
            }
        } catch {
            try? await sessionManager.failSession(
                uploadID: uploadID,
                errorCode: "commit_error",
                errorMessage: error.localizedDescription
            )
            return .error(code: "commit_error", message: error.localizedDescription, status: 500)
        }
    }
}
