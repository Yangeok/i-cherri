import Foundation
import SwiftUI
import AppKit
import Network
import ICherriProtocol
import ICherriCore

actor BackupRunProgressStore {
    struct Snapshot: Sendable {
        let totalBytes: Int64
        let completedBytes: Int64

        var fractionCompleted: Double {
            guard totalBytes > 0 else { return 0 }
            return min(max(Double(completedBytes) / Double(totalBytes), 0), 1)
        }
    }

    private struct DeviceRunProgress: Sendable {
        var totalBytes: Int64
        var uploadedAssetIDs: Set<String>
        var candidateBytesByAssetID: [String: Int64]
    }

    private var runsByDeviceID: [String: DeviceRunProgress] = [:]

    func recordCheckBatch(request: CheckBatchRequest, response: CheckBatchResponse) {
        let unsupportedIDs = Set(response.unsupported)
        let supportedCandidates = request.candidates.filter { !unsupportedIDs.contains($0.assetLocalID) }
        let candidateBytesByAssetID = Dictionary(uniqueKeysWithValues: supportedCandidates.map { ($0.assetLocalID, max($0.byteSize, 0)) })
        let totalBytes = max(
            request.librarySnapshot?.totalAssetBytes ?? 0,
            supportedCandidates.reduce(Int64(0)) { partial, asset in
                partial + max(asset.byteSize, 0)
            }
        )

        runsByDeviceID[request.device.deviceID] = DeviceRunProgress(
            totalBytes: totalBytes,
            uploadedAssetIDs: [],
            candidateBytesByAssetID: candidateBytesByAssetID
        )
    }

    func markUploaded(deviceID: String, assetLocalID: String) {
        guard var run = runsByDeviceID[deviceID] else { return }
        guard run.candidateBytesByAssetID[assetLocalID] != nil else { return }
        run.uploadedAssetIDs.insert(assetLocalID)
        runsByDeviceID[deviceID] = run
    }

    func snapshot(activeSessions: [UploadSessionRecord], coveredBytesByDeviceID: [String: Int64] = [:]) -> Snapshot? {
        let activeDeviceIDs = Set(activeSessions.map(\.deviceId))
        guard !activeDeviceIDs.isEmpty else { return nil }

        var totalBytes: Int64 = 0
        var completedBytes: Int64 = 0

        for deviceID in activeDeviceIDs {
            guard let run = runsByDeviceID[deviceID] else { continue }

            totalBytes += run.totalBytes
            completedBytes += max(coveredBytesByDeviceID[deviceID] ?? 0, 0)
            completedBytes += run.uploadedAssetIDs.reduce(Int64(0)) { partial, assetID in
                partial + (run.candidateBytesByAssetID[assetID] ?? 0)
            }
        }

        let activeSessionBytes = activeSessions.reduce(Int64(0)) { partial, session in
            partial + max(session.receivedBytes, 0)
        }
        completedBytes += activeSessionBytes

        guard totalBytes > 0 else { return nil }
        return Snapshot(totalBytes: totalBytes, completedBytes: min(completedBytes, totalBytes))
    }
}

@MainActor
final class AppCoordinator: NSObject, ObservableObject {
    static let shared = AppCoordinator()
    
    @Published var backupFolder: URL
    @Published var isServerRunning = false
    @Published var serverIssue: String?
    @Published var port: UInt16 = 8787 // Using 8787 as in the original Go project
    
    private var server: ReceiverHTTPServer?
    private var advertiser: BonjourAdvertiser?
    private var cleanupScheduler: CleanupScheduler?
    private var securityScopedURL: URL?
    
    private var sessionManager: SessionManager?
    private var commitProcessor: FileCommitProcessor?
    let backupRunProgressStore = BackupRunProgressStore()
    
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
        isServerRunning = false
        serverIssue = nil

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
            let backupIndex = DiskBackedBackupIndex(databaseManager: DatabaseManager.shared, backupRootURL: backupDir)
            let queryProcessor = CheckBatchProcessor(index: backupIndex)
            let checkBatchHandler = CheckBatchHandler(
                processor: queryProcessor,
                progressStore: backupRunProgressStore,
                databaseManager: DatabaseManager.shared
            )
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
            await srv.setStateHandler { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.isServerRunning = true
                        self.serverIssue = nil
                    case .waiting(let error):
                        self.isServerRunning = false
                        self.serverIssue = Self.listenerIssueDescription(prefix: "Listener waiting", error: error)
                    case .failed(let error):
                        self.isServerRunning = false
                        self.serverIssue = Self.listenerIssueDescription(prefix: "Listener failed", error: error)
                    case .cancelled:
                        self.isServerRunning = false
                        self.serverIssue = "Listener cancelled before becoming ready."
                    default:
                        break
                    }
                }
            }
            try await srv.start()
            self.server = srv
            print("[AppCoordinator] HTTP Server start requested on port \(port)")

            // Bonjour Advertiser
            let receiverName = Host.current().localizedName ?? "Mac Receiver"
            let adv = BonjourAdvertiser(port: port, receiverName: receiverName)
            try await adv.start()
            self.advertiser = adv
            print("[AppCoordinator] Bonjour Advertiser started as \(receiverName) on port \(port)")

            // Cleanup Scheduler
            let scheduler = CleanupScheduler(sessionManager: manager, incomingDir: tmpDir)
            await scheduler.start()
            self.cleanupScheduler = scheduler
            
        } catch {
            isServerRunning = false
            serverIssue = Self.startFailureDescription(error)
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

    private static func listenerIssueDescription(prefix: String, error: NWError) -> String {
        let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else {
            return "\(prefix)."
        }
        return "\(prefix): \(detail)"
    }

    private static func startFailureDescription(_ error: Error) -> String {
        let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else {
            return "Receiver initialization failed."
        }
        return "Receiver initialization failed: \(detail)"
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

        if method == "POST" && path == "/backup/finalize-run" {
            return await handleFinalizeBackupRunRequest(request)
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

        if method == "POST" && path == "/devices/ping" {
            return await handleDevicePingRequest(request)
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

    private func handleDevicePingRequest(_ request: HTTPRequest) async -> HTTPResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct DevicePingRequest: Codable {
            let deviceID: String
        }
        
        guard let body = try? decoder.decode(DevicePingRequest.self, from: request.body) else {
            return .error(code: "invalid_body", message: "Failed to parse DevicePingRequest")
        }
        
        do {
            if var device = try await DatabaseManager.shared.fetchDevice(id: body.deviceID) {
                device.lastSeenAt = Date()
                try await DatabaseManager.shared.upsertDevice(device)
                await MainActor.run {
                    NotificationCenter.default.post(name: .receiverDataDidChange, object: nil)
                }
                let response = ["status": "ok"]
                return (try? HTTPResponse.json(response)) ?? .error(code: "encode_error", message: "Encode failed", status: 500)
            }
            return .error(code: "device_not_found", message: "Device not paired", status: 404)
        } catch {
            return .error(code: "ping_error", message: error.localizedDescription, status: 500)
        }
    }

    private func handleFinalizeBackupRunRequest(_ request: HTTPRequest) async -> HTTPResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let body = try? decoder.decode(FinalizeBackupRunRequest.self, from: request.body) else {
            return .error(code: "invalid_body", message: "Failed to parse FinalizeBackupRunRequest")
        }

        do {
            let snapshot = try await DatabaseManager.shared.finalizeBackupRun(
                runID: body.backupRunID,
                deviceID: body.device.deviceID
            )
            let response = FinalizeBackupRunResponse(
                status: snapshot.status,
                totalAssetCount: snapshot.totalAssetCount,
                completedAssetCount: snapshot.completedAssetCount,
                missingAssetIDs: snapshot.missingAssetIDs
            )
            return (try? HTTPResponse.json(response)) ?? .error(code: "encode_error", message: "Encode failed", status: 500)
        } catch {
            return .error(code: "finalize_backup_run_error", message: error.localizedDescription, status: 500)
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
                await AppCoordinator.shared.backupRunProgressStore.markUploaded(
                    deviceID: session.deviceID,
                    assetLocalID: session.assetLocalID
                )
                Task.detached(priority: .utility) {
                    await AssetHistoryThumbnailPrefetcher.prewarmCommittedAsset(
                        relativePath: displayPath,
                        mediaType: metadata.mediaType.rawValue
                    )
                }
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
