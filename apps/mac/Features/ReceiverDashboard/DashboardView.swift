import SwiftUI
import ICherriDesignSystem
import ICherriProtocol
import Inject

// macOS receiver dashboard showing paired devices, active sessions, and backup history.
struct DashboardView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = DashboardViewModel()
    @State private var devicePendingDeletion: PairedDeviceRecord?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .navigationTitle("iCherri Receiver")
        .enableInjection()
        .toolbar { toolbarContent }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .changeBackupFolder)) { _ in
            viewModel.selectBackupFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiverDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .alert(
            "Delete Paired Device?",
            isPresented: Binding(
                get: { devicePendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        devicePendingDeletion = nil
                    }
                }
            ),
            presenting: devicePendingDeletion
        ) { device in
            Button("Delete", role: .destructive) {
                Task { await viewModel.confirmDeleteDevice(device) }
            }
            Button("Cancel", role: .cancel) {
                devicePendingDeletion = nil
            }
        } message: { device in
            Text("This removes \(device.deviceName), its backup history, active sessions, and failure logs from this Mac.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $viewModel.selectedDevice) {
            Section("Paired Devices") {
                ForEach(viewModel.pairedDevices, id: \.deviceId) { device in
                    deviceRow(device)
                        .tag(device.deviceId)
                        .contextMenu {
                            Button("Delete Device", role: .destructive) {
                                devicePendingDeletion = device
                            }
                        }
                }
            }
            Section("Active Uploads") {
                ForEach(viewModel.activeUploads) { upload in
                    activeUploadRow(upload)
                }
                if viewModel.activeUploads.isEmpty {
                    Text("No active uploads")
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

    private func activeUploadRow(_ upload: DashboardActiveUpload) -> some View {
        HStack {
            ProgressView(value: Double(upload.receivedBytes), total: Double(upload.expectedByteSize))
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(upload.filename)
                    .font(.caption)
                    .lineLimit(1)
                Text(upload.subtitle)
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
    @Published var activeUploads: [DashboardActiveUpload] = []
    @Published var allAssets: [BackupAssetRecord] = []
    @Published var selectedDevice: String?
    @Published var backupFolderPath: String?

    var selectedDeviceInfo: PairedDeviceRecord? {
        pairedDevices.first { $0.deviceId == selectedDevice }
    }

    func load() async {
        do {
            let previousSelection = selectedDevice
            self.backupFolderPath = AppCoordinator.shared.backupFolder.path
            
            let devices = try await DatabaseManager.shared.fetchAllDevices()
            let assets = try await DatabaseManager.shared.fetchAllAssets()
            let sessions = try await DatabaseManager.shared.fetchAllSessions()
            
            self.pairedDevices = devices
            self.allAssets = assets
            let deviceNames = Dictionary(uniqueKeysWithValues: devices.map { ($0.deviceId, $0.deviceName) })
            self.activeUploads = sessions.map { r in
                var filename = "Upload"
                var assetCreatedAt: Date?
                if let data = r.metadataJson.data(using: .utf8),
                   let metadata = try? JSONDecoder().decode(AssetMetadata.self, from: data) {
                    filename = metadata.originalFilename
                    assetCreatedAt = metadata.creationDate
                }

                return DashboardActiveUpload(
                    uploadID: r.uploadId,
                    filename: filename,
                    deviceName: deviceNames[r.deviceId] ?? r.deviceId,
                    assetCreatedAt: assetCreatedAt,
                    expectedByteSize: r.expectedByteSize,
                    receivedBytes: r.receivedBytes,
                    status: r.status
                )
            }

            if let previousSelection, devices.contains(where: { $0.deviceId == previousSelection }) {
                self.selectedDevice = previousSelection
            } else {
                self.selectedDevice = devices.first?.deviceId
            }
        } catch {
            print("[DashboardViewModel] Load failed: \(error)")
        }
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
        AppCoordinator.shared.selectBackupFolder()
        Task {
            await load()
        }
    }

    func confirmDeleteDevice(_ device: PairedDeviceRecord) async {
        do {
            let tempPaths = try await DatabaseManager.shared.deletePairedDevice(deviceId: device.deviceId)
            let keychain = MacKeychainStore()
            try? keychain.deleteTrustToken(for: device.deviceId)
            for path in tempPaths {
                try? FileManager.default.removeItem(atPath: path)
            }

            if selectedDevice == device.deviceId {
                selectedDevice = nil
            }

            await load()
        } catch {
            print("[DashboardViewModel] Delete device failed: \(error)")
        }
    }
}

struct DashboardActiveUpload: Identifiable {
    let uploadID: String
    let filename: String
    let deviceName: String
    let assetCreatedAt: Date?
    let expectedByteSize: Int64
    let receivedBytes: Int64
    let status: String

    var id: String { uploadID }

    var subtitle: String {
        let createdLabel = assetCreatedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown date"
        let receivedLabel = ByteCountFormatter.string(fromByteCount: receivedBytes, countStyle: .file)
        let totalLabel = ByteCountFormatter.string(fromByteCount: expectedByteSize, countStyle: .file)
        return "\(createdLabel) · \(deviceName) · \(receivedLabel) / \(totalLabel) · sess \(shortUploadID)"
    }

    private var shortUploadID: String {
        String(uploadID.prefix(6)).uppercased()
    }
}
