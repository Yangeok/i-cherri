import SwiftUI
import AppKit
import QuickLook
import QuickLookThumbnailing
import ICherriDesignSystem
import ICherriProtocol
import Inject

// macOS receiver dashboard showing paired devices, active sessions, and backup history.
struct DashboardView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = DashboardViewModel()
    @State private var devicePendingDeletion: PairedDeviceRecord?
    @State private var previewURL: URL?

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
        .onChange(of: viewModel.selectedDevice) { _, _ in
            Task { await viewModel.loadSelectedDeviceAssets(reset: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .changeBackupFolder)) { _ in
            viewModel.selectBackupFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiverDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .quickLookPreview($previewURL)
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
                        .allowsHitTesting(false)
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

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search filename", text: $viewModel.assetSearchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Picker("Status", selection: $viewModel.assetStatusFilter) {
                    ForEach(AssetHistoryFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
            .onChange(of: viewModel.assetSearchQuery) { _, _ in
                Task { await viewModel.loadSelectedDeviceAssets(reset: true) }
            }
            .onChange(of: viewModel.assetStatusFilter) { _, _ in
                Task { await viewModel.loadSelectedDeviceAssets(reset: true) }
            }

            if viewModel.visibleAssets.isEmpty, !viewModel.isLoadingAssetPage {
                emptyHistoryState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(viewModel.visibleAssets.enumerated()), id: \.element.backupId) { index, asset in
                            assetHistoryListItem(asset, index: index)
                        }

                        if viewModel.isLoadingAssetPage {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Loading more history…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        } else if !viewModel.hasMoreVisibleAssets, !viewModel.visibleAssets.isEmpty {
                            Text("End of backup history")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
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

    private var emptyHistoryState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No backup history matches this filter")
                .foregroundStyle(.secondary)
            Text("Adjust the search text or status filter.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func assetHistoryRow(_ asset: BackupAssetRecord) -> some View {
        HStack(alignment: .top, spacing: 14) {
            AssetHistoryThumbnailView(asset: asset)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(asset.originalFilename)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(asset.creationDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(assetStatusLabel(asset.status))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(assetStatusColor(asset.status).opacity(0.14))
                        .foregroundStyle(assetStatusColor(asset.status))
                        .clipShape(Capsule())
                }

                HStack(spacing: 14) {
                    Label(asset.mediaType.capitalized, systemImage: "photo")
                    Label(ByteCountFormatter.string(fromByteCount: asset.byteSize, countStyle: .file), systemImage: "externaldrive")
                    Label(assetHistoryDate(asset), systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let lastError = asset.lastError, !lastError.isEmpty {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func assetHistoryListItem(_ asset: BackupAssetRecord, index: Int) -> some View {
        assetHistoryRow(asset)
            .onTapGesture(count: 2) {
                previewAsset(asset)
            }
            .contextMenu {
                Button("Preview") {
                    previewAsset(asset)
                }
                Button("Open") {
                    openAsset(asset)
                }
                Button("Reveal in Finder") {
                    revealAsset(asset)
                }
            }
            .onAppear {
                Task { await viewModel.loadMoreIfNeeded(currentIndex: index) }
            }
    }

    private func assetHistoryDate(_ asset: BackupAssetRecord) -> String {
        (asset.completedAt ?? asset.firstSeenAt).formatted(date: .abbreviated, time: .shortened)
    }

    private func assetIconName(_ mediaType: String) -> String {
        switch mediaType.lowercased() {
        case "video":
            return "video.fill"
        default:
            return "photo.fill"
        }
    }

    private func assetStatusLabel(_ status: String) -> String {
        switch status {
        case "completed":
            return "Backed Up"
        case "duplicate":
            return "Duplicate"
        case "failed":
            return "Failed"
        default:
            return status.capitalized
        }
    }

    private func assetStatusColor(_ status: String) -> Color {
        switch status {
        case "completed":
            return .green
        case "duplicate":
            return .orange
        case "failed":
            return .red
        default:
            return .secondary
        }
    }

    private func assetFileURL(_ asset: BackupAssetRecord) -> URL? {
        guard !asset.finalPath.isEmpty else { return nil }
        let url: URL
        if (asset.finalPath as NSString).isAbsolutePath {
            url = URL(fileURLWithPath: asset.finalPath)
        } else {
            url = AppCoordinator.shared.backupFolder.appendingPathComponent(asset.finalPath)
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func previewAsset(_ asset: BackupAssetRecord) {
        previewURL = assetFileURL(asset)
    }

    private func openAsset(_ asset: BackupAssetRecord) {
        guard let url = assetFileURL(asset) else { return }
        NSWorkspace.shared.open(url)
    }

    private func revealAsset(_ asset: BackupAssetRecord) {
        guard let url = assetFileURL(asset) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
    private static let assetPageSize = 200

    @Published var pairedDevices: [PairedDeviceRecord] = []
    @Published var activeUploads: [DashboardActiveUpload] = []
    @Published var allAssets: [BackupAssetRecord] = []
    @Published var visibleAssets: [BackupAssetRecord] = []
    @Published var hasMoreVisibleAssets = false
    @Published var isLoadingAssetPage = false
    @Published var selectedDevice: String?
    @Published var backupFolderPath: String?
    @Published var assetSearchQuery = ""
    @Published var assetStatusFilter: AssetHistoryFilter = .all

    private var assetPageOffset = 0

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

            await loadSelectedDeviceAssets(reset: true)
        } catch {
            print("[DashboardViewModel] Load failed: \(error)")
        }
    }

    func loadSelectedDeviceAssets(reset: Bool) async {
        guard let deviceId = selectedDevice else {
            visibleAssets = []
            hasMoreVisibleAssets = false
            assetPageOffset = 0
            return
        }
        guard !isLoadingAssetPage else { return }

        do {
            isLoadingAssetPage = true
            defer { isLoadingAssetPage = false }

            let offset = reset ? 0 : assetPageOffset
            let page = try await DatabaseManager.shared.fetchAssets(
                deviceId: deviceId,
                searchQuery: assetSearchQuery,
                status: assetStatusFilter.databaseValue,
                limit: Self.assetPageSize,
                offset: offset
            )

            if reset {
                visibleAssets = page
            } else {
                visibleAssets.append(contentsOf: page)
            }

            assetPageOffset = offset + page.count
            hasMoreVisibleAssets = page.count == Self.assetPageSize
        } catch {
            isLoadingAssetPage = false
            print("[DashboardViewModel] Asset page load failed: \(error)")
        }
    }

    func loadMoreIfNeeded(currentIndex: Int) async {
        guard hasMoreVisibleAssets else { return }
        guard currentIndex >= visibleAssets.count - 30 else { return }
        await loadSelectedDeviceAssets(reset: false)
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

private struct AssetHistoryThumbnailView: View {
    let asset: BackupAssetRecord
    @StateObject private var loader: AssetHistoryThumbnailLoader

    init(asset: BackupAssetRecord) {
        self.asset = asset
        let resolvedPath: String
        if (asset.finalPath as NSString).isAbsolutePath {
            resolvedPath = asset.finalPath
        } else {
            resolvedPath = AppCoordinator.shared.backupFolder
                .appendingPathComponent(asset.finalPath)
                .path
        }
        _loader = StateObject(wrappedValue: AssetHistoryThumbnailLoader(path: resolvedPath))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.12))
                    Image(systemName: iconName)
                        .foregroundStyle(color)
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task {
            await loader.loadIfNeeded()
        }
    }

    private var iconName: String {
        switch asset.mediaType.lowercased() {
        case "video":
            return "video.fill"
        default:
            return "photo.fill"
        }
    }

    private var color: Color {
        switch asset.status {
        case "completed":
            return .green
        case "duplicate":
            return .orange
        case "failed":
            return .red
        default:
            return .secondary
        }
    }
}

@MainActor
private final class AssetHistoryThumbnailLoader: ObservableObject {
    @Published var image: NSImage?

    private let path: String
    private var hasLoaded = false

    init(path: String) {
        self.path = path
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard !path.isEmpty else { return }

        let fileURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        if let directImage = NSImage(contentsOf: fileURL) {
            image = directImage
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: 112, height: 112),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .all
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            image = thumbnail.nsImage
        } catch {
            image = nil
        }
    }
}

enum AssetHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case completed
    case duplicate
    case failed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "All"
        case .completed:
            return "Backed Up"
        case .duplicate:
            return "Duplicates"
        case .failed:
            return "Failed"
        }
    }

    var databaseValue: String? {
        switch self {
        case .all:
            return nil
        default:
            return rawValue
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
