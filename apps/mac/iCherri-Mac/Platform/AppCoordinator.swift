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
    
    private var sessionManager: SessionManager?
    private var commitProcessor: FileCommitProcessor?
    
    private var checkBatchHandler: CheckBatchHandler?
    private var uploadHandler: UploadHandler?
    private var uploadStatusHandler: UploadStatusHandler?
    
    private override init() {
        // Resolve default path (~/Photos)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let defaultPath = home.appendingPathComponent("Photos")
        
        // Load custom path from UserDefaults if saved
        if let savedPath = UserDefaults.standard.string(forKey: "iCherriBackupFolderPath") {
            self.backupFolder = URL(fileURLWithPath: savedPath)
        } else {
            self.backupFolder = defaultPath
        }
        
        super.init()
        
        // Listen to UI-driven notification center events
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenDashboardNotification), name: .openDashboard, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChangeBackupFolderNotification), name: .changeBackupFolder, object: nil)
    }
    
    func start() async {
        do {
            let backupDir = self.backupFolder
            let tmpDir = backupDir.appendingPathComponent(".tmp")
            let incomingDir = tmpDir.appendingPathComponent("incoming")
            
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: incomingDir, withIntermediateDirectories: true)
            
            let dbPath = backupDir.appendingPathComponent(".i-cherri.sqlite3").path
            try await DatabaseManager.shared.open(at: dbPath)
            
            let manager = SessionManager(dbManager: DatabaseManager.shared)
            self.sessionManager = manager
            
            let processor = FileCommitProcessor(backupRootURL: backupDir, dbManager: DatabaseManager.shared)
            self.commitProcessor = processor
            
            // Handlers
            let queryProcessor = CheckBatchProcessor(index: DatabaseManager.shared)
            self.checkBatchHandler = CheckBatchHandler(processor: queryProcessor)
            self.uploadHandler = UploadHandler(sessionManager: manager, incomingDir: incomingDir)
            self.uploadStatusHandler = UploadStatusHandler(sessionManager: manager)
            
            // HTTP Server
            let srv = ReceiverHTTPServer(port: port)
            await srv.setRouteHandler(self)
            try await srv.start()
            self.server = srv
            self.isServerRunning = true
            print("[AppCoordinator] HTTP Server running on port \(port)")
            
            // Bonjour Advertiser
            let hostName = Host.current().localizedName ?? "iCherri Receiver"
            let adv = BonjourAdvertiser(port: port, receiverName: hostName)
            try await adv.start()
            self.advertiser = adv
            print("[AppCoordinator] Bonjour Advertiser started on port \(port)")
            
            // Cleanup Scheduler
            let scheduler = CleanupScheduler(sessionManager: manager, incomingDir: incomingDir)
            await scheduler.start()
            self.cleanupScheduler = scheduler
            
        } catch {
            print("[AppCoordinator] Initialization failed: \(error)")
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
            self.backupFolder = url
            UserDefaults.standard.set(url.path, forKey: "iCherriBackupFolderPath")
            print("[AppCoordinator] Backup folder changed to: \(url.path)")
            
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

extension AppCoordinator: ReceiverRouteHandler {
    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        let path = request.path
        let method = request.method
        
        print("[AppCoordinator] HTTP Request: \(method) \(path)")
        
        if method == "POST" && path == "/backup/check-batch" {
            if let handler = checkBatchHandler {
                return await handler.handle(request)
            }
        }
        
        if method == "POST" && path == "/uploads/init" {
            if let handler = uploadHandler {
                return await handler.handleInit(request)
            }
        }
        
        // GET /uploads/{id}/status
        if method == "GET" && path.hasPrefix("/uploads/") && path.hasSuffix("/status") {
            let components = path.split(separator: "/")
            if components.count == 3 {
                let uploadID = String(components[1])
                if let handler = uploadStatusHandler {
                    return await handler.handle(request, uploadID: uploadID)
                }
            }
        }
        
        // PUT /uploads/{id}/chunks/{index}
        if method == "PUT" && path.hasPrefix("/uploads/") && path.contains("/chunks/") {
            let components = path.split(separator: "/")
            if components.count == 4 {
                let uploadID = String(components[1])
                if let chunkIndex = Int(components[3]), let handler = uploadHandler {
                    return await handler.handleChunk(request, uploadID: uploadID, chunkIndex: chunkIndex)
                }
            }
        }
        
        // POST /uploads/{id}/commit
        if method == "POST" && path.hasPrefix("/uploads/") && path.hasSuffix("/commit") {
            let components = path.split(separator: "/")
            if components.count == 3 {
                let uploadID = String(components[1])
                return await handleCommitRequest(request, uploadID: uploadID)
            }
        }
        
        return .notFound
    }
    
    private func handleCommitRequest(_ request: HTTPRequest, uploadID: String) async -> HTTPResponse {
        guard let sessionManager = self.sessionManager, let commitProcessor = self.commitProcessor else {
            return .error(code: "internal_error", message: "Server not initialized", status: 500)
        }
        
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
                
                let response = CommitUploadResponse.success(backupID: backupID, displayPath: displayPath)
                return (try? HTTPResponse.json(response)) ?? .error(code: "encode_error", message: "Encode failed", status: 500)
            case .checksumMismatch:
                return .error(code: "checksum_mismatch", message: "SHA256 checksum mismatch", status: 400)
            case .sizeMismatch:
                return .error(code: "size_mismatch", message: "File size mismatch", status: 400)
            }
        } catch {
            return .error(code: "commit_error", message: error.localizedDescription, status: 500)
        }
    }
}
