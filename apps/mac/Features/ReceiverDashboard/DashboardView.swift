import SwiftUI
import AppKit
import QuickLook
import QuickLookThumbnailing
import AVFoundation
import AVKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
import Darwin
import CoreLocation
import MapKit
import ICherriDesignSystem
import ICherriProtocol
import Inject
import Factory

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
    @State private var selectedDetailAsset: BackupAssetRecord? = nil
    @State private var magnificationScale: CGFloat = 1.0
    @State private var isPinching = false
    @State private var detailScale: CGFloat = 1.0
    @State private var detailOffset: CGSize = .zero
    @State private var detailLastOffset: CGSize = .zero
    @State private var detailShowInfo = false
    @State private var detailGPSLocation: String? = nil
    @State private var detailCoordinate: CLLocationCoordinate2D? = nil
    @State private var isLivePhotoVideoHovering = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .navigationTitle(selectedDetailAsset == nil ? "iCherri Receiver" : "")
        .enableInjection()
        .toolbar { toolbarContent }
        .task {
            await viewModel.load()
            viewModel.startObservation()
        }
        .onDisappear {
            viewModel.stopObservation()
        }
        .onChange(of: viewModel.selectedDevice) { _, _ in
            Task { await viewModel.loadSelectedDeviceAssets(reset: true) }
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
        ZStack {
            // Always keep the browser mounted to preserve scroll position
            if let device = viewModel.selectedDeviceInfo {
                deviceDetailView(device)
            } else {
                placeholderView
            }

            // Detail viewer overlays within the detail pane (toolbar stays native)
            if let asset = selectedDetailAsset {
                AssetHistoryDetailViewer(
                    asset: asset,
                    gpsLocation: $detailGPSLocation,
                    gpsCoordinate: $detailCoordinate,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedDetailAsset = nil
                            detailGPSLocation = nil
                            detailCoordinate = nil
                        }
                    }
                )
                .transition(.opacity)
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
            historyBrowser
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func deviceHeader(_ device: PairedDeviceRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
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
                
                // 1) Search bar pushed up
                historySearchBar
                    .frame(width: 220)
                
                // 2) media filters (All, Photos, Videos) in place of paired badge
                historyMediaFilterBar
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
            .padding(.vertical, 6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .onChange(of: viewModel.assetSearchQuery) { _, _ in
            Task { await viewModel.loadSelectedDeviceAssets(reset: true) }
        }
    }

    private var historyMediaFilterBar: some View {
        HStack(spacing: 6) {
            ForEach(AssetHistoryMediaFilter.allCases) { filter in
                mediaFilterChip(filter)
            }
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
        let baseGridItemSize = (contentWidth - CGFloat(max(columnCount - 1, 0)) * 8) / CGFloat(columnCount)
        let gridItemSize = baseGridItemSize * magnificationScale

        return ScrollViewReader { scrollProxy in
            ZStack(alignment: .bottom) {
                if viewModel.assetHistoryViewMode == .grid {
                    ZStack(alignment: .bottom) {
                        AssetHistoryCollectionView(
                            sections: viewModel.visibleAssetSections,
                            gridItemSize: gridItemSize,
                            onPreview: { asset in previewAsset(asset) },
                            onOpen: { asset in openAsset(asset) },
                            onReveal: { asset in revealAsset(asset) },
                            onLoadMore: { index in
                                Task { await viewModel.loadMoreIfNeeded(currentIndex: index) }
                            },
                            isPinching: isPinching,
                            viewModel: viewModel
                        )
                        .gesture(historyGridMagnificationGesture)

                        if viewModel.isLoadingAssetPage {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 110)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8, pinnedViews: [.sectionHeaders]) {
                            ForEach(viewModel.visibleAssetSections, id: \.id) { section in
                                Section(header: sectionHeaderView(section.title)) {
                                    ForEach(section.entries) { entry in
                                        assetHistoryListItem(entry.asset, index: entry.index)
                                    }
                                }
                                .id(section.id)
                            }
                        }

                        historyPaginationFooter
                            .padding(.vertical, 16)
                            .padding(.bottom, 96)
                    }
                    .scrollContentBackground(.hidden)
                }

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

    private func sectionHeaderView(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
            Spacer()
        }
        .padding(.horizontal, 4)
        .background(Color(NSColor.windowBackgroundColor))
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
                isPinching = true
                let start = gridPinchStartColumns ?? viewModel.gridColumnCount
                if gridPinchStartColumns == nil {
                    gridPinchStartColumns = start
                }
                magnificationScale = max(0.5, min(value, 2.0))
            }
            .onEnded { value in
                guard viewModel.assetHistoryViewMode == .grid else { return }
                isPinching = false
                let start = gridPinchStartColumns ?? viewModel.gridColumnCount
                let proposed = proposedGridColumnCount(start: start, magnificationValue: value) ?? start
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    viewModel.gridColumnCount = proposed
                    magnificationScale = 1.0
                }
                gridPinchStartColumns = nil
            }
    }

    private func proposedGridColumnCount(start: Int, magnificationValue: CGFloat) -> Int? {
        let safeValue = Double(magnificationValue)
        guard safeValue.isFinite, safeValue > 0 else { return nil }

        let proposed = Double(start) / safeValue
        guard proposed.isFinite, !proposed.isNaN else { return nil }

        return min(max(Int(proposed.rounded()), 2), 8)
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
            await MainActor.run {
                if viewModel.assetHistoryViewMode == .grid {
                    viewModel.scrollToSectionID = targetSectionID
                }
            }

            await viewModel.ensureSectionVisible(targetSectionID)
            guard !Task.isCancelled else { return }

            if viewModel.assetHistoryViewMode != .grid {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.12)) {
                        scrollProxy.scrollTo(targetSectionID, anchor: .top)
                    }
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
            if let asset = selectedDetailAsset {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedDetailAsset = nil
                        }
                    }) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(asset.originalFilename)
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(asset.creationDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let gps = detailGPSLocation {
                                Text("•").font(.caption).foregroundStyle(.secondary)
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(gps)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
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
    }

    // MARK: - Helpers

    private func deviceRow(_ device: PairedDeviceRecord) -> some View {
        let isOnline = Date().timeIntervalSince(device.lastSeenAt) < 30.0
        return HStack {
            Image(systemName: "iphone")
                .foregroundStyle(isOnline ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.deviceName)
                        .font(.subheadline)
                    Circle()
                        .fill(isOnline ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                }
                Text(isOnline ? "Online" : "Offline")
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
                .id(asset.backupId)

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
                    if asset.mediaType.lowercased() == "video" {
                        if let duration = asset.durationSeconds, duration > 0 {
                            let minutes = Int(duration) / 60
                            let seconds = Int(duration) % 60
                            let durationStr = String(format: "%d:%02d", minutes, seconds)
                            Label("Video (\(durationStr))", systemImage: "video")
                        } else {
                            Label("Video", systemImage: "video")
                        }
                    } else {
                        Label(asset.mediaType.capitalized, systemImage: "photo")
                    }
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

    private func assetIconName(_ mediaType: String) -> String {
        switch mediaType.lowercased() {
        case "video":
            return "video.fill"
        default:
            return "photo.fill"
        }
    }

    private func historySummary(for device: PairedDeviceRecord) -> String {
        if let coverageSummary = viewModel.latestCoverageSummary(for: device.deviceId) {
            return "\(coverageSummary.completedAssetCount.formatted()) / \(coverageSummary.totalAssetCount.formatted()) in library • \(coverageSummary.pendingAssetCount.formatted()) pending"
        }
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
        guard assetFileURL(asset) != nil else {
            assetActionError = missingFileMessage(for: asset)
            return
        }
        selectedDetailAsset = asset
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
                onOpen()
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

    @Injected(\.databaseManager) private var databaseManager
    @Injected(\.appCoordinator) private var appCoordinator

    private var observationTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    @Published var pairedDevices: [PairedDeviceRecord] = []
    @Published var activeUploads: [DashboardActiveUpload] = []
    @Published var deviceStats: [String: DatabaseManager.DeviceBackupStats] = [:]
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
    @Published var scrollToSectionID: String? = nil

    private var filteredAssets: [BackupAssetRecord] = []
    private var visibleAssetWindowRange: Range<Int> = 0..<0
    private var lastThumbnailBackfillSignature: String?
    private var latestCoverageSummariesByDevice: [String: BackupRunCoverageSummary] = [:]

    var selectedDeviceInfo: PairedDeviceRecord? {
        pairedDevices.first { $0.deviceId == selectedDevice }
    }

    func refreshDeviceStatus() async {
        do {
            let devices = try await databaseManager.fetchAllDevices()
            self.pairedDevices = devices
        } catch {
            print("Failed to refresh device status: \(error)")
        }
    }

    func load() async {
        do {
            let previousSelection = selectedDevice
            self.backupFolderPath = appCoordinator.backupFolder.path
            
            let devices = try await databaseManager.fetchAllDevices()
            let stats = try await databaseManager.fetchBackupStatsByDevice()
            let sessions = try await databaseManager.fetchAllSessions()
            let coverageSummaries = try await databaseManager.fetchLatestBackupCoverageSummaries()
            
            self.pairedDevices = devices
            self.deviceStats = stats
            self.latestCoverageSummariesByDevice = Dictionary(
                uniqueKeysWithValues: coverageSummaries.map { ($0.deviceId, $0) }
            )
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

            let hasChangedDevice = previousSelection != selectedDevice
            await loadSelectedDeviceAssets(reset: hasChangedDevice)
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
            filteredAssets = await matchingAssetsForSelectedDevice()
            visibleAssetWindowRange = 0..<0
            rebuildScrubberSections()
            scheduleThumbnailBackfillIfNeeded(for: deviceId)
            updateVisibleAssetWindow(anchorIndex: 0)
        } else {
            filteredAssets = await matchingAssetsForSelectedDevice()
            rebuildScrubberSections()

            // Preserve the currently loaded range of assets
            let currentRange = visibleAssetWindowRange
            let clampedUpperBound = min(filteredAssets.count, currentRange.upperBound)
            let newRange = 0..<clampedUpperBound
            visibleAssetWindowRange = newRange
            visibleAssets = Array(filteredAssets[newRange])
            rebuildVisibleAssetSections()
            hasMoreVisibleAssets = clampedUpperBound < filteredAssets.count
        }
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
        []
    }

    func assetCount(for deviceId: String) -> Int {
        deviceStats[deviceId]?.completedCount ?? 0
    }

    func duplicateCount(for deviceId: String) -> Int {
        deviceStats[deviceId]?.duplicateCount ?? 0
    }

    func failedCount(for deviceId: String) -> Int {
        deviceStats[deviceId]?.failedCount ?? 0
    }

    func lastBackupDate(for deviceId: String) -> Date? {
        deviceStats[deviceId]?.lastBackupDate
    }

    func latestCoverageSummary(for deviceId: String) -> BackupRunCoverageSummary? {
        latestCoverageSummariesByDevice[deviceId]
    }

    func selectBackupFolder() {
        appCoordinator.selectBackupFolder()
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
        let workloadProfile = AssetHistoryThumbnailWorkloadProfile.current()
        guard workloadProfile.allowsBackgroundBackfill else {
            lastThumbnailBackfillSignature = nil
            return
        }

        let trimmedQuery = assetSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = "\(deviceId)|\(assetHistoryMediaFilter.rawValue)|\(trimmedQuery)"
        guard signature != lastThumbnailBackfillSignature else { return }

        lastThumbnailBackfillSignature = signature
        let assetsToBackfill = filteredAssets
        Task.detached(priority: .utility) {
            await AssetHistoryThumbnailPrefetcher.backfill(assets: assetsToBackfill)
        }
    }

    private func matchingAssetsForSelectedDevice() async -> [BackupAssetRecord] {
        guard let deviceId = selectedDevice else { return [] }

        do {
            return try await databaseManager.fetchAssets(
                deviceId: deviceId,
                searchQuery: assetSearchQuery,
                status: nil, // fetch all statuses (completed, duplicate, failed)
                mediaType: assetHistoryMediaFilter.databaseValue,
                limit: 100000, // a high limit to get all matching assets for the scrubber
                offset: 0
            )
        } catch {
            print("Failed to fetch matching assets: \(error)")
            return []
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
        let lowerBound = 0
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

        // Prefetch thumbnails only for the neighborhood around the anchorIndex (80 items)
        let lowerBoundPrefetch = max(0, anchorIndex - 20)
        let upperBoundPrefetch = min(filteredAssets.count - 1, anchorIndex + 60)
        let assetsToWarm = Array(filteredAssets[lowerBoundPrefetch...upperBoundPrefetch])
        let columns = gridColumnCount
        let width: CGFloat = 800
        let itemSize = columns > 0 ? (width / CGFloat(columns)) : 48
        Task {
            await AssetHistoryThumbnailPrefetcher.prefetch(assets: assetsToWarm, size: itemSize)
        }
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
            let tempPaths = try await databaseManager.deletePairedDevice(deviceId: device.deviceId)
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
            print("Failed to delete device: \(error)")
        }
    }

    func startObservation() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            
            let folderChangeStream = NotificationCenter.default.notifications(named: .changeBackupFolder)
            let dataChangeStream = NotificationCenter.default.notifications(named: .receiverDataDidChange)
            
            Task { [weak self] in
                for await _ in folderChangeStream {
                    await self?.selectBackupFolder()
                }
            }
            
            Task { [weak self] in
                for await _ in dataChangeStream {
                    await self?.load()
                }
            }
        }
        
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    await self?.refreshDeviceStatus()
                } catch {
                    break
                }
            }
        }
    }

    func stopObservation() {
        observationTask?.cancel()
        observationTask = nil
        timerTask?.cancel()
        timerTask = nil
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
        _loader = StateObject(wrappedValue: AssetHistoryThumbnailLoader(
            path: resolvedPath,
            relativePath: asset.finalPath,
            mediaType: asset.mediaType,
            size: size
        ))
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
                    .font(.system(size: size < 60 ? 8 : 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, size < 60 ? 3 : 6)
                    .padding(.vertical, size < 60 ? 1.5 : 3)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .padding(size < 60 ? 2 : 6)
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

extension Notification.Name {
    static let thumbnailDidCache = Notification.Name("thumbnailDidCache")
}

@MainActor
private final class AssetHistoryThumbnailLoader: ObservableObject {
    @Published var image: NSImage?

    private let path: String
    private let relativePath: String
    private let mediaType: String
    private let size: CGFloat
    private var hasLoaded = false
    private var notificationObserver: AnyObject?

    init(path: String, relativePath: String, mediaType: String, size: CGFloat) {
        self.path = path
        self.relativePath = relativePath
        self.mediaType = mediaType
        self.size = size
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard !path.isEmpty else { return }

        let backupFolder = AppCoordinator.shared.backupFolder
        let fileURL = backupFolder.appendingPathComponent(relativePath)
        let displayScale = NSScreen.main?.backingScaleFactor ?? 2

        if let nsImage = await AssetHistoryThumbnailCache.shared.thumbnailImage(
            for: fileURL,
            mediaType: mediaType,
            size: size,
            scale: displayScale,
            generateIfAbsent: false
        ) {
            self.image = nsImage
        } else {
            setupNotificationObserver()

            let relativePath = self.relativePath
            let mediaType = self.mediaType
            let size = self.size
            Task {
                await AssetHistoryThumbnailPrefetchCoordinator.shared.enqueue(
                    relativePath: relativePath,
                    mediaType: mediaType,
                    workload: .neighborhoodPrefetch,
                    sizes: [size]
                )
            }
        }
    }

    private func setupNotificationObserver() {
        guard notificationObserver == nil else { return }

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .thumbnailDidCache,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let path = notification.userInfo?["path"] as? String,
                  let size = notification.userInfo?["size"] as? CGFloat else { return }

            if path == self.path && abs(size - self.size) < 1.0 {
                if let observer = self.notificationObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self.notificationObserver = nil
                }

                self.hasLoaded = false
                Task {
                    await self.loadIfNeeded()
                }
            }
        }
    }

    static func generateThumbnailData(fileURL: URL, mediaType: String, size: CGFloat, scale: CGFloat) async -> Data? {
        NSLog("iCherri-Thumbnail: generateThumbnailData START for \(fileURL.lastPathComponent) size \(size)")
        let backupFolder = await MainActor.run { AppCoordinator.shared.backupFolder }
        let access = backupFolder.startAccessingSecurityScopedResource()
        defer {
            if access {
                backupFolder.stopAccessingSecurityScopedResource()
            }
        }

        let reachable = (try? fileURL.checkResourceIsReachable()) == true
        NSLog("iCherri-Thumbnail: checkResourceIsReachable for \(fileURL.lastPathComponent): \(reachable)")
        guard reachable else {
            NSLog("iCherri-Thumbnail: File NOT reachable: \(fileURL.path)")
            return nil
        }

        if let directImage = loadDirectThumbnail(fileURL: fileURL, mediaType: mediaType, size: size) {
            NSLog("iCherri-Thumbnail: loadDirectThumbnail SUCCESS for \(fileURL.lastPathComponent)")
            return jpegData(from: directImage)
        }

        NSLog("iCherri-Thumbnail: loadDirectThumbnail returned nil, falling back to QLThumbnailGenerator for \(fileURL.lastPathComponent)")
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: size * 2, height: size * 2),
            scale: scale,
            representationTypes: .all
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            guard let croppedImage = squareCroppedImage(from: thumbnail.nsImage, size: size) else {
                NSLog("iCherri-Thumbnail: QL squareCroppedImage returned nil for \(fileURL.lastPathComponent)")
                return nil
            }
            NSLog("iCherri-Thumbnail: QL SUCCESS for \(fileURL.lastPathComponent)")
            return jpegData(from: croppedImage)
        } catch {
            NSLog("iCherri-Thumbnail: QL FAILURE for \(fileURL.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private static func loadDirectThumbnail(fileURL: URL, mediaType: String, size: CGFloat) -> CGImage? {
        if mediaType.lowercased() == "video" {
            // Let QLThumbnailGenerator handle videos asynchronously out-of-process.
            return nil
        }

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        
        // 1. Try to load using ONLY the embedded EXIF thumbnail (fast path!)
        let fastOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: false,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(size * 2)
        ]
        
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, fastOptions as CFDictionary) {
            return squareCroppedImage(from: cgImage, size: size)
        }
        
        // 2. Fallback to full image decode if no embedded thumbnail is present (slow path)
        let slowOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(size * 2)
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, slowOptions as CFDictionary) else {
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

private enum AssetHistoryThumbnailWorkloadKind {
    case committedPrewarm
    case backgroundBackfill
    case neighborhoodPrefetch
}

private struct AssetHistoryThumbnailWorkloadProfile {
    let allowsBackgroundBackfill: Bool
    let maxConcurrentPhotoPrefetches: Int
    let maxConcurrentVideoPrefetches: Int
    let maxVideoPixelSize: CGFloat
    let committedPhotoSizes: [CGFloat]
    let committedVideoSizes: [CGFloat]
    let backfillPhotoSizes: [CGFloat]
    let backfillVideoSizes: [CGFloat]

    static func current() -> AssetHistoryThumbnailWorkloadProfile {
        let processInfo = ProcessInfo.processInfo
        let lowSpecHardware = !HardwareCapabilities.isAppleSilicon
        let constrainedPower = processInfo.isLowPowerModeEnabled
        let constrainedThermals = processInfo.thermalState == .serious || processInfo.thermalState == .critical

        if lowSpecHardware || constrainedPower || constrainedThermals {
            return AssetHistoryThumbnailWorkloadProfile(
                allowsBackgroundBackfill: false,
                maxConcurrentPhotoPrefetches: 4,
                maxConcurrentVideoPrefetches: 2,
                maxVideoPixelSize: 96,
                committedPhotoSizes: [48, 96, 160],
                committedVideoSizes: [48, 96],
                backfillPhotoSizes: [48, 96],
                backfillVideoSizes: []
            )
        }

        return AssetHistoryThumbnailWorkloadProfile(
            allowsBackgroundBackfill: true,
            maxConcurrentPhotoPrefetches: 12,
            maxConcurrentVideoPrefetches: 4,
            maxVideoPixelSize: 160,
            committedPhotoSizes: [48, 96, 160, 240],
            committedVideoSizes: [48, 96, 160],
            backfillPhotoSizes: [48, 160, 240],
            backfillVideoSizes: [48, 96]
        )
    }

    func sizes(for mediaType: String, workload: AssetHistoryThumbnailWorkloadKind, requestedSizes: [CGFloat]) -> [CGFloat] {
        let normalizedMediaType = mediaType.lowercased()

        if normalizedMediaType == "video" {
            let configuredSizes: [CGFloat]
            switch workload {
            case .committedPrewarm:
                configuredSizes = committedVideoSizes
            case .backgroundBackfill:
                configuredSizes = backfillVideoSizes
            case .neighborhoodPrefetch:
                configuredSizes = requestedSizes.map { min($0, maxVideoPixelSize) }
            }

            return normalizedSizes(configuredSizes)
        }

        let configuredSizes: [CGFloat]
        switch workload {
        case .committedPrewarm:
            configuredSizes = committedPhotoSizes
        case .backgroundBackfill:
            configuredSizes = backfillPhotoSizes
        case .neighborhoodPrefetch:
            configuredSizes = requestedSizes
        }

        return normalizedSizes(configuredSizes)
    }

    private func normalizedSizes(_ sizes: [CGFloat]) -> [CGFloat] {
        var seen = Set<Int>()
        return sizes.compactMap { size in
            let rounded = max(Int(size.rounded()), 1)
            guard seen.insert(rounded).inserted else { return nil }
            return CGFloat(rounded)
        }
    }
}

private enum HardwareCapabilities {
    static let isAppleSilicon: Bool = {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return result == 0 && value == 1
    }()
}

@MainActor
final class AssetHistoryThumbnailCache {
    static let shared = AssetHistoryThumbnailCache()

    private static let cacheVersion = "v2"

    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    private var inFlightTasks: [String: (task: Task<(data: Data, isNew: Bool)?, Never>, generateIfAbsent: Bool, id: UInt64)] = [:]
    private var taskCounter: UInt64 = 0

    init() {
        memoryCache.countLimit = 512
        memoryCache.totalCostLimit = 128 * 1024 * 1024

        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let baseURL = applicationSupportURL.appendingPathComponent("iCherri", isDirectory: true)
        diskCacheURL = baseURL.appendingPathComponent("ThumbnailCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true, attributes: nil)
    }

    func cachedImage(for fileURL: URL, size: CGFloat) -> NSImage? {
        guard let cacheKey = cacheKey(for: fileURL, size: size) else { return nil }
        let nsCacheKey = cacheKey as NSString

        return memoryCache.object(forKey: nsCacheKey)
    }

    func thumbnailImage(
        for fileURL: URL,
        mediaType: String,
        size: CGFloat,
        scale: CGFloat,
        generateIfAbsent: Bool = true
    ) async -> NSImage? {
        guard let cacheKey = cacheKey(for: fileURL, size: size) else { return nil }
        let nsCacheKey = cacheKey as NSString

        if let cached = cachedImage(for: fileURL, size: size) {
            return cached
        }

        if let existing = inFlightTasks[cacheKey] {
            if !generateIfAbsent || existing.generateIfAbsent {
                if let result = await existing.task.value {
                    if let image = NSImage(data: result.data) {
                        memoryCache.setObject(image, forKey: nsCacheKey, cost: estimatedCost(for: size))
                        return image
                    }
                }
                return nil
            }
        }

        let taskId = taskCounter
        taskCounter += 1

        let diskCacheURL = self.diskCacheURL
        let task = Task.detached(priority: .utility) { [diskCacheURL] () -> (data: Data, isNew: Bool)? in
            let cachedFileURL = diskCacheURL.appendingPathComponent(cacheKey).appendingPathExtension("jpg")

            // 1. Try reading from disk cache asynchronously
            if FileManager.default.fileExists(atPath: cachedFileURL.path) {
                if let data = try? Data(contentsOf: cachedFileURL, options: [.mappedIfSafe]) {
                    return (data: data, isNew: false)
                }
            }

            // 2. Generate if requested
            if generateIfAbsent {
                let generatedData = await AssetHistoryThumbnailLoader.generateThumbnailData(
                    fileURL: fileURL,
                    mediaType: mediaType,
                    size: size,
                    scale: scale
                )
                if let generatedData {
                    // Store to disk cache asynchronously
                    try? generatedData.write(to: cachedFileURL, options: .atomic)
                    return (data: generatedData, isNew: true)
                }
            }
            return nil
        }

        inFlightTasks[cacheKey] = (task: task, generateIfAbsent: generateIfAbsent, id: taskId)

        let result = await task.value

        if inFlightTasks[cacheKey]?.id == taskId {
            inFlightTasks[cacheKey] = nil
        }

        if let result, let image = NSImage(data: result.data) {
            memoryCache.setObject(image, forKey: nsCacheKey, cost: estimatedCost(for: size))

            if result.isNew {
                let path = fileURL.path
                NSLog("iCherri-Thumbnail: Posting thumbnailDidCache for \(fileURL.lastPathComponent) size \(size)")
                NotificationCenter.default.post(
                    name: .thumbnailDidCache,
                    object: nil,
                    userInfo: ["path": path, "size": size]
                )
            }
            return image
        }

        return nil
    }

    private func cacheKey(for fileURL: URL, size: CGFloat) -> String? {
        // Backup files are immutable, so path and size are sufficient for the cache key.
        // This avoids blocking fileManager.attributesOfItem disk calls during scrolling.
        let rawKey = "\(Self.cacheVersion)|\(fileURL.path)|\(Int(size.rounded()))"
        let digest = SHA256.hash(data: Data(rawKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func estimatedCost(for size: CGFloat) -> Int {
        Int(size * size * 4)
    }
}

actor AssetHistoryThumbnailPrefetchCoordinator {
    static let shared = AssetHistoryThumbnailPrefetchCoordinator()

    private struct Request: Hashable {
        let relativePath: String
        let mediaType: String
        let size: Int
        let workload: AssetHistoryThumbnailWorkloadKind
    }

    private var queuedRequests: [Request] = []
    private var queuedRequestSet: Set<Request> = []
    private var activePhotoWorkerCount = 0
    private var activeVideoWorkerCount = 0

    fileprivate func enqueue(relativePath: String, mediaType: String, workload: AssetHistoryThumbnailWorkloadKind, sizes: [CGFloat]) async {
        let profile = AssetHistoryThumbnailWorkloadProfile.current()
        let requests = profile.sizes(for: mediaType, workload: workload, requestedSizes: sizes).map {
            Request(
                relativePath: relativePath,
                mediaType: mediaType,
                size: max(Int($0.rounded()), 1),
                workload: workload
            )
        }
        enqueue(requests)
    }

    fileprivate func enqueue(assets: [BackupAssetRecord], workload: AssetHistoryThumbnailWorkloadKind, sizes: [CGFloat]) async {
        guard !assets.isEmpty else { return }

        let profile = AssetHistoryThumbnailWorkloadProfile.current()
        var requests: [Request] = []
        requests.reserveCapacity(assets.count * sizes.count)

        for asset in assets {
            for size in profile.sizes(for: asset.mediaType, workload: workload, requestedSizes: sizes) {
                requests.append(
                    Request(
                        relativePath: asset.finalPath,
                        mediaType: asset.mediaType,
                        size: max(Int(size.rounded()), 1),
                        workload: workload
                    )
                )
            }
        }

        enqueue(requests)
    }

    private func enqueue(_ requests: [Request]) {
        guard !requests.isEmpty else { return }

        for request in requests {
            if let existingIndex = queuedRequests.firstIndex(where: { $0.relativePath == request.relativePath && $0.size == request.size }) {
                let existingRequest = queuedRequests[existingIndex]
                if request.workload != .backgroundBackfill && existingRequest.workload == .backgroundBackfill {
                    queuedRequests.remove(at: existingIndex)
                    queuedRequestSet.remove(existingRequest)
                    queuedRequestSet.insert(request)
                    queuedRequests.insert(request, at: 0)
                }
            } else {
                queuedRequestSet.insert(request)
                if request.workload == .backgroundBackfill {
                    queuedRequests.append(request)
                } else {
                    queuedRequests.insert(request, at: 0)
                }
            }
        }

        spawnWorkersIfNeeded()
    }

    private func spawnWorkersIfNeeded() {
        while let request = reserveNextRequest() {
            Task.detached(priority: .utility) {
                let backupFolder = await MainActor.run { AppCoordinator.shared.backupFolder }
                let fileURL = backupFolder.appendingPathComponent(request.relativePath)

                await AssetHistoryThumbnailPrefetcher.prefetch(
                    fileURL: fileURL,
                    mediaType: request.mediaType,
                    size: CGFloat(request.size)
                )
                await self.complete(request)
            }
        }
    }

    private func reserveNextRequest() -> Request? {
        guard !queuedRequests.isEmpty else { return nil }

        let profile = AssetHistoryThumbnailWorkloadProfile.current()

        for (index, request) in queuedRequests.enumerated() {
            let isVideo = request.mediaType.caseInsensitiveCompare("video") == .orderedSame
            if isVideo {
                guard activeVideoWorkerCount < profile.maxConcurrentVideoPrefetches else { continue }
                activeVideoWorkerCount += 1
            } else {
                guard activePhotoWorkerCount < profile.maxConcurrentPhotoPrefetches else { continue }
                activePhotoWorkerCount += 1
            }

            queuedRequests.remove(at: index)
            queuedRequestSet.remove(request)
            return request
        }

        return nil
    }

    private func complete(_ request: Request) {
        if request.mediaType.caseInsensitiveCompare("video") == .orderedSame {
            activeVideoWorkerCount = max(0, activeVideoWorkerCount - 1)
        } else {
            activePhotoWorkerCount = max(0, activePhotoWorkerCount - 1)
        }

        spawnWorkersIfNeeded()
    }
}

enum AssetHistoryThumbnailPrefetcher {
    static func prewarmCommittedAsset(relativePath: String, mediaType: String) async {
        let profile = AssetHistoryThumbnailWorkloadProfile.current()
        await AssetHistoryThumbnailPrefetchCoordinator.shared.enqueue(
            relativePath: relativePath,
            mediaType: mediaType,
            workload: .committedPrewarm,
            sizes: mediaType.caseInsensitiveCompare("video") == .orderedSame ? profile.committedVideoSizes : profile.committedPhotoSizes
        )
    }

    static func backfill(assets: [BackupAssetRecord]) async {
        let profile = AssetHistoryThumbnailWorkloadProfile.current()
        guard profile.allowsBackgroundBackfill else { return }
        await AssetHistoryThumbnailPrefetchCoordinator.shared.enqueue(
            assets: assets,
            workload: .backgroundBackfill,
            sizes: profile.backfillPhotoSizes + profile.backfillVideoSizes
        )
    }

    static func prefetch(assets: [BackupAssetRecord], size: CGFloat) async {
        await AssetHistoryThumbnailPrefetchCoordinator.shared.enqueue(
            assets: assets,
            workload: .neighborhoodPrefetch,
            sizes: [size]
        )
    }

    static func prefetch(asset: BackupAssetRecord, size: CGFloat) async {
        await prefetch(assets: [asset], size: size)
    }

    static func prefetch(fileURL: URL, mediaType: String, size: CGFloat) async {
        let displayScale = NSScreen.main?.backingScaleFactor ?? 2
        _ = await AssetHistoryThumbnailCache.shared.thumbnailImage(
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

private struct AssetHistorySection: Identifiable, Equatable {
    let id: String
    let title: String
    var entries: [AssetHistoryEntry]

    static func == (lhs: AssetHistorySection, rhs: AssetHistorySection) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.entries.map(\.id) == rhs.entries.map(\.id)
    }
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

// MARK: - AppKit Collection View Wrapper
fileprivate struct AssetHistoryCollectionView: NSViewRepresentable {
    fileprivate let sections: [AssetHistorySection]
    let gridItemSize: CGFloat
    let onPreview: (BackupAssetRecord) -> Void
    let onOpen: (BackupAssetRecord) -> Void
    let onReveal: (BackupAssetRecord) -> Void
    let onLoadMore: (Int) -> Void
    let isPinching: Bool
    @ObservedObject var viewModel: DashboardViewModel

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let layout = NSCollectionViewFlowLayout()
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionHeadersPinToVisibleBounds = true

        let collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator

        // Register custom item and header
        collectionView.register(
            AssetHistoryCollectionViewItem.self,
            forItemWithIdentifier: NSUserInterfaceItemIdentifier("AssetItem")
        )
        collectionView.register(
            AssetHistoryCollectionViewHeader.self,
            forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: NSUserInterfaceItemIdentifier("SectionHeader")
        )

        scrollView.documentView = collectionView
        context.coordinator.collectionView = collectionView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.update(
            sections: sections,
            gridItemSize: gridItemSize,
            onPreview: onPreview,
            onOpen: onOpen,
            onReveal: onReveal,
            onLoadMore: onLoadMore,
            isJumpingToSection: viewModel.scrollToSectionID != nil,
            isPinching: isPinching
        )

        if let targetID = viewModel.scrollToSectionID {
            context.coordinator.scrollToSection(id: targetID)
            DispatchQueue.main.async {
                viewModel.scrollToSectionID = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout {
        fileprivate var sections: [AssetHistorySection] = []
        var gridItemSize: CGFloat = 180
        var onPreview: ((BackupAssetRecord) -> Void)?
        var onOpen: ((BackupAssetRecord) -> Void)?
        var onReveal: ((BackupAssetRecord) -> Void)?
        var onLoadMore: ((Int) -> Void)?
        weak var collectionView: NSCollectionView?
        
        private var lockedAnchorIndexPath: IndexPath?
        private var anchorResetWorkItem: DispatchWorkItem?

        fileprivate func update(
            sections: [AssetHistorySection],
            gridItemSize: CGFloat,
            onPreview: @escaping (BackupAssetRecord) -> Void,
            onOpen: @escaping (BackupAssetRecord) -> Void,
            onReveal: @escaping (BackupAssetRecord) -> Void,
            onLoadMore: @escaping (Int) -> Void,
            isJumpingToSection: Bool,
            isPinching: Bool
        ) {
            let sectionsChanged = self.sections != sections
            let sizeChanged = self.gridItemSize != gridItemSize

            self.sections = sections
            self.onPreview = onPreview
            self.onOpen = onOpen
            self.onReveal = onReveal
            self.onLoadMore = onLoadMore
            
            if sectionsChanged {
                let isSameDataset = !self.sections.isEmpty && !sections.isEmpty &&
                                    self.sections[0].entries.first?.id == sections[0].entries.first?.id
                let anchorPath = (isSameDataset && !isJumpingToSection) ? collectionView?.indexPathsForVisibleItems().sorted().first : nil

                self.gridItemSize = gridItemSize
                collectionView?.reloadData()

                if let anchorPath = anchorPath,
                   anchorPath.section < sections.count,
                   anchorPath.item < sections[anchorPath.section].entries.count {
                    collectionView?.layoutSubtreeIfNeeded()
                    collectionView?.scrollToItems(at: [anchorPath], scrollPosition: .top)
                }
            } else if sizeChanged {
                self.gridItemSize = gridItemSize
                
                // Track top-most visible item index path before reflow, lock it during continuous resize/pinch
                if lockedAnchorIndexPath == nil {
                    lockedAnchorIndexPath = collectionView?.indexPathsForVisibleItems().sorted().first
                }
                
                if isPinching {
                    collectionView?.collectionViewLayout?.invalidateLayout()
                } else {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.3
                        context.allowsImplicitAnimation = true
                        collectionView?.collectionViewLayout?.invalidateLayout()
                    }
                }
                
                if let anchorPath = lockedAnchorIndexPath {
                    // Force immediate layout reflow so scrollToItems uses correct updated positions
                    collectionView?.layoutSubtreeIfNeeded()
                    collectionView?.scrollToItems(at: [anchorPath], scrollPosition: .top)
                }
                
                // Debounce resetting the locked anchor (e.g. 0.3 seconds after resizing/pinching stops)
                anchorResetWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    self?.lockedAnchorIndexPath = nil
                }
                anchorResetWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
            }
        }

        fileprivate func scrollToSection(id: String) {
            guard let collectionView = collectionView,
                  let sectionIndex = sections.firstIndex(where: { $0.id == id }) else { return }
            
            let itemCount = sections[sectionIndex].entries.count
            guard itemCount > 0 else { return }
            let indexPath = IndexPath(item: 0, section: sectionIndex)
            
            collectionView.layoutSubtreeIfNeeded()
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                collectionView.animator().scrollToItems(at: [indexPath], scrollPosition: .top)
            }
        }

        func numberOfSections(in collectionView: NSCollectionView) -> Int {
            sections.count
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            sections[section].entries.count
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            itemForRepresentedObjectAt indexPath: IndexPath
        ) -> NSCollectionViewItem {
            let item = collectionView.makeItem(
                withIdentifier: NSUserInterfaceItemIdentifier("AssetItem"),
                for: indexPath
            ) as! AssetHistoryCollectionViewItem

            let entry = sections[indexPath.section].entries[indexPath.item]
            
            item.configure(
                asset: entry.asset,
                size: gridItemSize,
                onPreview: onPreview,
                onOpen: onOpen,
                onReveal: onReveal
            )

            // Trigger load more near the bottom
            if let onLoadMore = onLoadMore {
                var absIndex = 0
                for s in 0..<indexPath.section {
                    absIndex += sections[s].entries.count
                }
                absIndex += indexPath.item
                onLoadMore(absIndex)
            }

            return item
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            viewForSupplementaryElementOfKind kind: String,
            at indexPath: IndexPath
        ) -> NSView {
            if kind == NSCollectionView.elementKindSectionHeader {
                let header = collectionView.makeSupplementaryView(
                    ofKind: kind,
                    withIdentifier: NSUserInterfaceItemIdentifier("SectionHeader"),
                    for: indexPath
                ) as! AssetHistoryCollectionViewHeader
                
                let title = sections[indexPath.section].title
                header.configure(title: title)
                return header
            }
            return NSView()
        }

        // Layout delegate
        func collectionView(
            _ collectionView: NSCollectionView,
            layout collectionViewLayout: NSCollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> NSSize {
            NSSize(width: gridItemSize, height: gridItemSize)
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            layout collectionViewLayout: NSCollectionViewLayout,
            referenceSizeForHeaderInSection section: Int
        ) -> NSSize {
            NSSize(width: 0, height: 32)
        }
    }
}

// Custom CollectionView Cell Item
class AssetHistoryCollectionViewItem: NSCollectionViewItem {
    private var hostingView: NSHostingView<AssetHistoryCollectionViewCellWrapper>?
    private var currentAsset: BackupAssetRecord?
    private var imageLoadTask: Task<Void, Never>?

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }

    deinit {
        cleanup()
    }

    private func cleanup() {
        imageLoadTask?.cancel()
        imageLoadTask = nil
    }

    static func bucketedSize(for size: CGFloat) -> CGFloat {
        if size <= 80 {
            return 80
        } else if size <= 160 {
            return 160
        } else if size <= 240 {
            return 240
        } else if size <= 320 {
            return 320
        } else {
            return (size / 80.0).rounded(.up) * 80.0
        }
    }

    func configure(
        asset: BackupAssetRecord,
        size: CGFloat,
        onPreview: ((BackupAssetRecord) -> Void)?,
        onOpen: ((BackupAssetRecord) -> Void)?,
        onReveal: ((BackupAssetRecord) -> Void)?
    ) {
        if currentAsset?.backupId == asset.backupId {
            return
        }

        cleanup()
        self.currentAsset = asset

        // 1. Show placeholder initially
        updateContent(image: nil, size: size, onPreview: onPreview, onOpen: onOpen, onReveal: onReveal)

        // 2. Resolve paths
        let resolvedPath: String
        if (asset.finalPath as NSString).isAbsolutePath {
            resolvedPath = asset.finalPath
        } else {
            resolvedPath = AppCoordinator.shared.backupFolder
                .appendingPathComponent(asset.finalPath)
                .path
        }
        let fileURL = URL(fileURLWithPath: resolvedPath)
        let mediaType = asset.mediaType
        let displayScale = self.view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let bucketed = Self.bucketedSize(for: size)

        // 3. Load/Generate thumbnail immediately in real-time!
        imageLoadTask = Task { @MainActor in
            if let nsImage = await AssetHistoryThumbnailCache.shared.thumbnailImage(
                for: fileURL,
                mediaType: mediaType,
                size: bucketed,
                scale: displayScale,
                generateIfAbsent: true // <-- Generate immediately in background!
            ) {
                guard self.currentAsset?.backupId == asset.backupId else { return }
                self.updateContent(image: nsImage, size: size, onPreview: onPreview, onOpen: onOpen, onReveal: onReveal)
            }
        }
    }

    private func updateContent(
        image: NSImage?,
        size: CGFloat,
        onPreview: ((BackupAssetRecord) -> Void)?,
        onOpen: ((BackupAssetRecord) -> Void)?,
        onReveal: ((BackupAssetRecord) -> Void)?
    ) {
        guard let asset = currentAsset else { return }
        
        let cellView = AssetHistoryCollectionViewCellContent(
            asset: asset,
            image: image,
            size: size
        )
        
        let cellWrapper = AssetHistoryCollectionViewCellWrapper(
            content: cellView,
            asset: asset,
            onPreview: onPreview,
            onOpen: onOpen,
            onReveal: onReveal
        )

        if let hosting = hostingView {
            hosting.rootView = cellWrapper
        } else {
            let hosting = NSHostingView(rootView: cellWrapper)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(hosting)
            
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: self.view.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
            self.hostingView = hosting
        }
    }
}

// Custom CollectionView Section Header
class AssetHistoryCollectionViewHeader: NSView {
    private var hostingView: NSHostingView<AnyView>?

    func configure(title: String) {
        let headerView = HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
            Spacer()
        }
        .padding(.horizontal, 8)
        .background(Color(NSColor.windowBackgroundColor))
        
        let anyView = AnyView(headerView)

        if let hosting = hostingView {
            hosting.rootView = anyView
        } else {
            let hosting = NSHostingView(rootView: anyView)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(hosting)
            
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: self.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            ])
            self.hostingView = hosting
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }
}

// Cell Wrapper View
struct AssetHistoryCollectionViewCellWrapper: View {
    let content: AssetHistoryCollectionViewCellContent
    let asset: BackupAssetRecord
    let onPreview: ((BackupAssetRecord) -> Void)?
    let onOpen: ((BackupAssetRecord) -> Void)?
    let onReveal: ((BackupAssetRecord) -> Void)?

    var body: some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture(count: 2) {
                onOpen?(asset)
            }
            .contextMenu {
                Button("Preview") {
                    onPreview?(asset)
                }
                Button("Open") {
                    onOpen?(asset)
                }
                Button("Reveal in Finder") {
                    onReveal?(asset)
                }
            }
    }
}

struct AssetHistoryCollectionViewCellContent: View {
    let asset: BackupAssetRecord
    let image: NSImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let image = image {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            return .blue
        }
    }

    private var durationLabel: String? {
        guard let duration = asset.durationSeconds, duration > 0 else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

fileprivate struct AssetHistoryDetailViewer: View {
    let asset: BackupAssetRecord
    @Binding var gpsLocation: String?
    @Binding var gpsCoordinate: CLLocationCoordinate2D?
    let onClose: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showInfo = false
    @State private var isLivePhotoVideoHovering = false
    @GestureState private var pinchScale: CGFloat = 1.0

    private var fileURL: URL? {
        guard !asset.finalPath.isEmpty else { return nil }
        if (asset.finalPath as NSString).isAbsolutePath {
            return URL(fileURLWithPath: asset.finalPath)
        } else {
            return AppCoordinator.shared.backupFolder.appendingPathComponent(asset.finalPath)
        }
    }

    private var isVideo: Bool {
        asset.mediaType.lowercased() == "video"
    }

    private var livePhotoVideoURL: URL? {
        guard !isVideo, let fileURL = fileURL else { return nil }
        let videoURL = fileURL.deletingPathExtension().appendingPathExtension("mov")
        if FileManager.default.fileExists(atPath: videoURL.path) {
            return videoURL
        }
        let mp4URL = fileURL.deletingPathExtension().appendingPathExtension("mp4")
        if FileManager.default.fileExists(atPath: mp4URL.path) {
            return mp4URL
        }
        return nil
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background — tap to go back
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onClose()
                    }

                // Content area
                if let fileURL = fileURL {
                    ZStack {
                        if isVideo {
                            NativeVideoPlayerView(url: fileURL, autoPlay: true, showControls: true)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let liveVideoURL = livePhotoVideoURL, isLivePhotoVideoHovering {
                            NativeVideoPlayerView(url: liveVideoURL, autoPlay: true, showControls: false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            if let nsImage = NSImage(contentsOf: fileURL) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .scaleEffect(scale * pinchScale)
                                    .offset(offset)
                                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7), value: pinchScale)
                                    .gesture(
                                        MagnificationGesture()
                                            .updating($pinchScale) { value, state, _ in
                                                state = value
                                            }
                                            .onEnded { value in
                                                let newScale = min(max(scale * value, 0.3), 4.0)
                                                if newScale < 1.0 {
                                                    // 100% 아래로 당기면 뒤로가기
                                                    withAnimation(.easeIn(duration: 0.15)) {
                                                        scale = 0.5
                                                    }
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                                        onClose()
                                                    }
                                                } else {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                        scale = newScale
                                                    }
                                                }
                                            }
                                    )
                                    .simultaneousGesture(
                                        DragGesture()
                                            .onChanged { value in
                                                if scale > 1.0 {
                                                    offset = CGSize(
                                                        width: lastOffset.width + value.translation.width,
                                                        height: lastOffset.height + value.translation.height
                                                    )
                                                }
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                            }
                                    )
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.largeTitle)
                                        .foregroundStyle(.red)
                                    Text("Failed to load image")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .allowsHitTesting(true)
                    .onHover { hovering in
                        if livePhotoVideoURL != nil {
                            isLivePhotoVideoHovering = hovering
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.folder")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("File not found")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }

                // Info Panel Overlay (trailing slide-in)
                if showInfo {
                    HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Asset Info")
                                    .font(.title3.bold())
                                Spacer()
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showInfo = false
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Divider()

                            // Map (GPS가 있을 때만)
                            if let coord = gpsCoordinate {
                                MapPinView(coordinate: coord)
                                    .frame(height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            Group {
                                InfoRow(label: "Filename", value: asset.originalFilename)
                                InfoRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: asset.byteSize, countStyle: .file))
                                InfoRow(label: "Dimensions", value: "\(asset.pixelWidth) x \(asset.pixelHeight)")
                                InfoRow(label: "Created", value: asset.creationDate.formatted(date: .long, time: .standard))
                                if let gps = gpsLocation {
                                    InfoRow(label: "Location", value: gps)
                                }
                                InfoRow(label: "Media Type", value: asset.mediaType.uppercased())
                                InfoRow(label: "Status", value: asset.status.capitalized)
                                InfoRow(label: "Local ID", value: asset.assetLocalId)
                                InfoRow(label: "Device ID", value: asset.deviceId)
                            }

                            Spacer()
                        }
                        .padding(20)
                        .frame(width: 320)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 15, y: 5)
                        .transition(.move(edge: .trailing))
                        .padding(12)
                    }
                }
            }
        }
        .toolbar {
            if !isVideo {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        scale = max(1.0, scale - 0.25)
                        if scale == 1.0 { offset = .zero; lastOffset = .zero }
                    }) {
                        Image(systemName: "magnifyingglass.minus")
                    }
                    .disabled(scale <= 1.0)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { scale = min(4.0, scale + 0.25) }) {
                        Image(systemName: "magnifyingglass.plus")
                    }
                    .disabled(scale >= 4.0)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showInfo.toggle()
                    }
                }) {
                    Image(systemName: showInfo ? "info.circle.fill" : "info.circle")
                }
            }
        }
        .onAppear {
            if let fileURL = fileURL {
                Task {
                    self.gpsLocation = await extractLocation(from: fileURL, isVideo: isVideo)
                }
            }
        }
    }

    private func extractLocation(from url: URL, isVideo: Bool) async -> String? {
        // Step 1: Extract raw GPS coordinates
        var finalCoordinate: CLLocationCoordinate2D? = nil

        if isVideo {
            let avAsset = AVAsset(url: url)
            if let metadata = try? await avAsset.load(.metadata) {
                for item in metadata where item.commonKey == .commonKeyLocation {
                    if let str = try? await item.load(.stringValue) {
                        // ISO 6709: ±DD.DDDD±DDD.DDDD/
                        let scanner = Scanner(string: str)
                        if let lat = scanner.scanDouble(), let lon = scanner.scanDouble() {
                            finalCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        }
                    }
                }
            }
        } else {
            finalCoordinate = await Task.detached(priority: .userInitiated) {
                guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let props = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
                      let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
                      let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
                      let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
                      let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
                      let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
                else { return nil }
                let signedLat = latRef == "S" ? -lat : lat
                let signedLon = lonRef == "W" ? -lon : lon
                return CLLocationCoordinate2D(latitude: signedLat, longitude: signedLon)
            }.value
        }

        guard let coord = finalCoordinate, CLLocationCoordinate2DIsValid(coord) else { return nil }

        // coordinate를 부모에게 올려줌 (맵 표시용)
        await MainActor.run { gpsCoordinate = coord }

        // Step 2: Reverse geocode to human-readable address
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR")) { placemarks, _ in
                guard let p = placemarks?.first else {
                    continuation.resume(returning: String(format: "%.4f°, %.4f°", coord.latitude, coord.longitude))
                    return
                }
                // 가장 구체적인 필드 하나 + "근처"
                // subLocality(동) > locality(시) > subAdministrativeArea(구) > administrativeArea(도/시)
                let specific = p.subLocality
                    ?? p.locality
                    ?? p.subAdministrativeArea
                    ?? p.administrativeArea
                if let s = specific, !s.isEmpty {
                    continuation.resume(returning: "\(s) 근처")
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}


fileprivate struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

fileprivate struct NativeVideoPlayerView: NSViewRepresentable {
    let url: URL
    let autoPlay: Bool
    let showControls: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = AVPlayer(url: url)
        playerView.controlsStyle = showControls ? .floating : .none
        playerView.videoGravity = .resizeAspect
        
        // Loop video for live photos (when controls are hidden)
        if !showControls {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerView.player?.currentItem,
                queue: .main
            ) { [weak player = playerView.player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }
        
        if autoPlay {
            playerView.player?.play()
        }
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // No updates needed
    }
}

fileprivate struct MapPinView: NSViewRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsZoomControls = false
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 800,
            longitudinalMeters: 800
        )
        mapView.setRegion(region, animated: false)
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        mapView.addAnnotation(pin)
    }
}
