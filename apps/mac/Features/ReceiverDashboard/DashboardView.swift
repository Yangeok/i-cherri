import SwiftUI
import AppKit
import QuickLook
import QuickLookThumbnailing
import AVFoundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
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
    @State private var scrubberActiveSectionID: String?
    @State private var scrubberActiveSectionTitle: String?
    @State private var scrubberCommitTask: Task<Void, Never>?

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
            deviceHeader(device)
            historySearchBar
            historyMediaFilterBar
            historyBrowser
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func deviceHeader(_ device: PairedDeviceRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
        }
    }

    private var historySearchBar: some View {
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
    }

    private var historyMediaFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(AssetHistoryMediaFilter.allCases) { filter in
                mediaFilterChip(filter)
            }
            Spacer()
        }
    }

    private var historyBrowser: some View {
        Group {
            if viewModel.visibleAssets.isEmpty, !viewModel.isLoadingAssetPage {
                emptyHistoryState
            } else {
                GeometryReader { proxy in
                    historyBrowserContent(height: proxy.size.height, width: proxy.size.width)
                }
            }
        }
    }

    private func historyBrowserContent(height: CGFloat, width: CGFloat) -> some View {
        let contentWidth = max(width, 1)
        let columnCount = viewModel.gridColumnCount
        let gridColumns = Array(
            repeating: GridItem(.flexible(), spacing: 8, alignment: .top),
            count: columnCount
        )
        let gridItemSize = (contentWidth - CGFloat(max(columnCount - 1, 0)) * 8) / CGFloat(columnCount)

        return ScrollViewReader { scrollProxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.visibleAssetSections, id: \.id) { section in
                            historySectionView(section, gridColumns: gridColumns, gridItemSize: gridItemSize)
                        }

                        historyPaginationFooter
                    }
                    .padding(.bottom, 96)
                }
                .scrollContentBackground(.hidden)
                .gesture(historyGridMagnificationGesture)

                historyFloatingControls
                    .padding(.bottom, 16)

                historyTimelineScrubber(
                    sections: viewModel.scrubberSections,
                    height: height,
                    scrollProxy: scrollProxy
                )
                .padding(.trailing, 10)
                .padding(.bottom, 104)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func historySectionView(
        _ section: AssetHistorySection,
        gridColumns: [GridItem],
        gridItemSize: CGFloat
    ) -> some View {
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
        .id(section.id)
    }

    private var historyPaginationFooter: some View {
        Group {
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

    private var historyGridMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard viewModel.assetHistoryViewMode == .grid else { return }
                let start = gridPinchStartColumns ?? viewModel.gridColumnCount
                if gridPinchStartColumns == nil {
                    gridPinchStartColumns = start
                }
                if let proposed = proposedGridColumnCount(start: start, magnificationValue: value) {
                    viewModel.gridColumnCount = proposed
                }
            }
            .onEnded { value in
                guard viewModel.assetHistoryViewMode == .grid else { return }
                let start = gridPinchStartColumns ?? viewModel.gridColumnCount
                if let proposed = proposedGridColumnCount(start: start, magnificationValue: value) {
                    viewModel.gridColumnCount = proposed
                }
                gridPinchStartColumns = nil
            }
    }

    private func proposedGridColumnCount(start: Int, magnificationValue: CGFloat) -> Int? {
        let safeValue = Double(magnificationValue)
        guard safeValue.isFinite, safeValue > 0 else { return nil }

        let proposed = Double(start) / safeValue
        guard proposed.isFinite, !proposed.isNaN else { return nil }

        return min(max(Int(proposed.rounded()), 2), 6)
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

    private func historyTimelineScrubber(
        sections: [AssetHistorySection],
        height: CGFloat,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        let scrubberHeight = max(min(height - 156, 420), 180)

        return Group {
            if sections.count > 1 {
                HStack(spacing: 10) {
                    if let scrubberActiveSectionTitle {
                        Text(scrubberActiveSectionTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }

                    GeometryReader { scrubberProxy in
                        let scrubberSize = scrubberProxy.size
                        let markers = markerIndices(for: sections.count, trackHeight: scrubberSize.height)

                        ZStack(alignment: .top) {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                }

                            VStack(spacing: 0) {
                                ForEach(markers, id: \.self) { markerIndex in
                                    Circle()
                                        .fill(scrubberActiveSectionID == sections[markerIndex].id ? Color.accentColor : Color.secondary.opacity(0.45))
                                        .frame(width: scrubberActiveSectionID == sections[markerIndex].id ? 7 : 5, height: scrubberActiveSectionID == sections[markerIndex].id ? 7 : 5)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateScrubberSelection(
                                        locationY: value.location.y,
                                        trackHeight: scrubberSize.height,
                                        sections: sections
                                    )
                                }
                                .onEnded { _ in
                                    commitScrubberSelection(scrollProxy: scrollProxy)
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        scrubberActiveSectionTitle = nil
                                    }
                                }
                        )
                    }
                    .frame(width: 18, height: scrubberHeight)
                }
                .animation(.easeOut(duration: 0.16), value: scrubberActiveSectionTitle)
            }
        }
    }

    private func updateScrubberSelection(
        locationY: CGFloat,
        trackHeight: CGFloat,
        sections: [AssetHistorySection]
    ) {
        guard !sections.isEmpty else { return }
        let clampedY = min(max(locationY, 0), max(trackHeight, 1))
        let progress = clampedY / max(trackHeight, 1)
        let rawIndex = Int((progress * CGFloat(max(sections.count - 1, 0))).rounded())
        let section = sections[min(max(rawIndex, 0), sections.count - 1)]

        guard scrubberActiveSectionID != section.id else { return }

        scrubberActiveSectionID = section.id
        scrubberActiveSectionTitle = section.title

        if viewModel.visibleAssetSections.contains(where: { $0.id == section.id }) {
            // keep drag responsive for already-loaded sections without triggering pagination work
        }
    }

    private func commitScrubberSelection(scrollProxy: ScrollViewProxy) {
        guard let targetSectionID = scrubberActiveSectionID else { return }

        scrubberCommitTask?.cancel()
        scrubberCommitTask = Task {
            await viewModel.ensureSectionVisible(targetSectionID)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.12)) {
                    scrollProxy.scrollTo(targetSectionID, anchor: .top)
                }
            }
        }
    }

    private func markerIndices(for sectionCount: Int, trackHeight: CGFloat) -> [Int] {
        guard sectionCount > 0 else { return [] }
        let estimatedMarkerCapacity = max(Int(trackHeight / 14), 8)
        let markerCount = min(sectionCount, estimatedMarkerCapacity)
        guard markerCount > 1 else { return [0] }

        return (0..<markerCount).map { step in
            Int((Double(step) / Double(markerCount - 1) * Double(sectionCount - 1)).rounded())
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
    private static let retainedPageRadius = 2
    private static let assetPageLoadThreshold = 30

    @Published var pairedDevices: [PairedDeviceRecord] = []
    @Published var activeUploads: [DashboardActiveUpload] = []
    @Published var allAssets: [BackupAssetRecord] = []
    @Published var visibleAssets: [BackupAssetRecord] = []
    @Published fileprivate var visibleAssetSections: [AssetHistorySection] = []
    @Published fileprivate var scrubberSections: [AssetHistorySection] = []
    @Published var hasMoreVisibleAssets = false
    @Published var isLoadingAssetPage = false
    @Published var selectedDevice: String?
    @Published var backupFolderPath: String?
    @Published var assetSearchQuery = ""
    @Published var assetHistoryViewMode: AssetHistoryViewMode = .list
    @Published var assetHistoryTimeGroupingMode: AssetHistoryTimeGroupingMode = .month {
        didSet {
            rebuildVisibleAssetSections()
            rebuildScrubberSections()
        }
    }
    @Published var assetHistoryMediaFilter: AssetHistoryMediaFilter = .all
    @Published var gridColumnCount: Int = 4

    private var filteredAssets: [BackupAssetRecord] = []
    private var visibleAssetWindowRange: Range<Int> = 0..<0
    private var lastThumbnailBackfillSignature: String?

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
            scrubberSections = []
            hasMoreVisibleAssets = false
            filteredAssets = []
            visibleAssetWindowRange = 0..<0
            lastThumbnailBackfillSignature = nil
            return
        }

        isLoadingAssetPage = true
        defer { isLoadingAssetPage = false }

        if reset {
            filteredAssets = matchingAssetsForSelectedDevice()
            visibleAssetWindowRange = 0..<0
            rebuildScrubberSections()
            scheduleThumbnailBackfillIfNeeded(for: deviceId)
        }

        updateVisibleAssetWindow(anchorIndex: reset ? 0 : visibleAssetWindowRange.lowerBound)
    }

    func loadMoreIfNeeded(currentIndex: Int) async {
        guard !filteredAssets.isEmpty else { return }
        guard !visibleAssetWindowRange.isEmpty else { return }

        let shouldLoadNext = AssetHistoryWindowPlanner.shouldLoadNext(
            currentIndex: currentIndex,
            lastVisibleIndex: visibleAssetWindowRange.upperBound - 1,
            threshold: Self.assetPageLoadThreshold
        )
        let shouldLoadPrevious = AssetHistoryWindowPlanner.shouldLoadPrevious(
            currentIndex: currentIndex,
            firstVisibleIndex: visibleAssetWindowRange.lowerBound,
            threshold: Self.assetPageLoadThreshold
        )

        guard shouldLoadNext || shouldLoadPrevious else { return }
        updateVisibleAssetWindow(anchorIndex: currentIndex)
    }

    func prefetchVisibleAssetNeighborhood(around index: Int, size: CGFloat) async {
        guard !visibleAssets.isEmpty else { return }

        let localIndex = index - visibleAssetWindowRange.lowerBound
        guard visibleAssets.indices.contains(localIndex) else { return }

        let lowerBound = max(0, localIndex - 12)
        let upperBound = min(visibleAssets.count - 1, localIndex + 24)
        let assetsToWarm = Array(visibleAssets[lowerBound...upperBound])
        await AssetHistoryThumbnailPrefetcher.prefetch(assets: assetsToWarm, size: size)
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
        visibleAssetSections = Self.buildSections(
            from: visibleAssets,
            mode: assetHistoryTimeGroupingMode,
            baseIndex: visibleAssetWindowRange.lowerBound
        )
    }

    private func rebuildScrubberSections() {
        scrubberSections = Self.buildSections(
            from: filteredAssets,
            mode: assetHistoryTimeGroupingMode,
            baseIndex: 0
        )
    }

    private func scheduleThumbnailBackfillIfNeeded(for deviceId: String) {
        let trimmedQuery = assetSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = "\(deviceId)|\(assetHistoryMediaFilter.rawValue)|\(trimmedQuery)"
        guard signature != lastThumbnailBackfillSignature else { return }

        lastThumbnailBackfillSignature = signature
        let assetsToBackfill = filteredAssets
        Task.detached(priority: .utility) {
            await AssetHistoryThumbnailPrefetcher.backfill(assets: assetsToBackfill)
        }
    }

    private func matchingAssetsForSelectedDevice() -> [BackupAssetRecord] {
        guard let deviceId = selectedDevice else { return [] }

        return allAssets.filter { asset in
            guard asset.deviceId == deviceId else { return false }

            if let mediaType = assetHistoryMediaFilter.databaseValue,
               asset.mediaType.caseInsensitiveCompare(mediaType) != .orderedSame {
                return false
            }

            let trimmedQuery = assetSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedQuery.isEmpty,
               asset.originalFilename.range(of: trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
                return false
            }

            return true
        }
        .sorted { lhs, rhs in
            if lhs.creationDate == rhs.creationDate {
                return lhs.backupId > rhs.backupId
            }
            return lhs.creationDate > rhs.creationDate
        }
    }

    func ensureSectionVisible(_ sectionID: String) async {
        guard let targetSection = scrubberSections.first(where: { $0.id == sectionID }),
              let targetIndex = targetSection.entries.first?.index else {
            return
        }

        updateVisibleAssetWindow(anchorIndex: targetIndex)
    }

    private func updateVisibleAssetWindow(anchorIndex: Int) {
        guard !filteredAssets.isEmpty else {
            visibleAssetWindowRange = 0..<0
            visibleAssets = []
            visibleAssetSections = []
            hasMoreVisibleAssets = false
            return
        }

        let lastPage = max(0, (filteredAssets.count - 1) / Self.assetPageSize)
        let clampedAnchor = min(max(0, anchorIndex), filteredAssets.count - 1)
        let anchorPage = clampedAnchor / Self.assetPageSize
        let pageRange = AssetHistoryWindowPlanner.pageRange(
            centeringOn: anchorPage,
            lastPage: lastPage,
            radius: Self.retainedPageRadius
        )
        let lowerBound = pageRange.lowerBound * Self.assetPageSize
        let upperBound = min(filteredAssets.count, (pageRange.upperBound + 1) * Self.assetPageSize)
        let nextRange = lowerBound..<upperBound

        guard nextRange != visibleAssetWindowRange else {
            hasMoreVisibleAssets = upperBound < filteredAssets.count
            return
        }

        visibleAssetWindowRange = nextRange
        visibleAssets = Array(filteredAssets[nextRange])
        rebuildVisibleAssetSections()
        hasMoreVisibleAssets = upperBound < filteredAssets.count
    }

    private static func buildSections(
        from assets: [BackupAssetRecord],
        mode: AssetHistoryTimeGroupingMode,
        baseIndex: Int
    ) -> [AssetHistorySection] {
        guard !assets.isEmpty else { return [] }

        var sections: [AssetHistorySection] = []
        sections.reserveCapacity(max(1, assets.count / 16))

        for (index, asset) in assets.enumerated() {
            let key = sectionKey(for: asset, mode: mode)
            let entry = AssetHistoryEntry(index: baseIndex + index, asset: asset)

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
        ) {
            await MainActor.run {
                if image == nil {
                    image = NSImage(data: thumbnailData)
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
            guard let croppedImage = squareCroppedImage(from: thumbnail.nsImage, size: size) else {
                return nil
            }
            return jpegData(from: croppedImage)
        } catch {
            return nil
        }
    }

    private static func loadDirectThumbnail(fileURL: URL, mediaType: String, size: CGFloat) -> CGImage? {
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

    private static func squareCroppedImage(from nsImage: NSImage, size: CGFloat) -> CGImage? {
        var proposedRect = CGRect(origin: .zero, size: nsImage.size)
        guard let cgImage = nsImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }
        return squareCroppedImage(from: cgImage, size: size)
    }

    private static func squareCroppedImage(from cgImage: CGImage, size: CGFloat) -> CGImage {
        let sideLength = min(cgImage.width, cgImage.height)
        let cropRect = CGRect(
            x: (cgImage.width - sideLength) / 2,
            y: (cgImage.height - sideLength) / 2,
            width: sideLength,
            height: sideLength
        )
        let croppedImage = cgImage.cropping(to: cropRect) ?? cgImage
        return resizedRGBImage(from: croppedImage, size: Int(size * 2)) ?? croppedImage
    }

    private static func resizedRGBImage(from cgImage: CGImage, size: Int) -> CGImage? {
        let clampedSize = max(size, 1)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpace(name: CGColorSpace.displayP3) else {
            return nil
        }

        guard let context = CGContext(
            data: nil,
            width: clampedSize,
            height: clampedSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: clampedSize, height: clampedSize))
        return context.makeImage()
    }

    private static func jpegData(from cgImage: CGImage) -> Data? {
        let outputImage = resizedRGBImage(from: cgImage, size: cgImage.width) ?? cgImage
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.82
        ]
        CGImageDestinationAddImage(destination, outputImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }
}

actor AssetHistoryThumbnailCache {
    static let shared = AssetHistoryThumbnailCache()

    private static let cacheVersion = "v2"

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
        let rawKey = "\(Self.cacheVersion)|\(fileURL.path)|\(Int(size.rounded()))|\(modificationDate)"
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

actor AssetHistoryThumbnailPrefetchCoordinator {
    static let shared = AssetHistoryThumbnailPrefetchCoordinator()

    private struct Request: Hashable {
        let path: String
        let mediaType: String
        let size: Int
    }

    private let maxConcurrentPrefetches = 2
    private var queuedRequests: [Request] = []
    private var queuedRequestSet: Set<Request> = []
    private var activeWorkerCount = 0

    func enqueue(relativePath: String, mediaType: String, sizes: [CGFloat]) async {
        guard let fileURL = await AssetHistoryThumbnailPrefetcher.resolvedFileURL(for: relativePath) else { return }
        enqueue(fileURL: fileURL, mediaType: mediaType, sizes: sizes)
    }

    func enqueue(assets: [BackupAssetRecord], sizes: [CGFloat]) async {
        guard !assets.isEmpty else { return }

        let backupFolder = await MainActor.run { AppCoordinator.shared.backupFolder }
        var requests: [Request] = []
        requests.reserveCapacity(assets.count * sizes.count)

        for asset in assets {
            guard let resolvedPath = AssetHistoryThumbnailPrefetcher.resolvedPath(
                for: asset.finalPath,
                backupFolder: backupFolder
            ) else {
                continue
            }

            for size in sizes {
                requests.append(
                    Request(
                        path: resolvedPath,
                        mediaType: asset.mediaType,
                        size: max(Int(size.rounded()), 1)
                    )
                )
            }
        }

        enqueue(requests)
    }

    private func enqueue(fileURL: URL, mediaType: String, sizes: [CGFloat]) {
        let requests = sizes.map {
            Request(
                path: fileURL.path,
                mediaType: mediaType,
                size: max(Int($0.rounded()), 1)
            )
        }
        enqueue(requests)
    }

    private func enqueue(_ requests: [Request]) {
        guard !requests.isEmpty else { return }

        for request in requests where !queuedRequestSet.contains(request) {
            queuedRequests.append(request)
            queuedRequestSet.insert(request)
        }

        spawnWorkersIfNeeded()
    }

    private func spawnWorkersIfNeeded() {
        while activeWorkerCount < maxConcurrentPrefetches && !queuedRequests.isEmpty {
            activeWorkerCount += 1
            Task.detached(priority: .utility) {
                await self.workerLoop()
            }
        }
    }

    private func workerLoop() async {
        while let request = dequeueNextRequest() {
            await AssetHistoryThumbnailPrefetcher.prefetch(
                fileURL: URL(fileURLWithPath: request.path),
                mediaType: request.mediaType,
                size: CGFloat(request.size)
            )
        }
    }

    private func dequeueNextRequest() -> Request? {
        guard !queuedRequests.isEmpty else {
            activeWorkerCount = max(0, activeWorkerCount - 1)
            return nil
        }

        let request = queuedRequests.removeFirst()
        queuedRequestSet.remove(request)
        return request
    }
}

enum AssetHistoryThumbnailPrefetcher {
    static let committedAssetSizes: [CGFloat] = [48, 96, 160, 240]
    static let backgroundBackfillSizes: [CGFloat] = [48, 160, 240]

    static func prewarmCommittedAsset(relativePath: String, mediaType: String) async {
        await AssetHistoryThumbnailPrefetchCoordinator.shared.enqueue(
            relativePath: relativePath,
            mediaType: mediaType,
            sizes: committedAssetSizes
        )
    }

    static func backfill(assets: [BackupAssetRecord]) async {
        await AssetHistoryThumbnailPrefetchCoordinator.shared.enqueue(
            assets: assets,
            sizes: backgroundBackfillSizes
        )
    }

    static func prefetch(assets: [BackupAssetRecord], size: CGFloat) async {
        await AssetHistoryThumbnailPrefetchCoordinator.shared.enqueue(
            assets: assets,
            sizes: [size]
        )
    }

    static func prefetch(asset: BackupAssetRecord, size: CGFloat) async {
        await prefetch(assets: [asset], size: size)
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

    static func resolvedFileURL(for path: String) async -> URL? {
        let resolvedPath: String
        if (path as NSString).isAbsolutePath {
            resolvedPath = path
        } else {
            let backupFolder = await MainActor.run { AppCoordinator.shared.backupFolder }
            resolvedPath = backupFolder.appendingPathComponent(path).path
        }

        guard !resolvedPath.isEmpty else { return nil }
        let fileURL = URL(fileURLWithPath: resolvedPath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return fileURL
    }

    static func resolvedPath(for path: String, backupFolder: URL) -> String? {
        let resolvedPath: String
        if (path as NSString).isAbsolutePath {
            resolvedPath = path
        } else {
            resolvedPath = backupFolder.appendingPathComponent(path).path
        }

        guard !resolvedPath.isEmpty else { return nil }
        guard FileManager.default.fileExists(atPath: resolvedPath) else { return nil }
        return resolvedPath
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

struct AssetHistoryWindowPlanner {
    static func pageRange(centeringOn currentPage: Int, lastPage: Int, radius: Int) -> ClosedRange<Int> {
        guard lastPage > 0 else { return 0...0 }

        let clampedPage = min(max(0, currentPage), lastPage)
        let maxWindowPageCount = max(1, radius * 2 + 1)
        let earliestLowerBound = max(0, lastPage - (maxWindowPageCount - 1))
        let lowerBound = min(max(0, clampedPage - radius), earliestLowerBound)
        let upperBound = min(lastPage, lowerBound + maxWindowPageCount - 1)
        return lowerBound...upperBound
    }

    static func shouldLoadNext(currentIndex: Int, lastVisibleIndex: Int, threshold: Int) -> Bool {
        currentIndex >= (lastVisibleIndex - threshold)
    }

    static func shouldLoadPrevious(currentIndex: Int, firstVisibleIndex: Int, threshold: Int) -> Bool {
        currentIndex <= (firstVisibleIndex + threshold)
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
