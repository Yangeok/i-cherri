import SwiftUI
import Network
import ICherriProtocol
import ICherriDesignSystem
import Inject

// Onboarding + pairing + backup trigger dashboard for iOS.
public struct BackupDashboardView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = BackupDashboardViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                ScrollView {
                    VStack(spacing: 28) {
                        permissionSection
                        pairingSection
                        if viewModel.isPaired {
                            backupTriggerSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("iCherri")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await viewModel.onAppear() }
        .sheet(
            isPresented: Binding(
                get: { viewModel.activeBackupProgressViewModel != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissBackupProgress()
                    }
                }
            )
        ) {
            if let progressViewModel = viewModel.activeBackupProgressViewModel {
                NavigationStack {
                    BackupProgressView(viewModel: progressViewModel)
                }
            }
        }
        .enableInjection()
    }

    // MARK: - Sections

    private var permissionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Photo Library", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                permissionRow(
                    title: "Photos Access",
                    status: viewModel.photoPermissionStatus,
                    action: { await viewModel.requestPhotoPermission() }
                )
                permissionRow(
                    title: "Local Network",
                    status: viewModel.localNetworkStatus,
                    action: nil
                )
            }
        } label: {
            Label("Permissions", systemImage: "lock.shield")
        }
        .groupBoxStyle(.automatic)
    }

    private var pairingSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                if let receiverName = viewModel.pairedReceiverName {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Backup Target")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(receiverName)
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                        Button("Forget") { viewModel.clearPairedReceiver() }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isPairing || viewModel.isBackingUp)
                    }
                }
                if viewModel.discoveredReceivers.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Looking for Mac receivers…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(viewModel.discoveredReceivers) { receiver in
                        receiverRow(receiver)
                    }
                }
                if let message = viewModel.pairingStatusMessage {
                    Label(message, systemImage: viewModel.isPaired ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(viewModel.isPaired ? .green : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let errorMessage = viewModel.pairingErrorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } label: {
            Label("Available Receivers", systemImage: "macbook.and.iphone")
        }
    }

    private var backupTriggerSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                if let receiverName = viewModel.pairedReceiverName {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected to \(receiverName)")
                            .font(.subheadline)
                        Spacer()
                    }
                }
                Button(action: { Task { await viewModel.startBackup() } }) {
                    Label("Start Backup", systemImage: "arrow.up.to.line.compact")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBackingUp)
                if let backupStatusMessage = viewModel.backupStatusMessage {
                    Label(backupStatusMessage, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } label: {
            Label("Backup", systemImage: "externaldrive.fill.badge.icloud")
        }
    }

    // MARK: - Helpers

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color.accentColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func permissionRow(title: String, status: PermissionStatus, action: (() async -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .denied:
                Button("Open Settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                    .font(.caption)
                    .buttonStyle(.bordered)
            case .unknown:
                if let action {
                    Button("Allow") { Task { await action() } }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                } else {
                    ProgressView()
                }
            }
        }
    }

    private func receiverRow(_ receiver: DiscoveredReceiver) -> some View {
        HStack {
            Image(systemName: "desktopcomputer")
            VStack(alignment: .leading, spacing: 2) {
                Text(receiver.name)
                    .font(.subheadline)
                if viewModel.isPaired && viewModel.pairedReceiverName == receiver.name {
                    Text("Current backup target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if viewModel.isPaired && viewModel.pairedReceiver?.id == receiver.id {
                Label("Current", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button(viewModel.isPaired ? "Switch Target" : "Connect") { Task { await viewModel.pair(with: receiver) } }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isPairing || viewModel.isBackingUp)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

enum PermissionStatus { case granted, denied, unknown }

@MainActor
final class BackupDashboardViewModel: ObservableObject {
    private static let maxConcurrentUploads = 3

    @Published var photoPermissionStatus: PermissionStatus = .unknown
    @Published var localNetworkStatus: PermissionStatus = .unknown
    @Published var discoveredReceivers: [DiscoveredReceiver] = []
    @Published var pairedReceiver: DiscoveredReceiver?
    @Published var pairedReceiverName: String?
    @Published var isPaired = false
    @Published var isPairing = false
    @Published var isBackingUp = false
    @Published var pairingStatusMessage: String?
    @Published var pairingErrorMessage: String?
    @Published var backupStatusMessage: String?
    @Published var activeBackupProgressViewModel: BackupProgressViewModel?

    private let scanner = PhotoLibraryScanner()
    private let bonjourBrowser = BonjourBrowser()
    private let trustTokenKey = "iCherriTrustToken"
    private let receiverURLKey = "iCherriReceiverURL"
    private let receiverNameKey = "iCherriReceiverName"

    func onAppear() async {
        updatePhotoPermission()
        restorePairingState()
        bonjourBrowser.startBrowsing()
        // Observe browser changes
        Task { @MainActor in
            for await receivers in bonjourBrowser.$discoveredReceivers.values {
                self.discoveredReceivers = receivers
                self.localNetworkStatus = receivers.isEmpty ? self.localNetworkStatus : .granted
                if let pairedReceiverName {
                    self.pairedReceiver = receivers.first(where: { $0.name == pairedReceiverName })
                }
            }
        }
        Task { @MainActor in
            for await status in bonjourBrowser.$status.values {
                switch status {
                case .ready:
                    self.localNetworkStatus = .granted
                case .failed:
                    self.localNetworkStatus = .denied
                case .idle, .browsing:
                    if self.localNetworkStatus != .granted {
                        self.localNetworkStatus = .unknown
                    }
                }
            }
        }
    }

    func requestPhotoPermission() async {
        let status = await scanner.requestAuthorization()
        photoPermissionStatus = permissionStatus(for: status)
    }

    func pair(with receiver: DiscoveredReceiver) async {
        let previousReceiver = pairedReceiver
        let previousReceiverName = pairedReceiverName
        let previousIsPaired = isPaired
        let previousStatusMessage = pairingStatusMessage

        isPairing = true
        pairingErrorMessage = nil
        pairingStatusMessage = "Connecting to \(receiver.name)..."
        defer { isPairing = false }

        // Resolve endpoint and send pair request to Mac server
        do {
            let baseURL = try await resolveEndpoint(receiver.endpoint)
            let device = currentDeviceInfo()
            let pairRequest = PairingStartRequest(device: device)
            
            let url = baseURL.appendingPathComponent("/pair")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 10
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(device.deviceID, forHTTPHeaderField: "X-iCherri-Device-ID")
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(pairRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode < 300 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let confirmResponse = try decoder.decode(PairingConfirmResponse.self, from: data)
                
                // Store trust token for future requests
                UserDefaults.standard.set(confirmResponse.trustToken, forKey: trustTokenKey)
                UserDefaults.standard.set(baseURL.absoluteString, forKey: receiverURLKey)
                UserDefaults.standard.set(receiver.name, forKey: receiverNameKey)

                pairedReceiver = receiver
                pairedReceiverName = receiver.name
                isPaired = true
                pairingStatusMessage = "Connected to \(receiver.name)."
                print("[Pair] Successfully paired with \(receiver.name), token: \(confirmResponse.trustToken.prefix(8))...")
            } else {
                print("[Pair] Server returned error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                pairedReceiver = previousReceiver
                pairedReceiverName = previousReceiverName
                isPaired = previousIsPaired
                pairingStatusMessage = previousStatusMessage
                pairingErrorMessage = "Pairing failed. Receiver returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)."
            }
        } catch {
            print("[Pair] Failed to pair: \(error)")
            pairedReceiver = previousReceiver
            pairedReceiverName = previousReceiverName
            isPaired = previousIsPaired
            pairingStatusMessage = previousStatusMessage
            pairingErrorMessage = "Pairing failed: \(error.localizedDescription)"
        }
    }

    func clearPairedReceiver() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: trustTokenKey)
        defaults.removeObject(forKey: receiverURLKey)
        defaults.removeObject(forKey: receiverNameKey)

        pairedReceiver = nil
        pairedReceiverName = nil
        isPaired = false
        pairingStatusMessage = "Choose a Mac receiver to use as the backup target."
        backupStatusMessage = nil
    }

    func startBackup() async {
        guard photoPermissionStatus == .granted else {
            backupStatusMessage = "Allow Photos access before starting backup."
            return
        }
        guard
            let trustToken = UserDefaults.standard.string(forKey: trustTokenKey),
            !trustToken.isEmpty
        else {
            backupStatusMessage = "Connect to a Mac receiver first."
            return
        }

        isBackingUp = true
        backupStatusMessage = "Scanning photo library..."
        let device = currentDeviceInfo()
        let scannedAssets = await scanner.scanAllAssets(deviceID: device.deviceID)
        let progressViewModel = BackupProgressViewModel(totalCount: scannedAssets.count)
        activeBackupProgressViewModel = progressViewModel

        let backupTask = Task { [weak self] in
            guard let self else { return }
            defer { Task { @MainActor in self.isBackingUp = false } }

            do {
                try Task.checkCancellation()

                if scannedAssets.isEmpty {
                    await MainActor.run {
                        progressViewModel.update(
                            filename: "No media found",
                            completed: 0,
                            success: 0,
                            duplicates: 0,
                            failed: 0,
                            bytesPerSecond: 0
                        )
                        self.backupStatusMessage = "No photos or videos found to back up."
                    }
                    return
                }

                let progressCoordinator = BackupUploadProgressCoordinator(viewModel: progressViewModel)

                progressCoordinator.updateSnapshot(
                    filename: "Checking existing backups...",
                    completed: 0,
                    success: 0,
                    duplicates: 0,
                    failed: 0,
                    bytesPerSecond: 0
                )

                let receiverURL = try await self.resolveReceiverURLForBackup()
                let backupClient = BackupClient(receiverBaseURL: receiverURL, device: device, trustToken: trustToken)
                let batchResponse = try await backupClient.checkBatch(candidates: scannedAssets)
                let assetIndex = Dictionary(uniqueKeysWithValues: scannedAssets.map { ($0.assetLocalID, $0) })

                var completed = batchResponse.alreadyBackedUp.count + batchResponse.duplicates.count + batchResponse.unsupported.count
                var success = 0
                let duplicates = batchResponse.alreadyBackedUp.count + batchResponse.duplicates.count
                var failed = batchResponse.unsupported.count
                var pendingAssets: [AssetMetadata] = []

                for requirement in batchResponse.requiredUploads {
                    guard let metadata = assetIndex[requirement.assetLocalID] else {
                        failed += 1
                        completed += 1
                        continue
                    }
                    pendingAssets.append(metadata)
                }

                progressCoordinator.updateSnapshot(
                    filename: "Preparing uploads...",
                    completed: completed,
                    success: success,
                    duplicates: duplicates,
                    failed: failed,
                    bytesPerSecond: 0
                )

                try await withThrowingTaskGroup(of: UploadTaskOutcome.self) { group in
                    var nextIndex = 0

                    func enqueueNextUpload() {
                        guard nextIndex < pendingAssets.count else { return }
                        let metadata = pendingAssets[nextIndex]
                        nextIndex += 1

                        group.addTask {
                            let taskBackupClient = BackupClient(
                                receiverBaseURL: receiverURL,
                                device: device,
                                trustToken: trustToken
                            )
                            let taskChunkSender = ChunkUploadSender(
                                receiverBaseURL: receiverURL,
                                device: device,
                                trustToken: trustToken
                            )
                            let taskProgress = await AssetUploadProgressReporter(
                                assetLocalID: metadata.assetLocalID,
                                filename: metadata.originalFilename,
                                coordinator: progressCoordinator
                            )
                            await taskChunkSender.setProgressDelegate(taskProgress)
                            let taskScanner = PhotoLibraryScanner()

                            let uploadManager = ResumableUploadManager(
                                backupClient: taskBackupClient,
                                chunkSender: taskChunkSender,
                                scanner: taskScanner
                            )

                            await progressCoordinator.beginAsset(assetLocalID: metadata.assetLocalID, filename: metadata.originalFilename)

                            do {
                                _ = try await uploadManager.upload(
                                    assetLocalID: metadata.assetLocalID,
                                    metadata: metadata
                                )
                                return .success(assetLocalID: metadata.assetLocalID, filename: metadata.originalFilename)
                            } catch {
                                print("[Backup] Failed to upload \(metadata.originalFilename): \(error)")
                                return .failure(assetLocalID: metadata.assetLocalID, filename: metadata.originalFilename)
                            }
                        }
                    }

                    let initialConcurrency = min(Self.maxConcurrentUploads, pendingAssets.count)
                    for _ in 0..<initialConcurrency {
                        enqueueNextUpload()
                    }

                    while let outcome = try await group.next() {
                        try Task.checkCancellation()

                        switch outcome {
                        case .success(let assetLocalID, let filename):
                            success += 1
                            completed += 1
                            progressCoordinator.finishAsset(
                                assetLocalID: assetLocalID,
                                filename: filename,
                                completed: completed,
                                success: success,
                                duplicates: duplicates,
                                failed: failed
                            )
                        case .failure(let assetLocalID, let filename):
                            failed += 1
                            completed += 1
                            progressCoordinator.finishAsset(
                                assetLocalID: assetLocalID,
                                filename: filename,
                                completed: completed,
                                success: success,
                                duplicates: duplicates,
                                failed: failed
                            )
                        }

                        enqueueNextUpload()
                    }
                }

                await MainActor.run {
                    self.backupStatusMessage = "Backup complete. Uploaded \(success), skipped \(duplicates), failed \(failed)."
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.backupStatusMessage = "Backup canceled."
                    self.activeBackupProgressViewModel = nil
                }
            } catch {
                print("[Backup] Backup run failed: \(error)")
                await MainActor.run {
                    self.backupStatusMessage = "Backup failed: \(self.describeBackupError(error))"
                    self.activeBackupProgressViewModel = nil
                }
            }
        }

        progressViewModel.bindCancellation(to: backupTask)
        await backupTask.value
    }

    func dismissBackupProgress() {
        activeBackupProgressViewModel = nil
    }

    private func updatePhotoPermission() {
        let status = scanner.currentAuthorizationStatus()
        photoPermissionStatus = permissionStatus(for: status)
    }

    private func permissionStatus(for status: PhotoLibraryAuthStatus) -> PermissionStatus {
        switch status {
        case .authorized, .limited:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        }
    }

    private func restorePairingState() {
        let defaults = UserDefaults.standard
        guard
            let trustToken = defaults.string(forKey: trustTokenKey),
            !trustToken.isEmpty
        else {
            pairedReceiver = nil
            pairedReceiverName = nil
            isPaired = false
            return
        }

        pairedReceiverName = defaults.string(forKey: receiverNameKey)
        isPaired = pairedReceiverName != nil
        pairingStatusMessage = pairedReceiverName.map { "Connected to \($0)." }
    }

    private func describeBackupError(_ error: Error) -> String {
        if let backupError = error as? BackupClientError {
            switch backupError {
            case .httpError(let statusCode, let data):
                let body = String(data: data, encoding: .utf8) ?? "No response body"
                return "HTTP \(statusCode): \(body)"
            case .invalidResponse:
                return "Invalid server response."
            }
        }
        return error.localizedDescription
    }
    
    private func currentDeviceInfo() -> DeviceInfo {
        DeviceInfo(
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            deviceName: UIDevice.current.name,
            platform: "iOS",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }

    private func resolveReceiverURLForBackup() async throws -> URL {
        if let pairedReceiver {
            let resolvedURL = try await resolveEndpoint(pairedReceiver.endpoint)
            UserDefaults.standard.set(resolvedURL.absoluteString, forKey: receiverURLKey)
            return resolvedURL
        }

        if let pairedReceiverName,
           let discoveredReceiver = discoveredReceivers.first(where: { $0.name == pairedReceiverName }) {
            pairedReceiver = discoveredReceiver
            let resolvedURL = try await resolveEndpoint(discoveredReceiver.endpoint)
            UserDefaults.standard.set(resolvedURL.absoluteString, forKey: receiverURLKey)
            return resolvedURL
        }

        if let receiverURLString = UserDefaults.standard.string(forKey: receiverURLKey),
           let receiverURL = URL(string: receiverURLString),
           !isLinkLocalReceiverURL(receiverURL) {
            return receiverURL
        }

        throw URLError(.cannotFindHost)
    }

    private func isLinkLocalReceiverURL(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return host.hasPrefix("fe80:")
    }
    
    private func resolveEndpoint(_ endpoint: NWEndpoint) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(to: endpoint, using: .tcp)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = innerEndpoint {
                        let hostStr: String
                        switch host {
                        case .ipv4(let addr):
                            hostStr = "\(addr)"
                        case .ipv6(let addr):
                            hostStr = "[\(addr)]"
                        default:
                            hostStr = "\(host)"
                        }
                        connection.cancel()
                        if let url = URL(string: "http://\(hostStr):\(port)") {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(throwing: URLError(.badURL))
                        }
                    } else {
                        connection.cancel()
                        continuation.resume(throwing: URLError(.cannotFindHost))
                    }
                case .failed(let error):
                    connection.cancel()
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }
}

@MainActor
private final class BackupUploadProgressCoordinator {
    private struct ActiveUploadState {
        var filename: String
        var sentBytes: Int64 = 0
        var totalBytes: Int64 = 0
        var bytesPerSecond: Double = 0
    }

    private let viewModel: BackupProgressViewModel
    private var currentFilename: String = "Preparing uploads..."
    private var archivedSentBytes: Int64 = 0
    private var archivedTotalBytes: Int64 = 0
    private var completed: Int = 0
    private var success: Int = 0
    private var duplicates: Int = 0
    private var failed: Int = 0
    private var activeUploads: [String: ActiveUploadState] = [:]

    init(viewModel: BackupProgressViewModel) {
        self.viewModel = viewModel
    }

    func beginAsset(assetLocalID: String, filename: String) {
        currentFilename = filename
        activeUploads[assetLocalID] = ActiveUploadState(filename: filename)
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond)
    }

    func updateSnapshot(
        filename: String,
        completed: Int,
        success: Int,
        duplicates: Int,
        failed: Int,
        bytesPerSecond: Double
    ) {
        currentFilename = filename
        self.completed = completed
        self.success = success
        self.duplicates = duplicates
        self.failed = failed
        pushUpdate(bytesPerSecond: bytesPerSecond)
    }

    func didSendBytes(assetLocalID: String, filename: String, totalSent: Int64, totalExpected: Int64, bytesPerSecond: Double) {
        currentFilename = filename
        activeUploads[assetLocalID] = ActiveUploadState(
            filename: filename,
            sentBytes: totalSent,
            totalBytes: totalExpected,
            bytesPerSecond: bytesPerSecond
        )
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond)
    }

    func finishAsset(
        assetLocalID: String,
        filename: String,
        completed: Int,
        success: Int,
        duplicates: Int,
        failed: Int
    ) {
        currentFilename = filename
        if let state = activeUploads.removeValue(forKey: assetLocalID) {
            archivedSentBytes += max(state.sentBytes, state.totalBytes)
            archivedTotalBytes += max(state.totalBytes, state.sentBytes)
        }
        self.completed = completed
        self.success = success
        self.duplicates = duplicates
        self.failed = failed
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond)
    }

    private var aggregateBytesPerSecond: Double {
        activeUploads.values.reduce(0) { $0 + $1.bytesPerSecond }
    }

    private func pushUpdate(bytesPerSecond: Double) {
        let activeBytesSent = activeUploads.values.reduce(Int64(0)) { $0 + $1.sentBytes }
        let activeBytesTotal = activeUploads.values.reduce(Int64(0)) { $0 + $1.totalBytes }
        let activeUploadItems = activeUploads
            .map { assetLocalID, state in
                ActiveUploadProgressItem(
                    id: assetLocalID,
                    assetLocalID: assetLocalID,
                    filename: state.filename,
                    sentBytes: state.sentBytes,
                    totalBytes: state.totalBytes,
                    bytesPerSecond: state.bytesPerSecond
                )
            }
            .sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }

        let displayFilename: String
        if activeUploads.count > 1 {
            displayFilename = "\(currentFilename) + \(activeUploads.count - 1) more"
        } else {
            displayFilename = currentFilename
        }

        viewModel.update(
            filename: displayFilename,
            completed: completed,
            success: success,
            duplicates: duplicates,
            failed: failed,
            bytesPerSecond: bytesPerSecond,
            sentBytes: archivedSentBytes + activeBytesSent,
            totalBytes: archivedTotalBytes + activeBytesTotal,
            activeUploads: activeUploads.count,
            activeUploadItems: activeUploadItems
        )
    }
}

private enum UploadTaskOutcome: Sendable {
    case success(assetLocalID: String, filename: String)
    case failure(assetLocalID: String, filename: String)
}

@MainActor
private final class AssetUploadProgressReporter: ChunkUploadProgressDelegate {
    private let assetLocalID: String
    private let filename: String
    private let coordinator: BackupUploadProgressCoordinator
    private var startedAt = Date()

    init(assetLocalID: String, filename: String, coordinator: BackupUploadProgressCoordinator) {
        self.assetLocalID = assetLocalID
        self.filename = filename
        self.coordinator = coordinator
    }

    func didSendBytes(_ bytes: Int64, totalSent: Int64, totalExpected: Int64) async {
        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        let bytesPerSecond = Double(totalSent) / elapsed
        coordinator.didSendBytes(
            assetLocalID: assetLocalID,
            filename: filename,
            totalSent: totalSent,
            totalExpected: totalExpected,
            bytesPerSecond: bytesPerSecond
        )
    }
}
