import SwiftUI
import AppKit
import QuickLook
import QuickLookThumbnailing
import AVFoundation
import CryptoKit
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
    @State private var hoveredHistoryControlID: String?
    @State private var hoveredMediaFilter: AssetHistoryMediaFilter?

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
                    if let lastBackupSummary = lastBackupSummary(for: device) {
                        Text(lastBackupSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No backups yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                statusPill(device.pairingStatus)
            }
            
            Text(historySummary(for: device))
                .font(.caption)
                .foregroundStyle(.secondary)

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

                    ZStack(alignment: .bottom) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(viewModel.visibleAssetSections, id: \.id) { section in
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
                            .padding(.bottom, 96)
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

                        historyFloatingControls
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var historyFloatingControls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                historyControlButton(
                    id: "view-list",
                    isSelected: viewModel.assetHistoryViewMode == .list,
                    action: { viewModel.assetHistoryViewMode = .list }
                ) {
                    Image(systemName: "list.bullet")
                        .frame(width: 30, height: 30)
                }

                historyControlButton(
                    id: "view-grid",
                    isSelected: viewModel.assetHistoryViewMode == .grid,
                    action: { viewModel.assetHistoryViewMode = .grid }
                ) {
                    Image(systemName: "square.grid.2x2")
                        .frame(width: 30, height: 30)
                }
            }

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1, height: 22)

            HStack(spacing: 4) {
                ForEach(AssetHistoryTimeGroupingMode.allCases) { mode in
                    historyControlButton(
                        id: "group-\(mode.rawValue)",
                        isSelected: viewModel.assetHistoryTimeGroupingMode == mode,
                        action: { viewModel.assetHistoryTimeGroupingMode = mode }
                    ) {
                        Text(mode.label)
                            .font(.caption.weight(.semibold))
                            .frame(minWidth: 54)
                            .padding(.horizontal, 2)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }

    private func historyControlButton<Content: View>(
        id: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isHovered = hoveredHistoryControlID == id

        return Button(action: action) {
            content()
                .foregroundStyle(isSelected ? Color.accentColor : (isHovered ? Color.primary : Color.secondary))
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? Color.accentColor.opacity(isHovered ? 0.24 : 0.18)
                                : (isHovered ? Color.primary.opacity(0.08) : .clear)
                        )
                )
                .scaleEffect(isSelected ? 1.02 : (isHovered ? 1.015 : 1.0))
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.16) : .clear,
                    radius: isSelected ? 8 : 0,
                    y: isSelected ? 4 : 0
                )
                .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isHovered)
                .animation(.spring(response: 0.24, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredHistoryControlID = isHovering ? id : (hoveredHistoryControlID == id ? nil : hoveredHistoryControlID)
        }
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

    private func mediaFilterChip(_ filter: AssetHistoryMediaFilter) -> some View {
        let isSelected = viewModel.assetHistoryMediaFilter == filter
        let isHovered = hoveredMediaFilter == filter

        return Button {
            viewModel.assetHistoryMediaFilter = filter
            Task { await viewModel.loadSelectedDeviceAssets(reset: true) }
        } label: {
            Text(filter.label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    isSelected
                    ? Color.accentColor.opacity(isHovered ? 0.22 : 0.16)
                    : (isHovered ? Color.secondary.opacity(0.16) : Color.secondary.opacity(0.10))
                )
                .foregroundStyle(isSelected ? Color.accentColor : (isHovered ? Color.primary : Color.secondary))
                .clipShape(Capsule())
                .scaleEffect(isSelected ? 1.02 : (isHovered ? 1.015 : 1.0))
                .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isHovered)
                .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredMediaFilter = isHovering ? filter : (hoveredMediaFilter == filter ? nil : hoveredMediaFilter)
        }
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
                }

                HStack(spacing: 14) {
                    Label(asset.mediaType.capitalized, systemImage: "photo")
                    Label(ByteCountFormatter.string(fromByteCount: asset.byteSize, countStyle: .file), systemImage: "externaldrive")
                    Label(asset.creationDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
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
                Task { await viewModel.prefetchVisibleAssetNeighborhood(around: index, size: 48) }
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
                Task { await viewModel.prefetchVisibleAssetNeighborhood(around: index, size: itemSize) }
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

    private func historySummary(for device: PairedDeviceRecord) -> String {
        let backedUp = viewModel.assetCount(for: device.deviceId)
        let duplicates = viewModel.duplicateCount(for: device.deviceId)
        let failed = viewModel.failedCount(for: device.deviceId)
        return "\(backedUp.formatted()) files • \(duplicates.formatted()) duplicates • \(failed.formatted()) failed"
    }

    private func lastBackupSummary(for device: PairedDeviceRecord) -> String? {
        guard let date = viewModel.lastBackupDate(for: device.deviceId) else { return nil }
        return "Backed up \(date.formatted(.relative(presentation: .named)))"
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
    @Published fileprivate var visibleAssetSections: [AssetHistorySection] = []
    @Published var hasMoreVisibleAssets = false
    @Published var isLoadingAssetPage = false
    @Published var selectedDevice: String?
    @Published var backupFolderPath: String?
    @Published var assetSearchQuery = ""
    @Published var assetHistoryViewMode: AssetHistoryViewMode = .list
    @Published var assetHistoryTimeGroupingMode: AssetHistoryTimeGroupingMode = .month {
        didSet {
            rebuildVisibleAssetSections()
        }
    }
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
            visibleAssetSections = []
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
                visibleAssetSections = Self.buildSections(from: page, mode: assetHistoryTimeGroupingMode)
            } else {
                let startIndex = visibleAssets.count
                visibleAssets.append(contentsOf: page)
                appendSections(for: page, startingAt: startIndex)
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

    func prefetchVisibleAssetNeighborhood(around index: Int, size: CGFloat) async {
        guard !visibleAssets.isEmpty else { return }
        let lowerBound = max(0, index - 12)
        let upperBound = min(visibleAssets.count - 1, index + 24)
        let assetsToWarm = Array(visibleAssets[lowerBound...upperBound])

        await withTaskGroup(of: Void.self) { group in
            for asset in assetsToWarm {
                group.addTask {
                    await AssetHistoryThumbnailPrefetcher.prefetch(asset: asset, size: size)
                }
            }
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

    func lastBackupDate(for deviceId: String) -> Date? {
        allAssets
            .filter { $0.deviceId == deviceId && ($0.status == "completed" || $0.status == "duplicate") }
            .compactMap(\.completedAt)
            .max()
    }

    func selectBackupFolder() {
        AppCoordinator.shared.selectBackupFolder()
        Task {
            await load()
        }
    }

    private func rebuildVisibleAssetSections() {
        visibleAssetSections = Self.buildSections(from: visibleAssets, mode: assetHistoryTimeGroupingMode)
    }

    private func appendSections(for page: [BackupAssetRecord], startingAt startIndex: Int) {
        guard !page.isEmpty else { return }

        var sections = visibleAssetSections
        for (offset, asset) in page.enumerated() {
            let entry = AssetHistoryEntry(index: startIndex + offset, asset: asset)
            let key = Self.sectionKey(for: asset, mode: assetHistoryTimeGroupingMode)

            if !sections.isEmpty, sections[sections.count - 1].id == key.id {
                sections[sections.count - 1].entries.append(entry)
            } else {
                sections.append(AssetHistorySection(id: key.id, title: key.title, entries: [entry]))
            }
        }

        visibleAssetSections = sections
    }

    private static func buildSections(from assets: [BackupAssetRecord], mode: AssetHistoryTimeGroupingMode) -> [AssetHistorySection] {
        guard !assets.isEmpty else { return [] }

        var sections: [AssetHistorySection] = []
        sections.reserveCapacity(max(1, assets.count / 16))

        for (index, asset) in assets.enumerated() {
            let key = sectionKey(for: asset, mode: mode)
            let entry = AssetHistoryEntry(index: index, asset: asset)

            if !sections.isEmpty, sections[sections.count - 1].id == key.id {
                sections[sections.count - 1].entries.append(entry)
            } else {
                sections.append(AssetHistorySection(id: key.id, title: key.title, entries: [entry]))
            }
        }

        return sections
    }

    private static func sectionKey(for asset: BackupAssetRecord, mode: AssetHistoryTimeGroupingMode) -> AssetHistorySectionKey {
        let calendar = Calendar(identifier: .gregorian)
        let date = asset.creationDate

        switch mode {
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
        .overlay(alignment: .bottomTrailing) {
            if let durationLabel {
                Text(durationLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(6)
            }
        }
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

    private var durationLabel: String? {
        guard asset.mediaType.lowercased() == "video", let duration = asset.durationSeconds, duration > 0 else {
            return nil
        }

        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

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
        let displayScale = NSScreen.main?.backingScaleFactor ?? 2

        if let thumbnailData = await AssetHistoryThumbnailCache.shared.thumbnailData(
            for: fileURL,
            mediaType: mediaType,
            size: size,
            scale: displayScale
        ), let generatedImage = NSImage(data: thumbnailData) {
            await MainActor.run {
                if image == nil {
                    image = generatedImage
                }
            }
        }
    }

    static func generateThumbnailData(fileURL: URL, mediaType: String, size: CGFloat, scale: CGFloat) async -> Data? {
        if let directImage = loadDirectThumbnail(fileURL: fileURL, mediaType: mediaType, size: size) {
            return jpegData(from: directImage)
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: size * 2, height: size * 2),
            scale: scale,
            representationTypes: .all
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let croppedImage = squareCroppedImage(from: thumbnail.nsImage, size: size) ?? thumbnail.nsImage
            return jpegData(from: croppedImage)
        } catch {
            return nil
        }
    }

    private static func loadDirectThumbnail(fileURL: URL, mediaType: String, size: CGFloat) -> NSImage? {
        if mediaType.lowercased() == "video" {
            let asset = AVURLAsset(url: fileURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: size * 2, height: size * 2)

            do {
                let frame = try generator.copyCGImage(at: .zero, actualTime: nil)
                return squareCroppedImage(from: frame, size: size)
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

        return squareCroppedImage(from: cgImage, size: size)
    }

    private static func squareCroppedImage(from nsImage: NSImage, size: CGFloat) -> NSImage? {
        var proposedRect = CGRect(origin: .zero, size: nsImage.size)
        guard let cgImage = nsImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }
        return squareCroppedImage(from: cgImage, size: size)
    }

    private static func squareCroppedImage(from cgImage: CGImage, size: CGFloat) -> NSImage {
        let sideLength = min(cgImage.width, cgImage.height)
        let cropRect = CGRect(
            x: (cgImage.width - sideLength) / 2,
            y: (cgImage.height - sideLength) / 2,
            width: sideLength,
            height: sideLength
        )
        let croppedImage = cgImage.cropping(to: cropRect) ?? cgImage
        return NSImage(cgImage: croppedImage, size: CGSize(width: size, height: size))
    }

    private static func jpegData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.82]
        )
    }
}

actor AssetHistoryThumbnailCache {
    static let shared = AssetHistoryThumbnailCache()

    private let memoryCache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    private var inFlightTasks: [String: Task<Data?, Never>] = [:]

    init() {
        memoryCache.countLimit = 512
        memoryCache.totalCostLimit = 128 * 1024 * 1024

        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let baseURL = applicationSupportURL.appendingPathComponent("iCherri", isDirectory: true)
        diskCacheURL = baseURL.appendingPathComponent("ThumbnailCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true, attributes: nil)
    }

    func cachedImageData(for fileURL: URL, size: CGFloat) -> Data? {
        guard let cacheKey = cacheKey(for: fileURL, size: size) else { return nil }
        let nsCacheKey = cacheKey as NSString

        if let imageData = memoryCache.object(forKey: nsCacheKey) {
            return imageData as Data
        }

        let cachedFileURL = diskCacheURL.appendingPathComponent(cacheKey).appendingPathExtension("jpg")
        guard let data = try? Data(contentsOf: cachedFileURL, options: [.mappedIfSafe]) else {
            return nil
        }

        memoryCache.setObject(data as NSData, forKey: nsCacheKey, cost: estimatedCost(for: size))
        return data
    }

    func store(_ data: Data, for fileURL: URL, size: CGFloat) {
        guard let cacheKey = cacheKey(for: fileURL, size: size) else { return }
        store(data, cacheKey: cacheKey, size: size)
    }

    func thumbnailData(for fileURL: URL, mediaType: String, size: CGFloat, scale: CGFloat) async -> Data? {
        guard let cacheKey = cacheKey(for: fileURL, size: size) else { return nil }

        if let cachedData = cachedImageData(for: fileURL, size: size) {
            return cachedData
        }

        if let existingTask = inFlightTasks[cacheKey] {
            return await existingTask.value
        }

        let task = Task.detached(priority: .utility) {
            await AssetHistoryThumbnailLoader.generateThumbnailData(
                fileURL: fileURL,
                mediaType: mediaType,
                size: size,
                scale: scale
            )
        }
        inFlightTasks[cacheKey] = task

        let generatedData = await task.value
        inFlightTasks[cacheKey] = nil

        if let generatedData {
            store(generatedData, cacheKey: cacheKey, size: size)
        }

        return generatedData
    }

    private func cacheKey(for fileURL: URL, size: CGFloat) -> String? {
        let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
        let modificationDate = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let rawKey = "\(fileURL.path)|\(Int(size.rounded()))|\(modificationDate)"
        let digest = SHA256.hash(data: Data(rawKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func estimatedCost(for size: CGFloat) -> Int {
        Int(size * size * 4)
    }

    private func store(_ data: Data, cacheKey: String, size: CGFloat) {
        let nsCacheKey = cacheKey as NSString
        memoryCache.setObject(data as NSData, forKey: nsCacheKey, cost: estimatedCost(for: size))

        let cachedFileURL = diskCacheURL.appendingPathComponent(cacheKey).appendingPathExtension("jpg")
        try? data.write(to: cachedFileURL, options: .atomic)
    }
}

enum AssetHistoryThumbnailPrefetcher {
    static func prewarmCommittedAsset(relativePath: String, mediaType: String) async {
        let resolvedPath: String
        if (relativePath as NSString).isAbsolutePath {
            resolvedPath = relativePath
        } else {
            let backupFolder = await MainActor.run { AppCoordinator.shared.backupFolder }
            resolvedPath = backupFolder.appendingPathComponent(relativePath).path
        }

        guard !resolvedPath.isEmpty else { return }
        let fileURL = URL(fileURLWithPath: resolvedPath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let sizes: [CGFloat] = [48, 96, 160, 240]
        await withTaskGroup(of: Void.self) { group in
            for size in sizes {
                group.addTask {
                    await prefetch(fileURL: fileURL, mediaType: mediaType, size: size)
                }
            }
        }
    }

    static func prefetch(asset: BackupAssetRecord, size: CGFloat) async {
        let resolvedPath: String
        if (asset.finalPath as NSString).isAbsolutePath {
            resolvedPath = asset.finalPath
        } else {
            let backupFolder = await MainActor.run { AppCoordinator.shared.backupFolder }
            resolvedPath = backupFolder
                .appendingPathComponent(asset.finalPath)
                .path
        }

        guard !resolvedPath.isEmpty else { return }

        let fileURL = URL(fileURLWithPath: resolvedPath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        await prefetch(fileURL: fileURL, mediaType: asset.mediaType, size: size)
    }

    static func prefetch(fileURL: URL, mediaType: String, size: CGFloat) async {
        let displayScale = NSScreen.main?.backingScaleFactor ?? 2
        _ = await AssetHistoryThumbnailCache.shared.thumbnailData(
            for: fileURL,
            mediaType: mediaType,
            size: size,
            scale: displayScale
        )
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
    var entries: [AssetHistoryEntry]
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
