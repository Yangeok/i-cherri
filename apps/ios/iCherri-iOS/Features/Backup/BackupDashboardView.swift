import SwiftUI
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
                if let receiver = viewModel.pairedReceiver {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected to \(receiver.name)")
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
            if viewModel.pairedReceiver?.id == receiver.id {
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
    @Published var isPaired = false
    @Published var isBackingUp = false

    private let scanner = PhotoLibraryScanner()
    private let bonjourBrowser = BonjourBrowser()

    func onAppear() async {
        updatePhotoPermission()
        bonjourBrowser.startBrowsing()
        // Observe browser changes
        Task { @MainActor in
            for await receivers in bonjourBrowser.$discoveredReceivers.values {
                self.discoveredReceivers = receivers
            }
        }
    }

    func requestPhotoPermission() async {
        let status = await scanner.requestAuthorization()
        photoPermissionStatus = status == .authorized || status == .limited ? .granted : .denied
    }

    func pair(with receiver: DiscoveredReceiver) async {
        pairedReceiver = receiver
        isPaired = true
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
}
