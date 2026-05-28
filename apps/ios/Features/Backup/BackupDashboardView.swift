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
    @Published var isBackingUp = false

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

        // Resolve endpoint and send pair request to Mac server
        do {
            let baseURL = try await resolveEndpoint(receiver.endpoint)
            let device = currentDeviceInfo()
            let pairRequest = PairingStartRequest(device: device)
            
            let url = baseURL.appendingPathComponent("/pair")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
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
                print("[Pair] Successfully paired with \(receiver.name), token: \(confirmResponse.trustToken.prefix(8))...")
            } else {
                print("[Pair] Server returned error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                pairedReceiver = previousReceiver
                pairedReceiverName = previousReceiverName
                isPaired = previousIsPaired
            }
        } catch {
            print("[Pair] Failed to pair: \(error)")
            pairedReceiver = previousReceiver
            pairedReceiverName = previousReceiverName
            isPaired = previousIsPaired
        }
    }

    func startBackup() async {
        isBackingUp = true
        defer { isBackingUp = false }
        // Backup orchestration delegated to BackupClient
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
