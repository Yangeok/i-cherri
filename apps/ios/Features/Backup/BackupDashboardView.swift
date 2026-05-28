import SwiftUI
import Network
import ICherriProtocol
import ICherriDesignSystem

// Onboarding + pairing + backup trigger dashboard for iOS.
public struct BackupDashboardView: View {
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
            Text(receiver.name)
                .font(.subheadline)
            Spacer()
            if viewModel.isPaired && viewModel.pairedReceiver?.id == receiver.id {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Connect") { Task { await viewModel.pair(with: receiver) } }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isPairing)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

enum PermissionStatus { case granted, denied, unknown }

@MainActor
final class BackupDashboardViewModel: ObservableObject {
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
                if let pairedReceiverName {
                    self.pairedReceiver = receivers.first(where: { $0.name == pairedReceiverName })
                }
            }
        }
    }

    func requestPhotoPermission() async {
        let status = await scanner.requestAuthorization()
        photoPermissionStatus = status == .authorized || status == .limited ? .granted : .denied
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

    func startBackup() async {
        guard photoPermissionStatus == .granted else {
            backupStatusMessage = "Allow Photos access before starting backup."
            return
        }
        guard
            let receiverURLString = UserDefaults.standard.string(forKey: receiverURLKey),
            let receiverURL = URL(string: receiverURLString)
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

                let backupClient = BackupClient(receiverBaseURL: receiverURL, device: device)
                let chunkSender = ChunkUploadSender(receiverBaseURL: receiverURL, device: device)
                let progressCoordinator = BackupUploadProgressCoordinator(viewModel: progressViewModel)
                await chunkSender.setProgressDelegate(progressCoordinator)
                let uploadManager = ResumableUploadManager(
                    backupClient: backupClient,
                    chunkSender: chunkSender,
                    scanner: scanner
                )

                let batchResponse = try await backupClient.checkBatch(candidates: scannedAssets)
                let assetIndex = Dictionary(uniqueKeysWithValues: scannedAssets.map { ($0.assetLocalID, $0) })

                var completed = batchResponse.alreadyBackedUp.count + batchResponse.duplicates.count + batchResponse.unsupported.count
                var success = 0
                var duplicates = batchResponse.alreadyBackedUp.count + batchResponse.duplicates.count
                var failed = batchResponse.unsupported.count

                await progressCoordinator.updateSnapshot(
                    filename: "Preparing uploads...",
                    completed: completed,
                    success: success,
                    duplicates: duplicates,
                    failed: failed,
                    bytesPerSecond: 0
                )

                for requirement in batchResponse.requiredUploads {
                    try Task.checkCancellation()

                    guard let metadata = assetIndex[requirement.assetLocalID] else {
                        failed += 1
                        completed += 1
                        await progressCoordinator.updateSnapshot(
                            filename: "Missing asset metadata",
                            completed: completed,
                            success: success,
                            duplicates: duplicates,
                            failed: failed,
                            bytesPerSecond: 0
                        )
                        continue
                    }

                    await progressCoordinator.beginAsset(
                        filename: metadata.originalFilename,
                        completed: completed,
                        success: success,
                        duplicates: duplicates,
                        failed: failed
                    )

                    do {
                        _ = try await uploadManager.upload(
                            assetLocalID: metadata.assetLocalID,
                            metadata: metadata
                        )
                        success += 1
                    } catch {
                        failed += 1
                        print("[Backup] Failed to upload \(metadata.originalFilename): \(error)")
                    }

                    completed += 1
                    await progressCoordinator.updateSnapshot(
                        filename: metadata.originalFilename,
                        completed: completed,
                        success: success,
                        duplicates: duplicates,
                        failed: failed,
                        bytesPerSecond: 0
                    )
                }

                await MainActor.run {
                    self.backupStatusMessage = "Backup complete. Uploaded \(success), skipped \(duplicates), failed \(failed)."
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.backupStatusMessage = "Backup canceled."
                }
            } catch {
                print("[Backup] Backup run failed: \(error)")
                await MainActor.run {
                    self.backupStatusMessage = "Backup failed: \(self.describeBackupError(error))"
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
        photoPermissionStatus = status == .authorized || status == .limited ? .granted : .denied
    }

    private func restorePairingState() {
        let defaults = UserDefaults.standard
        guard
            let trustToken = defaults.string(forKey: trustTokenKey),
            !trustToken.isEmpty,
            let receiverURL = defaults.string(forKey: receiverURLKey),
            !receiverURL.isEmpty
        else {
            pairedReceiver = nil
            pairedReceiverName = nil
            isPaired = false
            return
        }

        pairedReceiverName = defaults.string(forKey: receiverNameKey)
        isPaired = true
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
private final class BackupUploadProgressCoordinator: ChunkUploadProgressDelegate {
    private let viewModel: BackupProgressViewModel
    private var currentFilename: String = "Preparing uploads..."
    private var completed: Int = 0
    private var success: Int = 0
    private var duplicates: Int = 0
    private var failed: Int = 0
    private var assetStartDate = Date()

    init(viewModel: BackupProgressViewModel) {
        self.viewModel = viewModel
    }

    func beginAsset(filename: String, completed: Int, success: Int, duplicates: Int, failed: Int) {
        assetStartDate = Date()
        updateSnapshot(
            filename: filename,
            completed: completed,
            success: success,
            duplicates: duplicates,
            failed: failed,
            bytesPerSecond: 0
        )
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
        viewModel.update(
            filename: filename,
            completed: completed,
            success: success,
            duplicates: duplicates,
            failed: failed,
            bytesPerSecond: bytesPerSecond
        )
    }

    func didSendBytes(_ bytes: Int64, totalSent: Int64, totalExpected: Int64) async {
        let elapsed = max(Date().timeIntervalSince(assetStartDate), 0.001)
        let bytesPerSecond = Double(totalSent) / elapsed
        viewModel.update(
            filename: currentFilename,
            completed: completed,
            success: success,
            duplicates: duplicates,
            failed: failed,
            bytesPerSecond: bytesPerSecond
        )
    }
}
