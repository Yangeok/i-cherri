import SwiftUI
import AppKit
import QuickLook
import QuickLookThumbnailing
import AVFoundation
import ImageIO
import ICherriDesignSystem
import ICherriProtocol
import Inject

// macOS receiver dashboard showing paired devices, active sessions, and backup history.
struct DashboardView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = DashboardViewModel()
    @State private var devicePendingDeletion: PairedDeviceRecord?
    @State private var previewURL: URL?
    @State private var assetActionError: String?
    @State private var gridPinchStartColumns: Int?

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
        .alert("File Unavailable", isPresented: Binding(
            get: { assetActionError != nil },
            set: { isPresented in
                if !isPresented {
                    assetActionError = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                assetActionError = nil
            }
        } message: {
            Text(assetActionError ?? "The backup file could not be found.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List {
            Section("Paired Devices") {
                ForEach(viewModel.pairedDevices, id: \.deviceId) { device in
                    deviceRow(device)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedDevice = device.deviceId
                        }
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
                        .selectionDisabled(true)
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
        VStack(alignment: .leading, spacing: 12) {
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
            
            HStack(spacing: 8) {
                compactStatChip(label: "Backed Up", value: viewModel.assetCount(for: device.deviceId), color: .green)
                compactStatChip(label: "Duplicates", value: viewModel.duplicateCount(for: device.deviceId), color: .orange)
                compactStatChip(label: "Failed", value: viewModel.failedCount(for: device.deviceId), color: .red)
                Spacer()
                historyViewModePicker
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search filename", text: $viewModel.assetSearchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .onChange(of: viewModel.assetSearchQuery) { _, _ in
                Task { await viewModel.loadSelectedDeviceAssets(reset: true) }
            }

            HStack(spacing: 8) {
                ForEach(AssetHistoryMediaFilter.allCases) { filter in
                    mediaFilterChip(filter)
                }
                Spacer()
            }

            if viewModel.visibleAssets.isEmpty, !viewModel.isLoadingAssetPage {
                emptyHistoryState
            } else {
                GeometryReader { proxy in
                    let contentWidth = max(proxy.size.width, 1)
                    let gridColumns = Array(
                        repeating: GridItem(.flexible(), spacing: 8, alignment: .top),
                        count: viewModel.gridColumnCount
                    )
                    let gridItemSize = (contentWidth - CGFloat(max(viewModel.gridColumnCount - 1, 0)) * 8) / CGFloat(viewModel.gridColumnCount)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(groupedVisibleAssets, id: \.id) { section in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(section.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    if viewModel.assetHistoryViewMode == .grid {
                                        LazyVGrid(columns: gridColumns, spacing: 8) {
                                            ForEach(section.entries) { entry in
                                                assetHistoryGridItem(entry.asset, index: entry.index, itemSize: gridItemSize)
                                            }
                                        }
                                    } else {
                                        LazyVStack(spacing: 8) {
                                            ForEach(section.entries) { entry in
                                                assetHistoryListItem(entry.asset, index: entry.index)
                                            }
                                        }
                                    }
                                }
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
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                guard viewModel.assetHistoryViewMode == .grid else { return }
                                let start = gridPinchStartColumns ?? viewModel.gridColumnCount
                                if gridPinchStartColumns == nil {
                                    gridPinchStartColumns = start
                                }
                                let proposed = Int((Double(start) / Double(value)).rounded())
                                viewModel.gridColumnCount = min(max(proposed, 2), 6)
                            }
                            .onEnded { value in
                                guard viewModel.assetHistoryViewMode == .grid else { return }
                                let start = gridPinchStartColumns ?? viewModel.gridColumnCount
                                let proposed = Int((Double(start) / Double(value)).rounded())
                                viewModel.gridColumnCount = min(max(proposed, 2), 6)
                                gridPinchStartColumns = nil
                            }
                    )
                }
            }
        }
        .padding(24)
        .padding(.bottom, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottom) {
            timeGroupingBar
                .padding(.bottom, 18)
        }
    }

    private var historyViewModePicker: some View {
        HStack(spacing: 4) {
            Button {
                viewModel.assetHistoryViewMode = .list
            } label: {
                Image(systemName: "list.bullet")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(viewModel.assetHistoryViewMode == .list ? Color.secondary.opacity(0.16) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                viewModel.assetHistoryViewMode = .grid
            } label: {
                Image(systemName: "square.grid.2x2")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(viewModel.assetHistoryViewMode == .grid ? Color.secondary.opacity(0.16) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(4)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var timeGroupingBar: some View {
        HStack(spacing: 4) {
            ForEach(AssetHistoryTimeGroupingMode.allCases) { mode in
                Button {
                    viewModel.assetHistoryTimeGroupingMode = mode
                } label: {
                    Text(mode.label)
                        .font(.caption.weight(.medium))
                        .frame(minWidth: 56)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(viewModel.assetHistoryTimeGroupingMode == mode ? Color.accentColor.opacity(0.16) : .clear)
                .foregroundStyle(viewModel.assetHistoryTimeGroupingMode == mode ? Color.accentColor : Color.secondary)
                .clipShape(Capsule())
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
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
        .padding(.vertical, 2)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(viewModel.selectedDevice == device.deviceId ? Color.accentColor.opacity(0.14) : .clear)
        )
    }

    private func activeUploadRow(_ upload: DashboardActiveUpload) -> some View {
        HStack {
            ProgressView(value: Double(upload.receivedBytes), total: Double(upload.expectedByteSize))
                .frame(width: 40)
                .tint(upload.status == "receiving" ? .accentColor : .gray)
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
            Text("No backup history matches this search")
                .foregroundStyle(.secondary)
            Text("Adjust the search text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func compactStatChip(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
    }

    private func mediaFilterChip(_ filter: AssetHistoryMediaFilter) -> some View {
        Button {
            viewModel.assetHistoryMediaFilter = filter
            Task { await viewModel.loadSelectedDeviceAssets(reset: true) }
        } label: {
            Text(filter.label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    viewModel.assetHistoryMediaFilter == filter
                    ? Color.accentColor.opacity(0.16)
                    : Color.secondary.opacity(0.10)
                )
                .foregroundStyle(viewModel.assetHistoryMediaFilter == filter ? Color.accentColor : Color.secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func assetHistoryRow(_ asset: BackupAssetRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AssetHistoryThumbnailView(asset: asset, size: 48)

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
                    Label("Backed up \(assetHistoryDate(asset))", systemImage: "calendar")
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func assetHistoryGridCard(_ asset: BackupAssetRecord, itemSize: CGFloat) -> some View {
        AssetHistoryThumbnailView(asset: asset, size: itemSize)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func assetHistoryListItem(_ asset: BackupAssetRecord, index: Int) -> some View {
        assetHistoryRow(asset)
            .modifier(AssetHistoryInteractionModifier(
                onPreview: { previewAsset(asset) },
                onOpen: { openAsset(asset) },
                onReveal: { revealAsset(asset) }
            ))
            .onAppear {
                Task { await viewModel.loadMoreIfNeeded(currentIndex: index) }
            }
    }

    private func assetHistoryGridItem(_ asset: BackupAssetRecord, index: Int, itemSize: CGFloat) -> some View {
        assetHistoryGridCard(asset, itemSize: itemSize)
            .id("\(asset.backupId)-\(viewModel.gridColumnCount)")
            .modifier(AssetHistoryInteractionModifier(
                onPreview: { previewAsset(asset) },
                onOpen: { openAsset(asset) },
                onReveal: { revealAsset(asset) }
            ))
            .onAppear {
                Task { await viewModel.loadMoreIfNeeded(currentIndex: index) }
            }
    }

    private func assetHistoryDate(_ asset: BackupAssetRecord) -> String {
        (asset.completedAt ?? asset.firstSeenAt).formatted(date: .abbreviated, time: .shortened)
    }

    private var groupedVisibleAssets: [AssetHistorySection] {
        let entries = viewModel.visibleAssets.enumerated().map { AssetHistoryEntry(index: $0.offset, asset: $0.element) }
        let grouped = Dictionary(grouping: entries) { entry in
            sectionKey(for: entry.asset)
        }

        return grouped
            .map { key, entries in
                AssetHistorySection(
                    id: key.id,
                    title: key.title,
                    entries: entries.sorted { $0.index < $1.index }
                )
            }
            .sorted { $0.id > $1.id }
    }

    private func sectionKey(for asset: BackupAssetRecord) -> AssetHistorySectionKey {
        let calendar = Calendar(identifier: .gregorian)
        let date = asset.creationDate
        switch viewModel.assetHistoryTimeGroupingMode {
        case .year:
            let year = calendar.component(.year, from: date)
            return AssetHistorySectionKey(id: String(format: "%04d", year), title: "\(year)")
        case .month:
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let monthName = date.formatted(.dateTime.year().month(.wide))
            return AssetHistorySectionKey(id: String(format: "%04d-%02d", year, month), title: monthName)
        case .day:
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)
            return AssetHistorySectionKey(
                id: String(format: "%04d-%02d-%02d", year, month, day),
                title: date.formatted(date: .complete, time: .omitted)
            )
        }
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
        guard let url = assetFileURL(asset) else {
            assetActionError = missingFileMessage(for: asset)
            return
        }
        previewURL = nil
        DispatchQueue.main.async {
            previewURL = url
        }
    }

    private func openAsset(_ asset: BackupAssetRecord) {
        guard let url = assetFileURL(asset) else {
            assetActionError = missingFileMessage(for: asset)
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func revealAsset(_ asset: BackupAssetRecord) {
        guard let url = assetFileURL(asset) else {
            assetActionError = missingFileMessage(for: asset)
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func missingFileMessage(for asset: BackupAssetRecord) -> String {
        "Could not find \(asset.originalFilename) in the current backup folder."
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

private struct AssetHistoryInteractionModifier: ViewModifier {
    let onPreview: () -> Void
    let onOpen: () -> Void
    let onReveal: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture(count: 2) {
                onPreview()
            }
            .contextMenu {
                Button("Preview") {
                    onPreview()
                }
                Button("Open") {
                    onOpen()
                }
                Button("Reveal in Finder") {
                    onReveal()
                }
            }
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
    @Published var assetHistoryViewMode: AssetHistoryViewMode = .list
    @Published var assetHistoryTimeGroupingMode: AssetHistoryTimeGroupingMode = .month
    @Published var assetHistoryMediaFilter: AssetHistoryMediaFilter = .all
    @Published var gridColumnCount: Int = 4

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
                status: nil,
                mediaType: assetHistoryMediaFilter.databaseValue,
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
    let size: CGFloat
    @StateObject private var loader: AssetHistoryThumbnailLoader

    init(asset: BackupAssetRecord, size: CGFloat) {
        self.asset = asset
        self.size = size
        let resolvedPath: String
        if (asset.finalPath as NSString).isAbsolutePath {
            resolvedPath = asset.finalPath
        } else {
            resolvedPath = AppCoordinator.shared.backupFolder
                .appendingPathComponent(asset.finalPath)
                .path
        }
        _loader = StateObject(wrappedValue: AssetHistoryThumbnailLoader(path: resolvedPath, mediaType: asset.mediaType, size: size))
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
        .frame(width: size, height: size)
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
    private let mediaType: String
    private let size: CGFloat
    private var hasLoaded = false

    init(path: String, mediaType: String, size: CGFloat) {
        self.path = path
        self.mediaType = mediaType
        self.size = size
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard !path.isEmpty else { return }

        let fileURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        if let directImage = loadDirectThumbnail(fileURL: fileURL) {
            image = directImage
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: size * 2, height: size * 2),
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

    private func loadDirectThumbnail(fileURL: URL) -> NSImage? {
        if mediaType.lowercased() == "video" {
            let asset = AVURLAsset(url: fileURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: size * 2, height: size * 2)

            do {
                let frame = try generator.copyCGImage(at: .zero, actualTime: nil)
                return NSImage(cgImage: frame, size: CGSize(width: size, height: size))
            } catch {
                return nil
            }
        }

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(size * 2)
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: CGSize(width: size, height: size))
    }
}

enum AssetHistoryViewMode: String, CaseIterable, Identifiable {
    case list
    case grid

    var id: String { rawValue }
}

enum AssetHistoryTimeGroupingMode: String, CaseIterable, Identifiable {
    case year
    case month
    case day

    var id: String { rawValue }

    var label: String {
        switch self {
        case .year:
            return "Year"
        case .month:
            return "Month"
        case .day:
            return "Day"
        }
    }
}

enum AssetHistoryMediaFilter: String, CaseIterable, Identifiable {
    case all
    case photos
    case videos

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "All"
        case .photos:
            return "Photos"
        case .videos:
            return "Videos"
        }
    }

    var databaseValue: String? {
        switch self {
        case .all:
            return nil
        case .photos:
            return "photo"
        case .videos:
            return "video"
        }
    }
}

private struct AssetHistoryEntry: Identifiable {
    let index: Int
    let asset: BackupAssetRecord

    var id: String { asset.backupId }
}

private struct AssetHistorySection: Identifiable {
    let id: String
    let title: String
    let entries: [AssetHistoryEntry]
}

private struct AssetHistorySectionKey: Hashable {
    let id: String
    let title: String
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
