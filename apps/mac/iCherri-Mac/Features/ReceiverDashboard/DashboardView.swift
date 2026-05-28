import SwiftUI
import ICherriDesignSystem
import ICherriProtocol

// macOS receiver dashboard showing paired devices, active sessions, and backup history.
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .navigationTitle("iCherri Receiver")
        .toolbar { toolbarContent }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .changeBackupFolder)) { _ in
            viewModel.selectBackupFolder()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $viewModel.selectedDevice) {
            Section("Paired Devices") {
                ForEach(viewModel.pairedDevices, id: \.deviceId) { device in
                    deviceRow(device)
                        .tag(device.deviceId)
                }
            }
            Section("Sessions") {
                ForEach(viewModel.activeSessions, id: \.uploadID) { session in
                    sessionRow(session)
                }
                if viewModel.activeSessions.isEmpty {
                    Text("No active sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }

    // MARK: - Detail

    private var detailContent: some View {
        Group {
            if let device = viewModel.selectedDeviceInfo {
                deviceDetailView(device)
            } else {
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Select a device to view backup history")
                .foregroundStyle(.secondary)
            if let folder = viewModel.backupFolderPath {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(folder)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func deviceDetailView(_ device: PairedDeviceRecord) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.deviceName)
                        .font(.title2.weight(.semibold))
                    Text("Last seen: \(device.lastSeenAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusPill(device.pairingStatus)
            }
            .padding(.bottom, 4)

            HStack(spacing: 16) {
                GlowBadge(label: "Backed Up", value: "\(viewModel.assetCount(for: device.deviceId))", color: .green)
                GlowBadge(label: "Duplicates", value: "\(viewModel.duplicateCount(for: device.deviceId))", color: .orange)
                GlowBadge(label: "Failed", value: "\(viewModel.failedCount(for: device.deviceId))", color: .red)
            }

            Table(viewModel.assets(for: device.deviceId)) {
                TableColumn("Filename", value: \.originalFilename)
                TableColumn("Type", value: \.mediaType)
                TableColumn("Size") { asset in
                    Text(ByteCountFormatter.string(fromByteCount: asset.byteSize, countStyle: .file))
                }
                TableColumn("Status", value: \.status)
                TableColumn("Date") { asset in
                    Text(asset.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Toolbar

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.selectBackupFolder) {
                    Label("Change Folder", systemImage: "folder.badge.gear")
                }
            }
            ToolbarItem {
                Button(action: { Task { await viewModel.load() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    // MARK: - Helpers

    private func deviceRow(_ device: PairedDeviceRecord) -> some View {
        HStack {
            Image(systemName: "iphone")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceName)
                    .font(.subheadline)
                Text(device.pairingStatus.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sessionRow(_ session: SessionManager.SessionInfo) -> some View {
        HStack {
            ProgressView(value: Double(session.receivedBytes), total: Double(session.expectedByteSize))
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.assetLocalID)
                    .font(.caption)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: session.receivedBytes, countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusPill(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status == "paired" ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
            .foregroundStyle(status == "paired" ? .green : .secondary)
            .clipShape(Capsule())
    }
}

// MARK: - ViewModel

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var pairedDevices: [PairedDeviceRecord] = []
    @Published var activeSessions: [SessionManager.SessionInfo] = []
    @Published var allAssets: [BackupAssetRecord] = []
    @Published var selectedDevice: String?
    @Published var backupFolderPath: String?

    var selectedDeviceInfo: PairedDeviceRecord? {
        pairedDevices.first { $0.deviceId == selectedDevice }
    }

    func load() async {
        // Populated by the app coordinator which injects DatabaseManager
    }

    func assets(for deviceId: String) -> [BackupAssetRecord] {
        allAssets.filter { $0.deviceId == deviceId && $0.status == "completed" }
    }

    func assetCount(for deviceId: String) -> Int {
        allAssets.filter { $0.deviceId == deviceId && $0.status == "completed" }.count
    }

    func duplicateCount(for deviceId: String) -> Int {
        allAssets.filter { $0.deviceId == deviceId && $0.status == "duplicate" }.count
    }

    func failedCount(for deviceId: String) -> Int {
        allAssets.filter { $0.deviceId == deviceId && $0.status == "failed" }.count
    }

    func selectBackupFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose the backup root folder"
        if panel.runModal() == .OK, let url = panel.url {
            backupFolderPath = url.path
        }
    }
}
