import SwiftUI
import Network
import ICherriProtocol
import ICherriDesignSystem
import Inject
import Factory
import CryptoKit
import ActivityKit


// Onboarding + pairing + backup trigger dashboard for iOS.
public struct BackupDashboardView: View {
    @ObserveInjection var inject
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = BackupDashboardViewModel()
    @State private var isTargetPickerPresented = false
    @State private var backupSheetDetent: PresentationDetent = .large

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 사진 권한이 제한(Selected Photos)인 경우 노란색 경고 배너 표시
                    if viewModel.photoPermissionStatus == .limited {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("사진 접근 권한이 제한됨 (Selected Photos)")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            Text("아이폰 설정에서 '선택된 사진만 허용'으로 설정되어 있어 전체 사진 중 일부(\(viewModel.totalLibraryAssetCount)장)만 접근 가능합니다. 남은 모든 사진을 백업하려면 아래와 같이 변경해 주세요:\n\n1. 아이폰의 **[설정]** 앱 실행\n2. 스크롤을 내려 **[iCherri]** 선택\n3. **[사진]** 메뉴 선택\n4. **[모든 사진]** 접근 권한으로 변경")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }

                    // 1. 단일 대화형 대시보드 시뮬레이터 디자인 본판 이식
                    simulatorSection
                    
                    // 백업 중이 아닐 때만 하단 2열 설정/기기 그리드를 보여줌
                    if viewModel.activeBackupProgressViewModel == nil {
                        settingsGridSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.vertical)
            }
            .background(backgroundGradient)
            .modifier(ScrollBounceBehaviorModifier())
            .navigationTitle("iCherri")
        }
        .task { await viewModel.onAppear() }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            viewModel.recoverStuckBackupIfNeeded()
            Task {
                await viewModel.refreshReceivers()
                await viewModel.reevaluateAutomaticBackup()
            }
        }
        .confirmationDialog(
            "Choose Backup Target",
            isPresented: $isTargetPickerPresented,
            titleVisibility: .visible
        ) {
            ForEach(viewModel.availableSwitchTargets) { receiver in
                Button(receiver.name) {
                    Task { await viewModel.pair(with: receiver) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pick a different Mac receiver for the next backup.")
        }
        .enableInjection()
    }

    // MARK: - Subviews (단일 대화형 대시보드 본판 구현)
    
    private var simulatorSection: some View {
        VStack(spacing: 20) {
            // 디스크 & 카드 Morphing 컨테이너
            VStack {
                if let progressViewModel = viewModel.activeBackupProgressViewModel {
                    ExpandedBackupCardView(progressViewModel: progressViewModel)
                        .transition(.opacity)
                } else {
                    defaultDiscView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.activeBackupProgressViewModel != nil)
            .frame(height: viewModel.activeBackupProgressViewModel != nil ? 270 : 190)
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: viewModel.activeBackupProgressViewModel != nil)
            .background(morphingBackgroundGlow)
            
            triggerAndControls
        }
        .padding()
        .modifier(GlassContainerModifier())
    }
    
    private var defaultDiscView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                if !viewModel.isPaired {
                    Circle()
                        .fill(.gray)
                        .frame(width: 8, height: 8)
                    Text("연결 없음")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(.gray)
                } else {
                    Circle()
                        .fill(viewModel.pairedReceiverIsOnline ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(viewModel.pairedReceiverIsOnline ? "Online" : "Offline")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(viewModel.pairedReceiverIsOnline ? .green : .orange)
                }
            }
            
            Text(viewModel.pairedReceiverName ?? "대상을 선택해 주세요")
                .font(.system(.headline, design: .rounded, weight: .bold))
            
            if let recentResult = viewModel.autoBackupRecentResultMessage {
                Text(recentResult)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                Text("백업 대기 중")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .transition(.scale.combined(with: .opacity))
        .frame(width: 160, height: 160)
        .modifier(GlassCircleModifier())
    }
    
    private var morphingBackgroundGlow: some View {
        ZStack {
            if viewModel.activeBackupProgressViewModel == nil {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .blur(radius: 20)
            } else {
                RoundedRectangle(cornerRadius: 30)
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blur(radius: 25)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: viewModel.activeBackupProgressViewModel != nil)
    }
    
    private var triggerAndControls: some View {
        VStack(spacing: 12) {
            if let progressViewModel = viewModel.activeBackupProgressViewModel {
                BackupControlsView(viewModel: viewModel, progressViewModel: progressViewModel)
            } else {
                // 평소 상태 -> 백업 시작 버튼
                Button(action: {
                    Task {
                        await viewModel.startBackup()
                    }
                }) {
                    Label("백업 시작", systemImage: "arrow.up.to.line.compact")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(viewModel.isBackingUp || !viewModel.pairedReceiverIsOnline)
            }
        }
    }
    
    private var settingsGridSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("설정 및 기기 연결 상태")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.isBrowsing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // 자동 백업 카드 (실제 자동 백업 스토어 및 스케줄러 연동 완료!)
                VStack(alignment: .leading, spacing: 8) {
                    Label("자동 백업", systemImage: "bolt.badge.aod")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Toggle("", isOn: Binding(
                        get: { viewModel.isAutoBackupEnabled },
                        set: { isEnabled in
                            Task {
                                await viewModel.setAutoBackupEnabled(isEnabled)
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(.accentColor)
                    
                    Text(viewModel.autoBackupEligibilityMessage ?? "배터리 20% + Wi-Fi 조건")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(GlassCardModifier())
                
                // 사진 권한 카드 (탭 시 실제 사진 라이브러리 접근 요청 연동)
                Button(action: {
                    if viewModel.photoPermissionStatus != .granted && viewModel.photoPermissionStatus != .limited {
                        Task {
                            await viewModel.requestPhotoPermission()
                        }
                    }
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("사진 라이브러리", systemImage: "photo.fill")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(viewModel.photoPermissionStatus == .granted ? "허용됨" : (viewModel.photoPermissionStatus == .limited ? "부분 허용됨" : (viewModel.photoPermissionStatus == .denied ? "차단됨" : "확인 중")))
                                .font(.system(.footnote, design: .rounded, weight: .semibold))
                                .foregroundColor(viewModel.photoPermissionStatus == .granted ? .green : (viewModel.photoPermissionStatus == .limited ? .orange : (viewModel.photoPermissionStatus == .denied ? .red : .orange)))
                            Spacer()
                            Image(systemName: viewModel.photoPermissionStatus == .granted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(viewModel.photoPermissionStatus == .granted ? .green : (viewModel.photoPermissionStatus == .limited ? .orange : (viewModel.photoPermissionStatus == .denied ? .red : .orange)))
                        }
                        
                        Text(viewModel.photoPermissionStatus == .granted ? "라이브러리 접근 허가" : (viewModel.photoPermissionStatus == .limited ? "선택된 사진만 허용됨 (탭하여 권한 설명)" : "탭하여 권한 요청"))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(GlassCardModifier())
                }
                .buttonStyle(.plain)
                
                // 로컬 네트워크 카드 (탭 시 수동 Bonjour 새로고침 유동적 호출)
                Button(action: {
                    Task {
                        await viewModel.refreshReceivers()
                    }
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("로컬 네트워크", systemImage: "network")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(viewModel.localNetworkStatus == .granted ? "허용됨" : "확인 필요")
                                .font(.system(.footnote, design: .rounded, weight: .semibold))
                                .foregroundColor(viewModel.localNetworkStatus == .granted ? .green : .orange)
                            Spacer()
                            Image(systemName: viewModel.localNetworkStatus == .granted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(viewModel.localNetworkStatus == .granted ? .green : .orange)
                        }
                        
                        Text("주변 Mac 탐색 허가")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(GlassCardModifier())
                }
                .buttonStyle(.plain)
                
                // ⭐️ [요구사항 완벽 반영] 백업 대상 선택 및 Forget/Refresh 가 탑재된 기기 연결 카드
                Menu {
                    Section("감지된 기기 (자동 스캔 중)") {
                        if viewModel.discoveredReceivers.isEmpty {
                            Text("검색된 주변 Mac 기기 없음")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.discoveredReceivers) { receiver in
                                Button(action: {
                                    Task {
                                        await viewModel.pair(with: receiver)
                                    }
                                }) {
                                    HStack {
                                        Text(receiver.name)
                                        if viewModel.pairedReceiverName == receiver.name {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Section("제어 및 해제") {
                        // 수동 새로고침
                        Button(action: {
                            Task {
                                await viewModel.refreshReceivers()
                            }
                        }) {
                            Label("주변 기기 새로고침 (Refresh)", systemImage: "arrow.clockwise")
                        }
                        
                        // 기기 잊기
                        if viewModel.isPaired {
                            Button(role: .destructive, action: {
                                viewModel.clearPairedReceiver()
                            }) {
                                Label("이 기기 연결 끊기 (Forget)", systemImage: "trash")
                            }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("백업 대상", systemImage: "macbook.and.iphone")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(viewModel.pairedReceiverName ?? "선택 안 됨")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if !viewModel.isPaired {
                            Text("연결 없음")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.gray)
                        } else {
                            Text(viewModel.pairedReceiverIsOnline ? "🟢 Online" : "🟠 Offline")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(viewModel.pairedReceiverIsOnline ? .green : .orange)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(GlassCardModifier())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private var backgroundGradient: some View {
        ZStack {
            // 기본 베이스 배경 (라이트/다크 대응)
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.18),
                    Color.purple.opacity(0.12),
                    Color.blue.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 배경 오로라 빛 굴절 레이어 (Liquid Glass 투과용)
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.35))
                        .frame(width: proxy.size.width * 0.8)
                        .blur(radius: 60)
                        .offset(x: -proxy.size.width * 0.2, y: -proxy.size.height * 0.1)
                    
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: proxy.size.width * 0.7)
                        .blur(radius: 70)
                        .offset(x: proxy.size.width * 0.3, y: proxy.size.height * 0.2)
                    
                    Circle()
                        .fill(Color.pink.opacity(0.25))
                        .frame(width: proxy.size.width * 0.6)
                        .blur(radius: 50)
                        .offset(x: -proxy.size.width * 0.1, y: proxy.size.height * 0.5)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func phaseTitle(for phase: BackupProgressPhase) -> String {
        switch phase {
        case .scanning: return "스캔 중"
        case .checking: return "해시파일 비교 중"
        case .uploading: return "전송 중"
        case .complete: return "완료"
        case .failed: return "실패"
        }
    }
    
    private func phaseDescription(for phase: BackupProgressPhase) -> String {
        switch phase {
        case .scanning: return "최근 촬영된 라이브러리 스캔 중…"
        case .checking: return "Mac 리시버의 해시 파일과 비교 중…"
        case .uploading: return "iPhone 사진 라이브러리 전송 중"
        case .complete: return "모든 사진이 Mac에 동기화되었습니다."
        case .failed: return "백업 도중 오류가 발생했습니다."
        }
    }
    
    private func simulatedProgressText(for progressViewModel: BackupProgressViewModel) -> String {
        return "\(progressViewModel.overallBackedUpCount) / \(progressViewModel.totalCount)"
    }
}

// MARK: - Liquid Glass ViewModifiers

/// 그리드 카드(설정/권한/기기 연결)에 적용하는 Modifier.
/// iOS 26+ : .glassEffect(.clear.interactive(), in: .rect(cornerRadius:))
/// iOS 25- / macOS : .ultraThinMaterial + cornerRadius + 테두리 fallback
private struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 26, *) {
            content
                .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
        }
#else
        content
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.18), lineWidth: 0.5)
            )
#endif
    }
}

/// 메인 시뮬레이터 섹션 컨테이너에 적용하는 Modifier.
private struct GlassContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 26, *) {
            content
                .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 20))
        } else {
            content
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(20)
        }
#else
        content
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(20)
#endif
    }
}

/// 원형 disc 뷰에 적용하는 Modifier.
private struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 26, *) {
            content
                .glassEffect(.clear.interactive(), in: .circle)
        } else {
            content
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.35), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        )
                        .shadow(color: .blue.opacity(0.12), radius: 12, y: 6)
                )
        }
#else
        content
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: .blue.opacity(0.12), radius: 12, y: 6)
            )
#endif
    }
}

// MARK: - ViewModel

enum PermissionStatus { case granted, limited, denied, unknown }

enum UploadConcurrencyPolicy {
    static let hardCap = 4

    static func recommendedConcurrency(for assets: ArraySlice<AssetMetadata>, maxAllowed: Int = hardCap) -> Int {
        let candidates = Array(assets)
        guard !candidates.isEmpty else { return 1 }

        let cappedMax = max(1, min(maxAllowed, hardCap))
        let videoCount = candidates.filter { $0.mediaType == .video }.count
        let hugeAssetCount = candidates.filter { $0.byteSize >= 500_000_000 }.count
        let largeAssetCount = candidates.filter { $0.byteSize >= 25_000_000 }.count
        let unknownSizeCount = candidates.filter { $0.byteSize <= 0 }.count
        let averageByteSize = candidates.reduce(Int64(0)) { $0 + max($1.byteSize, 0) } / Int64(max(candidates.count, 1))

        if videoCount >= 2 || hugeAssetCount > 0 {
            return min(2, cappedMax)
        }

        if videoCount == 1 {
            return min(2, cappedMax)
        }

        if largeAssetCount >= 3 || unknownSizeCount > candidates.count / 2 {
            return min(2, cappedMax)
        }

        if candidates.count >= 20 && averageByteSize > 0 && averageByteSize <= 8_000_000 {
            return min(4, cappedMax)
        }

        return min(3, cappedMax)
    }
}

@MainActor
final class BackupDashboardViewModel: ObservableObject {
    private static let maxConcurrentUploads = UploadConcurrencyPolicy.hardCap

    private let resolver: any ReceiverResolver

    init(resolver: any ReceiverResolver = Container.shared.receiverResolver()) {
        self.resolver = resolver
    }

    @Published var photoPermissionStatus: PermissionStatus = .unknown
    @Published var totalLibraryAssetCount = 0
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
    @Published var isAutoBackupEnabled = false
    @Published var autoBackupEligibilityMessage: String?
    @Published var autoBackupStatusSummary: AutoBackupStatusViewModel?
    @Published var autoBackupRecentResultMessage: String?
    @Published var autoBackupLastSuccessMessage: String?
    @Published var autoBackupNextEvaluationMessage: String?
    @Published var activeBackupProgressViewModel: BackupProgressViewModel?
    @Published var backupCoverageSummary: String?
    @Published var backupCoverageProgress: Double?
    @Published var isBrowsing = false
    private var pingTimer: Task<Void, Never>?
    private var activeBackupTask: Task<Bool, Never>?

    var pairedReceiverIsOnline: Bool {
        guard let name = pairedReceiverName else { return false }
        return discoveredReceivers.contains(where: { $0.name == name })
    }

    var suggestedSwitchTarget: DiscoveredReceiver? {
        guard isPaired && !pairedReceiverIsOnline else { return nil }
        return availableSwitchTargets.first
    }

    func startPingTimer() {
        pingTimer?.cancel()
        pingTimer = Task {
            // Send an initial ping immediately on timer start
            await sendPingToReceiver()
            
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                    await sendPingToReceiver()
                } catch {
                    break
                }
            }
        }
    }

    func stopPingTimer() {
        pingTimer?.cancel()
        pingTimer = nil
    }

    private func sendPingToReceiver() async {
        guard isPaired, pairedReceiverIsOnline,
              let receiverURLString = UserDefaults.standard.string(forKey: receiverURLKey),
              let receiverURL = URL(string: receiverURLString)
        else { return }

        let deviceID = persistentDeviceID()

        do {
            struct DevicePingRequest: Codable {
                let deviceID: String
            }
            let pingReq = DevicePingRequest(deviceID: deviceID)
            guard let url = URL(string: "\(receiverURLString)/devices/ping") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 4
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(pingReq)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode >= 400 {
                    let errMsg = String(data: data, encoding: .utf8) ?? "No response body"
                    print("[Ping] Failed to send heartbeat. HTTP \(http.statusCode): \(errMsg)")
                } else {
                    print("[Ping] Successfully sent heartbeat ping to receiver")
                }
            } else {
                print("[Ping] Successfully sent heartbeat ping to receiver")
            }
        } catch {
            print("[Ping] Failed to send heartbeat: \(error)")
        }
    }

    @Injected(\.photoLibraryScanner) private var scanner
    @Injected(\.photoLibraryScanIndexStore) private var scanIndexStore
    @Injected(\.bonjourBrowser) private var bonjourBrowser
    @Injected(\.keychainStore) private var keychainStore
    @Injected(\.autoBackupStore) private var autoBackupStore
    @Injected(\.autoBackupScheduler) private var autoBackupScheduler
    @Injected(\.autoBackupEngine) private var autoBackupEngine
    @Injected(\.autoBackupPolicyEvaluator) private var autoBackupPolicyEvaluator
    private let trustTokenKey = "iCherriTrustToken"
    private let receiverIDKey = "iCherriReceiverID"
    private let receiverURLKey = "iCherriReceiverURL"
    private let receiverNameKey = "iCherriReceiverName"

    var isBackupSheetLocked: Bool {
        guard let activeBackupProgressViewModel else { return false }
        return isBackingUp && !activeBackupProgressViewModel.isComplete
    }

    var availableSwitchTargets: [DiscoveredReceiver] {
        discoveredReceivers.filter { receiver in
            guard let currentID = pairedReceiver?.id else {
                return pairedReceiverName != receiver.name
            }
            return receiver.id != currentID
        }
    }

    func onAppear() async {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updatePhotoPermission()
        restorePairingState()
        await loadAutoBackupPolicy()
        await syncAutoBackupReceiverSelectionFromDefaults()
        scanIndexStore.startObserving()
        bonjourBrowser.startBrowsing()
        // Observe browser changes
        Task { @MainActor in
            for await receivers in bonjourBrowser.$discoveredReceivers.values {
                self.discoveredReceivers = receivers
                self.localNetworkStatus = receivers.isEmpty ? self.localNetworkStatus : .granted
                
                // Auto-Healing: Automatically detect and update the stored URL if the Mac's IP/port has changed
                if let pairedName = self.pairedReceiverName,
                   let matchingReceiver = receivers.first(where: { $0.name == pairedName }) {
                    self.pairedReceiver = matchingReceiver
                    Task {
                        do {
                            let newBaseURL = try await self.resolver.resolve(matchingReceiver.endpoint)
                            let currentStoredURL = UserDefaults.standard.string(forKey: self.receiverURLKey)
                            if newBaseURL.absoluteString != currentStoredURL {
                                UserDefaults.standard.set(newBaseURL.absoluteString, forKey: self.receiverURLKey)
                                print("[Auto-Healing] Automatically updated receiver URL to \(newBaseURL.absoluteString)")
                            }
                            // Start pinging immediately once the endpoint is resolved to the new URL
                            self.startPingTimer()
                        } catch {
                            print("[Auto-Healing] Failed to auto-resolve endpoint: \(error)")
                        }
                    }
                } else if let pairedReceiverID = UserDefaults.standard.string(forKey: self.receiverIDKey) {
                    self.pairedReceiver = receivers.first(where: { $0.id == pairedReceiverID })
                    if let endpoint = self.pairedReceiver?.endpoint {
                        Task {
                            do {
                                let newBaseURL = try await self.resolver.resolve(endpoint)
                                UserDefaults.standard.set(newBaseURL.absoluteString, forKey: self.receiverURLKey)
                                self.startPingTimer()
                            } catch {
                                print("[Auto-Healing] Failed to resolve matched receiver by ID: \(error)")
                            }
                        }
                    }
                } else if let pairedReceiverName {
                    self.pairedReceiver = receivers.first(where: { $0.name == pairedReceiverName })
                    if let endpoint = self.pairedReceiver?.endpoint {
                        Task {
                            do {
                                let newBaseURL = try await self.resolver.resolve(endpoint)
                                UserDefaults.standard.set(newBaseURL.absoluteString, forKey: self.receiverURLKey)
                                self.startPingTimer()
                            } catch {
                                print("[Auto-Healing] Failed to resolve matched receiver by name: \(error)")
                            }
                        }
                    }
                }
                
                Task {
                    await self.reevaluateAutomaticBackup()
                }
            }
        }
        Task { @MainActor in
            for await status in bonjourBrowser.$status.values {
                switch status {
                case .ready:
                    self.localNetworkStatus = .granted
                    self.isBrowsing = false
                case .failed:
                    self.localNetworkStatus = .denied
                    self.isBrowsing = false
                case .browsing:
                    self.isBrowsing = true
                    if self.localNetworkStatus != .granted {
                        self.localNetworkStatus = .unknown
                    }
                case .idle:
                    self.isBrowsing = false
                    if self.localNetworkStatus != .granted {
                        self.localNetworkStatus = .unknown
                    }
                }
                Task {
                    await self.reevaluateAutomaticBackup()
                }
            }
        }
        Task {
            await reevaluateAutomaticBackup()
        }
    }

    func requestPhotoPermission() async {
        let status = await scanner.requestAuthorization()
        photoPermissionStatus = permissionStatus(for: status)
    }

    func refreshReceivers() async {
        bonjourBrowser.refreshBrowsing()
        if localNetworkStatus != .granted {
            localNetworkStatus = .unknown
        }
        pairingStatusMessage = isPaired
            ? pairedReceiverName.map { "Connected to \($0)." }
            : "Refreshing available receivers..."
        Task {
            await reevaluateAutomaticBackup()
        }
    }

    func setAutoBackupEnabled(_ isEnabled: Bool) async {
        isAutoBackupEnabled = isEnabled
        let currentPolicy = await autoBackupStore.loadPolicy()
        let updatedPolicy = AutoBackupPolicy(
            isEnabled: isEnabled,
            minimumBatteryPercent: currentPolicy.minimumBatteryPercent,
            requiresWiFiEnabled: currentPolicy.requiresWiFiEnabled,
            blocksOnLowPowerMode: currentPolicy.blocksOnLowPowerMode,
            pauseThermalThreshold: currentPolicy.pauseThermalThreshold,
            stagedStorageLimitBytes: currentPolicy.stagedStorageLimitBytes
        )
        await autoBackupStore.savePolicy(updatedPolicy)
        autoBackupScheduler.scheduleNextEvaluation()
        Task {
            await reevaluateAutomaticBackup()
        }
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
            let baseURL = try await self.resolver.resolve(receiver.endpoint)
            let device = currentDeviceInfo()
            let pairRequest = PairingStartRequest(device: device)
            
            guard let url = URL(string: "\(baseURL.absoluteString)/pair") else {
                throw URLError(.badURL)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 5
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
                UserDefaults.standard.set(receiver.id, forKey: receiverIDKey)
                UserDefaults.standard.set(baseURL.absoluteString, forKey: receiverURLKey)
                UserDefaults.standard.set(receiver.name, forKey: receiverNameKey)

                pairedReceiver = receiver
                pairedReceiverName = receiver.name
                isPaired = true
                pairingStatusMessage = "Connected to \(receiver.name)."
                await autoBackupStore.saveReceiverSelection(
                    AutoBackupReceiverSelection(
                        receiverID: receiver.id,
                        receiverName: receiver.name,
                        receiverURLString: baseURL.absoluteString,
                        trustTokenStorageKey: trustTokenKey
                    )
                )
                self.startPingTimer()
                Task {
                    await reevaluateAutomaticBackup()
                }
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

    func clearPairedReceiver() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: trustTokenKey)
        defaults.removeObject(forKey: receiverIDKey)
        defaults.removeObject(forKey: receiverURLKey)
        defaults.removeObject(forKey: receiverNameKey)

        pairedReceiver = nil
        pairedReceiverName = nil
        isPaired = false
        pairingStatusMessage = "Choose a Mac receiver to use as the backup target."
        backupStatusMessage = nil
        backupCoverageSummary = nil
        backupCoverageProgress = nil
        bonjourBrowser.refreshBrowsing()
        autoBackupEligibilityMessage = "Automatic backup is waiting for a backup target."
        self.stopPingTimer()
        Task {
            await autoBackupStore.saveReceiverSelection(nil)
            await refreshAutoBackupStatusPresentation(fallbackMessage: self.autoBackupEligibilityMessage)
        }
    }

    func reevaluateAutomaticBackup() async {
        guard photoPermissionStatus == .granted || photoPermissionStatus == .limited else {
            autoBackupEligibilityMessage = "Automatic backup needs Photos access."
            await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
            return
        }

        let policy = await autoBackupStore.loadPolicy()
        isAutoBackupEnabled = policy.isEnabled

        guard policy.isEnabled else {
            autoBackupEligibilityMessage = "Automatic backup is off."
            await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
            return
        }

        let runtimeSnapshot = makeAutoBackupRuntimeSnapshot()
        let eligibility = autoBackupPolicyEvaluator.evaluate(policy: policy, runtimeSnapshot: runtimeSnapshot)

        guard let receiverID = UserDefaults.standard.string(forKey: receiverIDKey), !receiverID.isEmpty else {
            autoBackupEligibilityMessage = "Automatic backup is waiting for a backup target."
            autoBackupScheduler.scheduleNextEvaluation()
            await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
            return
        }

        guard eligibility.isEligible else {
            autoBackupEligibilityMessage = eligibilityMessage(for: eligibility.reason)
            autoBackupScheduler.scheduleNextEvaluation()
            _ = try? await autoBackupEngine.evaluateAndPrepareRun(
                receiverID: receiverID,
                receiverName: pairedReceiverName,
                runtimeSnapshot: runtimeSnapshot,
                runAssets: []
            )
            await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
            return
        }

        let device = currentDeviceInfo()
        let scanPlan = await scanIndexStore.makeScanPlan(scanner: scanner, deviceID: device.deviceID)
        if let preparedRun = try? await autoBackupEngine.evaluateAndPrepareRun(
            receiverID: receiverID,
            receiverName: pairedReceiverName,
            runtimeSnapshot: runtimeSnapshot,
            runAssets: scanPlan.runAssets
        ) {
            autoBackupEligibilityMessage = scanPlan.runAssets.isEmpty
                ? "Automatic backup is ready. No changed assets are waiting."
                : "Automatic backup prepared \(preparedRun.assetRecords.count) item(s)."
        } else {
            autoBackupEligibilityMessage = "Automatic backup could not prepare a run."
        }
        autoBackupScheduler.scheduleNextEvaluation()
        await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
    }

    func startBackup() async {
        guard photoPermissionStatus == .granted || photoPermissionStatus == .limited else {
            backupStatusMessage = "Allow Photos access before starting backup."
            return
        }
        guard
            let trustToken = UserDefaults.standard.string(forKey: trustTokenKey),
            !trustToken.isEmpty
        else {
            backupStatusMessage = "Connect to a Mac receiver first."
            return
        }

        isBackingUp = true
        backupStatusMessage = "Scanning photo library..."
        let device = currentDeviceInfo()
        self.totalLibraryAssetCount = scanner.totalAssetCount()
        let progressViewModel = BackupProgressViewModel(totalCount: 0)
        progressViewModel.setPhase(.scanning)
        if #available(iOS 16.2, *) {
            BackupLiveActivityManager.shared.start(
                deviceName: device.deviceName,
                completedCount: 0,
                totalCount: self.totalLibraryAssetCount,
                phaseText: "라이브러리 스캔 중..."
            )
        }
        progressViewModel.onRetryFailedUploads = { [weak self] assetIDs in
            guard let self else { return }
            Task { @MainActor in
                await self.retryFailedUploads(assetIDs: assetIDs)
            }
        }
        progressViewModel.onRetryUpload = { [weak self] assetLocalID in
            guard let self else { return }
            Task { @MainActor in
                await self.retryFailedUploads(assetIDs: [assetLocalID])
            }
        }
        progressViewModel.update(
            filename: "Scanning photo library...",
            completed: 0,
            success: 0,
            duplicates: 0,
            failed: 0,
            overallBackedUpCount: 0,
            phase: .scanning,
            bytesPerSecond: 0,
            sentBytes: 0,
            totalBytes: 0,
            activeUploads: 0,
            activeUploadItems: [],
            failedUploadItems: []
        )
        activeBackupProgressViewModel = progressViewModel
        let pairedReceiverSnapshot = pairedReceiver
        let pairedReceiverIDSnapshot = UserDefaults.standard.string(forKey: receiverIDKey)
        let pairedReceiverNameSnapshot = pairedReceiverName
        let discoveredReceiversSnapshot = discoveredReceivers
        let storedReceiverURLString = UserDefaults.standard.string(forKey: receiverURLKey)

        var backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ManualBackup") { [weak self] in
            // iOS ran out of background time. Cancel the in-flight backup so its `defer` cleanup
            // below actually runs (resets isBackingUp, stops the Live Activity, ends the
            // background task) instead of leaving the task frozen mid-await when the process is
            // suspended — this previously only ended the background task assertion without ever
            // cancelling the work driving it, so returning to the foreground left the UI stuck
            // showing "backing up" with nothing left running to finish it.
            Task { @MainActor in
                self?.activeBackupTask?.cancel()
            }
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }

        let backupTask = Task.detached(priority: .userInitiated) { [maxConcurrentUploads = Self.maxConcurrentUploads, backgroundTaskID, pairedReceiverIDSnapshot] in
            var executedScanMode: PhotoLibraryScanPlan.Mode = .incremental
            defer {
                Task { @MainActor in
                    self.isBackingUp = false
                    self.activeBackupTask = nil
                    if #available(iOS 16.2, *) {
                        BackupLiveActivityManager.shared.stop()
                    }
                    if backgroundTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    }
                }
            }

            do {
                try Task.checkCancellation()

                // Switch the scan index store to load the correct receiver-specific cache file
                await self.scanIndexStore.switchReceiver(to: pairedReceiverIDSnapshot)

                let scanPlan = await self.scanIndexStore.makeScanPlan(
                    scanner: self.scanner,
                    deviceID: device.deviceID,
                    willPersist: {
                        Task { @MainActor in
                            progressViewModel.update(
                                filename: "스캔 결과 저장 중...",
                                completed: progressViewModel.totalCount,
                                success: 0,
                                duplicates: 0,
                                failed: 0,
                                overallBackedUpCount: progressViewModel.overallBackedUpCount,
                                phase: .scanning,
                                bytesPerSecond: 0,
                                sentBytes: 0,
                                totalBytes: 0,
                                activeUploads: 0,
                                activeUploadItems: [],
                                failedUploadItems: []
                            )
                            if #available(iOS 16.2, *) {
                                BackupLiveActivityManager.shared.update(
                                    progress: 1.0,
                                    completedCount: progressViewModel.overallBackedUpCount,
                                    totalCount: max(progressViewModel.totalCount, 1),
                                    formattedSpeed: "—",
                                    filename: nil,
                                    phaseText: "스캔 결과 저장 중..."
                                )
                            }
                        }
                    }
                ) { completed, total in
                    Task { @MainActor in
                        progressViewModel.update(
                            filename: "라이브러리 스캔 중...",
                            completed: completed,
                            success: 0,
                            duplicates: 0,
                            failed: 0,
                            overallBackedUpCount: completed,
                            phase: .scanning,
                            bytesPerSecond: 0,
                            sentBytes: 0,
                            totalBytes: 0,
                            activeUploads: 0,
                            activeUploadItems: [],
                            failedUploadItems: []
                        )
                        progressViewModel.totalCount = total
                        progressViewModel.progress = total > 0 ? Double(completed) / Double(total) : 0.0
                        if #available(iOS 16.2, *) {
                            BackupLiveActivityManager.shared.update(
                                progress: progressViewModel.progress,
                                completedCount: completed,
                                totalCount: total,
                                formattedSpeed: "—",
                                filename: nil,
                                phaseText: "라이브러리 스캔 중..."
                            )
                        }
                    }
                    return !progressViewModel.isCancelledFromAnyThread
                }
                executedScanMode = scanPlan.mode
                let runAssets = scanPlan.runAssets

                await MainActor.run {
                    progressViewModel.setTotalCount(scanPlan.runAssetCount)
                    progressViewModel.setTotalBytes(scanPlan.runAssetBytes)
                    progressViewModel.totalCount = scanPlan.libraryAssetCount
                    progressViewModel.overallBackedUpCount = max(scanPlan.libraryAssetCount - scanPlan.runAssetCount, 0)
                    // setTotalCount() above already recomputed `progress`, but from the
                    // pre-reassignment overallBackedUpCount/totalCount (the scan tally). Recompute
                    // once more from the values actually being displayed (the "already backed up"
                    // baseline) so the LiquidProgressBar can't show 0% while the count badge next
                    // to it already reads N/N — the two were being left out of sync here.
                    progressViewModel.progress = progressViewModel.totalCount > 0
                        ? Double(progressViewModel.overallBackedUpCount) / Double(progressViewModel.totalCount)
                        : 0
                }

                try Task.checkCancellation()

                if runAssets.isEmpty {
                    // Resolve receiver and verify if Mac is missing any assets (SSOT mismatch check)
                    let receiverURL = try await self.resolveReceiverURLForBackup(
                        pairedReceiver: pairedReceiverSnapshot,
                        pairedReceiverID: pairedReceiverIDSnapshot,
                        pairedReceiverName: pairedReceiverNameSnapshot,
                        discoveredReceivers: discoveredReceiversSnapshot,
                        storedReceiverURLString: storedReceiverURLString
                    )
                    
                    let backupClient = BackupClient(receiverBaseURL: receiverURL, device: device, trustToken: trustToken)
                    let backupRunID = UUID().uuidString
                    let batchResponse = try await backupClient.checkBatch(
                        backupRunID: backupRunID,
                        candidates: [],
                        totalAssetCount: scanPlan.libraryAssetCount,
                        totalAssetBytes: scanPlan.libraryAssetBytes
                    )
                    
                    let ssotCompletedCount = batchResponse.completedAssetCount
                    if scanPlan.mode == .incremental {
                        let expectedCompletedCount = scanPlan.libraryAssetCount
                        if ssotCompletedCount < expectedCompletedCount {
                            print("[Backup] Mismatch (empty runAssets): Mac has \(ssotCompletedCount), expected \(expectedCompletedCount). Triggering full reconcile.")
                            await self.scanIndexStore.markRequiresReconcile()
                            throw BackupRunReconcileError.reconcileRequired
                        }
                    }

                    await MainActor.run {
                        progressViewModel.update(
                            filename: scanPlan.mode == .incremental ? "Nothing new to back up" : "No media found",
                            completed: 0,
                            success: 0,
                            duplicates: 0,
                            failed: 0,
                            overallBackedUpCount: ssotCompletedCount,
                            phase: .complete,
                            bytesPerSecond: 0,
                            totalBytes: scanPlan.runAssetBytes
                        )
                        self.backupStatusMessage = scanPlan.mode == .incremental
                            ? "No changed photos or videos need backup."
                            : "No photos or videos found to back up."
                        self.scanIndexStore.finishBackupRun(mode: scanPlan.mode)
                    }
                    return false
                }

                // batchResponse 도착 전까지는 0으로 초기화 — 실제값은 Mac DB SSOT로 아래서 보정
                let progressCoordinator = await MainActor.run {
                    BackupUploadProgressCoordinator(
                        viewModel: progressViewModel,
                        totalExpectedBytes: scanPlan.runAssetBytes,
                        totalCount: scanPlan.libraryAssetCount,
                        initialOverallBackedUpCount: 0
                    )
                }

                await progressCoordinator.updateSnapshot(
                    filename: "Checking existing backups...",
                    completed: 0,
                    success: 0,
                    duplicates: 0,
                    failed: 0,
                    overallBackedUpCount: 0,
                    phase: .checking,
                    bytesPerSecond: 0
                )

                // Start simulated progress sweep for hash file comparison
                let checkingProgressTask = Task { @MainActor in
                    var currentProgress = 0.0
                    while !Task.isCancelled && currentProgress < 0.95 {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        currentProgress += 0.05
                        progressViewModel.progress = currentProgress
                        let simulatedCompleted = Int(Double(scanPlan.runAssetCount) * currentProgress)
                        progressViewModel.overallBackedUpCount = simulatedCompleted
                        progressViewModel.totalCount = scanPlan.runAssetCount
                    }
                }

                let receiverURL = try await self.resolveReceiverURLForBackup(
                    pairedReceiver: pairedReceiverSnapshot,
                    pairedReceiverID: pairedReceiverIDSnapshot,
                    pairedReceiverName: pairedReceiverNameSnapshot,
                    discoveredReceivers: discoveredReceiversSnapshot,
                    storedReceiverURLString: storedReceiverURLString
                )

                let backupClient = BackupClient(receiverBaseURL: receiverURL, device: device, trustToken: trustToken)
                let backupRunID = UUID().uuidString
                let batchResponse = try await backupClient.checkBatch(
                    backupRunID: backupRunID,
                    candidates: runAssets,
                    totalAssetCount: scanPlan.libraryAssetCount,
                    totalAssetBytes: scanPlan.libraryAssetBytes
                )
                
                checkingProgressTask.cancel()
                await MainActor.run {
                    progressViewModel.progress = 1.0
                    progressViewModel.overallBackedUpCount = scanPlan.runAssetCount
                    progressViewModel.totalCount = scanPlan.runAssetCount
                }
                let assetIndex = Dictionary(uniqueKeysWithValues: runAssets.map { ($0.assetLocalID, $0) })

                // ✅ Mac DB SSOT: 로컬 추정값을 버리고 Mac이 응답한 실제 완료 파일 수로 즉시 보정
                let ssotCompletedCount = batchResponse.completedAssetCount

                // ✅ Mismatch detection between local scan cache and Mac database SSOT
                if scanPlan.mode == .incremental {
                    let expectedCompletedCount = scanPlan.libraryAssetCount - scanPlan.runAssetCount
                    if ssotCompletedCount < expectedCompletedCount {
                        print("[Backup] Mismatch: Mac has \(ssotCompletedCount), expected \(expectedCompletedCount). Triggering full reconcile.")
                        await self.scanIndexStore.markRequiresReconcile()
                        throw BackupRunReconcileError.reconcileRequired
                    }
                }

                await progressCoordinator.setInitialOverallBackedUpCount(ssotCompletedCount)
                await MainActor.run {
                    progressViewModel.overallBackedUpCount = ssotCompletedCount
                    progressViewModel.totalCount = scanPlan.libraryAssetCount
                }

                let duplicateAssetIDs = Set(batchResponse.alreadyBackedUp + batchResponse.duplicates)
                let reconcileState = BackupRunReconcileState(
                    libraryAssetCount: scanPlan.libraryAssetCount,
                    runAssetCount: scanPlan.runAssetCount,
                    duplicateCount: duplicateAssetIDs.count,
                    failedAssetIDs: Set(batchResponse.unsupported)
                )
                // ✅ reconcileState에도 SSOT를 주입 — snapshotCounts()가 max(로컬추정, SSOT)를 반환하도록
                // 이 값이 없으면 updateSnapshot()이 overallBackedUpCount를 1 같은 값으로 덮어쓰게 됨
                await reconcileState.setReceiverCompletedAssetCount(ssotCompletedCount)
                var pendingAssetIDs: Set<String> = []

                let duplicateBytes = (batchResponse.alreadyBackedUp + batchResponse.duplicates)
                    .compactMap { assetIndex[$0]?.byteSize }
                    .reduce(Int64(0), +)
                await MainActor.run {
                    if scanPlan.mode == .full {
                        self.updateBackupCoverage(backedUpCount: duplicateAssetIDs.count, totalCount: scanPlan.libraryAssetCount)
                    }
                    self.scanIndexStore.markSucceeded(assetIDs: batchResponse.alreadyBackedUp + batchResponse.duplicates)
                }
                var initialFailures = batchResponse.unsupported.map { assetLocalID in
                    FailedUploadProgressItem(
                        id: "unsupported-\(assetLocalID)",
                        filename: assetIndex[assetLocalID]?.originalFilename ?? assetLocalID,
                        reason: "Unsupported media type.",
                        retryAssetLocalID: nil
                    )
                }

                for requirement in batchResponse.requiredUploads {
                    guard let metadata = assetIndex[requirement.assetLocalID] else {
                        _ = await reconcileState.recordFailure(assetLocalID: requirement.assetLocalID)
                        initialFailures.append(
                            FailedUploadProgressItem(
                                id: requirement.assetLocalID,
                                filename: requirement.assetLocalID,
                                reason: "Asset metadata could not be resolved before upload.",
                                retryAssetLocalID: requirement.assetLocalID
                            )
                        )
                        continue
                    }
                    pendingAssetIDs.insert(metadata.assetLocalID)
                }

                let requiredUploadIDs = Array(pendingAssetIDs)
                await MainActor.run {
                    self.scanIndexStore.markRetryRequired(assetIDs: requiredUploadIDs)
                }

                let initialCounts = await reconcileState.snapshotCounts()
                await progressCoordinator.setInitialFailures(initialFailures)
                await progressCoordinator.setAcknowledgedBytes(duplicateBytes)
                await progressCoordinator.updateSnapshot(
                    filename: "Preparing uploads...",
                    completed: initialCounts.completed,
                    success: initialCounts.success,
                    duplicates: initialCounts.duplicates,
                    failed: initialCounts.failed,
                    overallBackedUpCount: initialCounts.overallBackedUpCount,
                    phase: pendingAssetIDs.isEmpty ? .checking : .uploading,
                    bytesPerSecond: 0
                )

                let maxReconcileRounds = 3
                var reconcileRound = 0

                while true {
                    if !pendingAssetIDs.isEmpty {
                        let roundAssets = pendingAssetIDs.sorted().compactMap { assetIndex[$0] }
                        let resolvedAssetIDs = Set(roundAssets.map(\.assetLocalID))
                        let unresolvedAssetIDs = pendingAssetIDs.subtracting(resolvedAssetIDs)
                        guard unresolvedAssetIDs.isEmpty else {
                            throw BackupRunReconcileError.unresolvedAssets(unresolvedAssetIDs.sorted())
                        }

                        try await self.uploadAssets(
                            pendingAssets: roundAssets,
                            receiverURL: receiverURL,
                            device: device,
                            trustToken: trustToken,
                            progressCoordinator: progressCoordinator,
                            maxConcurrentUploads: maxConcurrentUploads
                        ) { outcome in
                            switch outcome {
                            case .success(let assetLocalID, let filename):
                                let counts = await reconcileState.recordSuccess(assetLocalID: assetLocalID)
                                await MainActor.run {
                                    if scanPlan.mode == .full {
                                        self.updateBackupCoverage(backedUpCount: counts.overallBackedUpCount, totalCount: scanPlan.libraryAssetCount)
                                    }
                                    self.scanIndexStore.markSucceeded(assetIDs: [assetLocalID])
                                }
                                await progressCoordinator.finishAsset(
                                    assetLocalID: assetLocalID,
                                    filename: filename,
                                    completed: counts.completed,
                                    success: counts.success,
                                    duplicates: counts.duplicates,
                                    failed: counts.failed,
                                    overallBackedUpCount: counts.overallBackedUpCount
                                )
                            case .failure(let assetLocalID, let filename, let reason):
                                let counts = await reconcileState.recordFailure(assetLocalID: assetLocalID)
                                await progressCoordinator.finishAsset(
                                    assetLocalID: assetLocalID,
                                    filename: filename,
                                    completed: counts.completed,
                                    success: counts.success,
                                    duplicates: counts.duplicates,
                                    failed: counts.failed,
                                    overallBackedUpCount: counts.overallBackedUpCount
                                )
                                await progressCoordinator.recordFailure(
                                    assetLocalID: assetLocalID,
                                    filename: filename,
                                    reason: reason
                                )
                            }
                        }

                        pendingAssetIDs.removeAll()
                    }

                    let verifyingCounts = await reconcileState.snapshotCounts()
                    await progressCoordinator.updateSnapshot(
                        filename: "Verifying receiver snapshot...",
                        completed: verifyingCounts.completed,
                        success: verifyingCounts.success,
                        duplicates: verifyingCounts.duplicates,
                        failed: verifyingCounts.failed,
                        overallBackedUpCount: verifyingCounts.overallBackedUpCount,
                        phase: .checking,
                        bytesPerSecond: 0
                    )

                    let finalizeResponse = try await backupClient.finalizeBackupRun(backupRunID: backupRunID)
                    await reconcileState.setReceiverCompletedAssetCount(finalizeResponse.completedAssetCount)
                    let uploadedAssetIDs = await reconcileState.currentUploadedAssetIDs()
                    let missingAssetIDs = Set(finalizeResponse.missingAssetIDs)
                        .subtracting(duplicateAssetIDs)
                        .subtracting(uploadedAssetIDs)

                    guard !missingAssetIDs.isEmpty else { break }

                    reconcileRound += 1
                    guard reconcileRound <= maxReconcileRounds else {
                        throw BackupRunReconcileError.exceededRetryRounds(missingAssetIDs.sorted())
                    }

                    pendingAssetIDs = missingAssetIDs
                    let retryAssetIDs = Array(pendingAssetIDs)
                    await MainActor.run {
                        self.scanIndexStore.markRetryRequired(assetIDs: retryAssetIDs)
                    }

                    let retryCounts = await reconcileState.snapshotCounts()
                    await progressCoordinator.updateSnapshot(
                        filename: "Retrying \(pendingAssetIDs.count.formatted()) missing items...",
                        completed: retryCounts.completed,
                        success: retryCounts.success,
                        duplicates: retryCounts.duplicates,
                        failed: retryCounts.failed,
                        overallBackedUpCount: retryCounts.overallBackedUpCount,
                        phase: .uploading,
                        bytesPerSecond: 0
                    )
                }

                let finalCounts = await reconcileState.snapshotCounts()
                await MainActor.run {
                    if scanPlan.mode == .full {
                        self.updateBackupCoverage(backedUpCount: finalCounts.overallBackedUpCount, totalCount: scanPlan.libraryAssetCount)
                    }
                    self.scanIndexStore.finishBackupRun(mode: scanPlan.mode)
                    self.backupStatusMessage = "Backup complete. Uploaded \(finalCounts.success), skipped \(finalCounts.duplicates), failed \(finalCounts.failed)."
                    progressViewModel.setPhase(.complete)
                }
                return false
            } catch where error is CancellationError || (error as? URLError)?.code == .cancelled {
                let scanMode = executedScanMode
                await MainActor.run {
                    self.backupStatusMessage = "Backup canceled."
                    self.scanIndexStore.finishBackupRun(mode: scanMode)
                    self.activeBackupProgressViewModel = nil
                }
                return false
            } catch BackupRunReconcileError.reconcileRequired {
                return true
            } catch {
                print("[Backup] Backup run failed: \(error)")
                await MainActor.run {
                    let message = backupFailureReason(error)
                    self.backupStatusMessage = "Backup failed: \(message)"
                    progressViewModel.markRunFailed(message)
                }
                return false
            }
        }

        activeBackupTask = backupTask
        progressViewModel.bindCancellation(to: backupTask)
        let shouldRestart = await backupTask.value

        if shouldRestart {
            print("[Backup] Mismatch detected. Restarting with full scan...")
            await MainActor.run {
                self.isBackingUp = false
                self.activeBackupProgressViewModel = nil
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            await startBackup()
        }
    }

    func dismissBackupProgress() {
        activeBackupProgressViewModel = nil
    }

    /// Safety net for returning to the foreground: if `isBackingUp` is stuck true with no task
    /// actually driving it (e.g. the process was suspended before the background-expiration
    /// handler's cancellation could run its cleanup), clear the stale "backing up" state instead
    /// of leaving the UI frozen indefinitely with nothing left to finish it.
    func recoverStuckBackupIfNeeded() {
        guard isBackingUp, activeBackupTask == nil else { return }
        isBackingUp = false
        activeBackupProgressViewModel = nil
        backupStatusMessage = "Backup was interrupted while the app was in the background."
        if #available(iOS 16.2, *) {
            BackupLiveActivityManager.shared.stop()
        }
    }

    func retryFailedUploads(assetIDs: [String]) async {
        let retryableIDs = Array(Set(assetIDs))
        guard !retryableIDs.isEmpty else { return }
        guard !isBackingUp else { return }

        scanIndexStore.markRetryRequired(assetIDs: retryableIDs)
        activeBackupProgressViewModel = nil
        backupStatusMessage = "Retrying failed uploads..."
        await startBackup()
    }

    private func updateBackupCoverage(backedUpCount: Int, totalCount: Int) {
        guard totalCount > 0 else {
            backupCoverageSummary = nil
            backupCoverageProgress = nil
            return
        }

        let clampedCount = min(max(backedUpCount, 0), totalCount)
        let percent = Int((Double(clampedCount) / Double(totalCount) * 100).rounded())
        backupCoverageProgress = Double(clampedCount) / Double(totalCount)
        backupCoverageSummary = "\(percent)% · \(clampedCount.formatted()) / \(totalCount.formatted())"
    }

    private func updatePhotoPermission() {
        let status = scanner.currentAuthorizationStatus()
        photoPermissionStatus = permissionStatus(for: status)
        totalLibraryAssetCount = scanner.totalAssetCount()
    }

    private func loadAutoBackupPolicy() async {
        let policy = await autoBackupStore.loadPolicy()
        isAutoBackupEnabled = policy.isEnabled
    }

    private func syncAutoBackupReceiverSelectionFromDefaults() async {
        guard
            let receiverID = UserDefaults.standard.string(forKey: receiverIDKey),
            !receiverID.isEmpty
        else {
            await autoBackupStore.saveReceiverSelection(nil)
            await refreshAutoBackupStatusPresentation(fallbackMessage: "Automatic backup is waiting for a backup target.")
            return
        }

        await autoBackupStore.saveReceiverSelection(
            AutoBackupReceiverSelection(
                receiverID: receiverID,
                receiverName: UserDefaults.standard.string(forKey: receiverNameKey),
                receiverURLString: UserDefaults.standard.string(forKey: receiverURLKey),
                trustTokenStorageKey: trustTokenKey
            )
        )
        await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
    }

    private func makeAutoBackupRuntimeSnapshot() -> AutoBackupRuntimeSnapshot {
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryPercent = batteryLevel >= 0 ? Int((batteryLevel * 100).rounded()) : 100
        return AutoBackupRuntimeSnapshot(
            batteryLevelPercent: batteryPercent,
            isWiFiEnabled: localNetworkStatus == .granted,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: ProcessInfo.processInfo.thermalState,
            hasPairedReceiver: isPaired
        )
    }

    private func eligibilityMessage(for reason: AutoBackupEligibilityBlockReason?) -> String {
        switch reason {
        case .disabled:
            return "Automatic backup is off."
        case .batteryBelowMinimum:
            return "Automatic backup is waiting for battery to reach 20%."
        case .wiFiUnavailable:
            return "Automatic backup is waiting for Wi-Fi."
        case .receiverUnavailable:
            return "Automatic backup is waiting for a Mac receiver."
        case .lowPowerMode:
            return "Automatic backup is paused by Low Power Mode."
        case .thermal:
            return "Automatic backup is paused because the device is too warm."
        case nil:
            return "Automatic backup is ready."
        }
    }

    private func refreshAutoBackupStatusPresentation(fallbackMessage: String?) async {
        let receiverID = UserDefaults.standard.string(forKey: receiverIDKey)
        let activeRun: AutoBackupRun?
        if let receiverID, !receiverID.isEmpty {
            activeRun = await autoBackupStore.loadActiveRun(receiverID: receiverID)
        } else {
            activeRun = nil
        }
        let terminalRun = await autoBackupStore.loadMostRecentTerminalRun(receiverID: receiverID)
        let latestEvent = await autoBackupStore.loadLatestEvent(runID: activeRun?.runID ?? terminalRun?.runID)
        let nextEvaluationAt = await autoBackupStore.loadNextEvaluationDate()
        autoBackupStatusSummary = AutoBackupStatusViewModel.make(
            isEnabled: isAutoBackupEnabled,
            receiverName: pairedReceiverName,
            activeRun: activeRun,
            fallbackMessage: fallbackMessage,
            latestEvent: latestEvent
        )
        autoBackupRecentResultMessage = AutoBackupStatusViewModel.recentResultText(for: terminalRun)
        autoBackupLastSuccessMessage = AutoBackupStatusViewModel.lastSuccessText(for: terminalRun)
        autoBackupNextEvaluationMessage = AutoBackupStatusViewModel.nextEvaluationText(for: nextEvaluationAt)
    }

    private func permissionStatus(for status: PhotoLibraryAuthStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .granted
        case .limited:
            return .limited
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        }
    }

    private func restorePairingState() {
        let defaults = UserDefaults.standard
        guard
            let trustToken = defaults.string(forKey: trustTokenKey),
            !trustToken.isEmpty
        else {
            pairedReceiver = nil
            pairedReceiverName = nil
            isPaired = false
            return
        }

        pairedReceiverName = defaults.string(forKey: receiverNameKey)
        isPaired = pairedReceiverName != nil
        pairingStatusMessage = pairedReceiverName.map { "Connected to \($0)." }
        if isPaired {
            startPingTimer()
        }
    }

    private func describeBackupError(_ error: Error) -> String {
        backupFailureReason(error)
    }

    private func uploadAssets(
        pendingAssets: [AssetMetadata],
        receiverURL: URL,
        device: DeviceInfo,
        trustToken: String,
        progressCoordinator: BackupUploadProgressCoordinator,
        maxConcurrentUploads: Int,
        onOutcome: @escaping @Sendable (UploadTaskOutcome) async -> Void
    ) async throws {
        guard !pendingAssets.isEmpty else { return }

        // Start background pre-hashing pipeline
        let scanner = PhotoLibraryScanner()
        let prehashTask = Task.detached(priority: .utility) {
            for metadata in pendingAssets {
                if Task.isCancelled { break }
                
                // Keep memory usage low: wait if cache is full
                while await PrehashCache.shared.isFull() {
                    if Task.isCancelled { break }
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                }
                
                do {
                    if metadata.mediaType == .video {
                        // Stream hashing for videos to avoid memory loading
                        let (stream, _) = try await scanner.openInputStreamWithSize(for: metadata.assetLocalID)
                        stream.open()
                        var hasher = SHA256()
                        let bufSize = 65536
                        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
                        while stream.hasBytesAvailable {
                            if Task.isCancelled { break }
                            let n = stream.read(buf, maxLength: bufSize)
                            guard n > 0 else { break }
                            hasher.update(data: Data(bytes: buf, count: n))
                        }
                        buf.deallocate()
                        stream.close()
                        
                        if !Task.isCancelled {
                            let contentHash = hasher.finalize().map { String(format: "%02x", $0) }.joined()
                            await PrehashCache.shared.setHash(contentHash, for: metadata.assetLocalID)
                        }
                    } else {
                        let data = try await scanner.fetchData(for: metadata.assetLocalID)
                        if Task.isCancelled { break }
                        let contentHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                        await PrehashCache.shared.setHash(contentHash, for: metadata.assetLocalID)
                        await PrehashCache.shared.setData(data, for: metadata.assetLocalID)
                    }
                } catch {
                    print("[Prehash] Failed to prehash \(metadata.originalFilename): \(error)")
                }
            }
        }
        defer { prehashTask.cancel() }

        try await withThrowingTaskGroup(of: UploadTaskOutcome.self) { group in
            var nextIndex = 0
            var activeTaskCount = 0

            func enqueueNextUpload() {
                guard nextIndex < pendingAssets.count else { return }
                let metadata = pendingAssets[nextIndex]
                nextIndex += 1
                activeTaskCount += 1

                group.addTask {
                    let taskBackupClient = BackupClient(
                        receiverBaseURL: receiverURL,
                        device: device,
                        trustToken: trustToken
                    )
                    let taskChunkSender = ChunkUploadSender(
                        receiverBaseURL: receiverURL,
                        device: device,
                        trustToken: trustToken
                    )
                    let taskProgress = AssetUploadProgressReporter(
                        assetLocalID: metadata.assetLocalID,
                        filename: metadata.originalFilename,
                        coordinator: progressCoordinator
                    )
                    await taskChunkSender.setProgressDelegate(taskProgress)
                    let uploadManager = ResumableUploadManager(
                        backupClient: taskBackupClient,
                        chunkSender: taskChunkSender,
                        scanner: PhotoLibraryScanner()
                    )

                    await progressCoordinator.beginAsset(
                        assetLocalID: metadata.assetLocalID,
                        filename: metadata.originalFilename,
                        expectedByteSize: metadata.byteSize
                    )

                    do {
                        _ = try await uploadManager.upload(
                            assetLocalID: metadata.assetLocalID,
                            metadata: metadata
                        )
                        return .success(assetLocalID: metadata.assetLocalID, filename: metadata.originalFilename)
                    } catch {
                        print("[Backup] Failed to upload \(metadata.originalFilename): \(error)")
                        return .failure(
                            assetLocalID: metadata.assetLocalID,
                            filename: metadata.originalFilename,
                            reason: backupFailureReason(error)
                        )
                    }
                }
            }

            let initialConcurrency = min(
                UploadConcurrencyPolicy.recommendedConcurrency(
                    for: pendingAssets[pendingAssets.startIndex...],
                    maxAllowed: maxConcurrentUploads
                ),
                pendingAssets.count
            )
            for _ in 0..<initialConcurrency {
                enqueueNextUpload()
            }

            while let outcome = try await group.next() {
                try Task.checkCancellation()
                activeTaskCount = max(activeTaskCount - 1, 0)
                await onOutcome(outcome)

                let desiredConcurrency = UploadConcurrencyPolicy.recommendedConcurrency(
                    for: pendingAssets[nextIndex...],
                    maxAllowed: maxConcurrentUploads
                )
                while activeTaskCount < desiredConcurrency && nextIndex < pendingAssets.count {
                    enqueueNextUpload()
                }
            }
        }
    }
    
    private func currentDeviceInfo() -> DeviceInfo {
        DeviceInfo(
            deviceID: persistentDeviceID(),
            deviceName: UIDevice.current.name,
            platform: "iOS",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }

    private func persistentDeviceID() -> String {
        if let stored = try? keychainStore.loadDeviceID(), !stored.isEmpty {
            return stored
        }

        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        try? keychainStore.saveDeviceID(generated)
        return generated
    }

    private func resolveWithTimeout(_ endpoint: NWEndpoint) async throws -> URL {
        try await withThrowingTaskGroup(of: URL.self) { group in
            group.addTask {
                try await self.resolver.resolve(endpoint)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds timeout
                throw URLError(.timedOut)
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }

    func resolveReceiverURLForBackup(
        pairedReceiver: DiscoveredReceiver?,
        pairedReceiverID: String?,
        pairedReceiverName: String?,
        discoveredReceivers: [DiscoveredReceiver],
        storedReceiverURLString: String?
    ) async throws -> URL {
        // 1. First priority: Use the stored receiver URL (which is kept updated by Auto-Healing)
        if let storedReceiverURLString,
           let receiverURL = URL(string: storedReceiverURLString),
           !Self.isLinkLocalReceiverURL(receiverURL) {
            return receiverURL
        }

        // 2. Second priority: Resolve using the known paired receiver name directly via NetService
        if let pairedReceiverName {
            do {
                let serviceEndpoint = NWEndpoint.service(name: pairedReceiverName, type: "_icherri._tcp", domain: "local.", interface: nil)
                return try await resolveWithTimeout(serviceEndpoint)
            } catch {
                print("[resolveReceiverURL] Failed to resolve pairedReceiverName directly: \(error)")
            }
        }

        // 3. Third priority: Dynamically resolve Bonjour endpoints from active browse results
        if let pairedReceiver {
            do {
                return try await resolveWithTimeout(pairedReceiver.endpoint)
            } catch {
                print("[resolveReceiverURL] Failed to resolve pairedReceiver endpoint: \(error)")
            }
        }

        if let pairedReceiverID,
           let discoveredReceiver = discoveredReceivers.first(where: { $0.id == pairedReceiverID }) {
            do {
                return try await resolveWithTimeout(discoveredReceiver.endpoint)
            } catch {
                print("[resolveReceiverURL] Failed to resolve pairedReceiverID endpoint: \(error)")
            }
        }

        throw URLError(.cannotFindHost)
    }

    private static func isLinkLocalReceiverURL(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        let cleanHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return cleanHost.hasPrefix("fe80:")
    }

}

private func backupFailureReason(_ error: Error) -> String {
    let localizedDescription = error.localizedDescription
    if localizedDescription.contains("timed out") || localizedDescription.contains("시간 초과") {
        return "Mac 리시버와 연결할 수 없습니다. Mac의 iCherri 앱이 실행 중인지, 그리고 같은 Wi-Fi에 연결되어 있는지 확인해 주세요."
    }
    if localizedDescription.contains("Cannot find host") || localizedDescription.contains("Could not connect to the server") || localizedDescription.contains("호스트를 찾을 수") {
        return "백업 대상을 찾을 수 없습니다. 네트워크 설정을 확인해 주세요."
    }

    if let backupError = error as? BackupClientError {
        switch backupError {
        case .httpError(let statusCode, let data):
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let body, !body.isEmpty {
                return "HTTP \(statusCode): \(body)"
            }
            return "HTTP \(statusCode)."
        case .invalidResponse:
            return "Invalid server response."
        }
    }
    if let chunkError = error as? ChunkUploadError {
        switch chunkError {
        case .serverError(let statusCode):
            return "Chunk upload failed with HTTP \(statusCode)."
        case .streamError:
            return "Media stream could not be read."
        }
    }
    if let resumableError = error as? ResumableUploadError {
        switch resumableError {
        case .commitFailed(let status):
            return "Commit failed: \(status)."
        case .sessionExpired:
            return "Upload session expired."
        }
    }
    return localizedDescription
}

private actor BackupRunReconcileState {
    struct Counts: Sendable {
        let completed: Int
        let success: Int
        let duplicates: Int
        let failed: Int
        let overallBackedUpCount: Int
    }

    private let libraryAssetCount: Int
    private let runAssetCount: Int
    private let duplicateCount: Int
    private var uploadedAssetIDs: Set<String> = []
    private var failedAssetIDs: Set<String>
    private var receiverCompletedAssetCount: Int?

    init(libraryAssetCount: Int, runAssetCount: Int, duplicateCount: Int, failedAssetIDs: Set<String>) {
        self.libraryAssetCount = libraryAssetCount
        self.runAssetCount = runAssetCount
        self.duplicateCount = duplicateCount
        self.failedAssetIDs = failedAssetIDs
    }

    func recordSuccess(assetLocalID: String) -> Counts {
        uploadedAssetIDs.insert(assetLocalID)
        failedAssetIDs.remove(assetLocalID)
        return snapshotCounts()
    }

    func recordFailure(assetLocalID: String) -> Counts {
        failedAssetIDs.insert(assetLocalID)
        return snapshotCounts()
    }

    func setReceiverCompletedAssetCount(_ count: Int) {
        receiverCompletedAssetCount = count
    }

    func currentUploadedAssetIDs() -> Set<String> {
        uploadedAssetIDs
    }

    func snapshotCounts() -> Counts {
        let success = uploadedAssetIDs.count
        let failed = failedAssetIDs.count
        
        let overallBackedUpCount: Int
        if let receiverBackedUpCount = receiverCompletedAssetCount {
            overallBackedUpCount = receiverBackedUpCount + success
        } else {
            let alreadyBackedUpCount = max(libraryAssetCount - runAssetCount, 0)
            overallBackedUpCount = alreadyBackedUpCount + success + duplicateCount
        }
        
        return Counts(
            completed: success + duplicateCount + failed,
            success: success,
            duplicates: duplicateCount,
            failed: failed,
            overallBackedUpCount: overallBackedUpCount
        )
    }
}

private actor BackupUploadProgressCoordinator {
    private struct ActiveUploadState {
        var filename: String
        var sentBytes: Int64 = 0
        var totalBytes: Int64 = 0
        var bytesPerSecond: Double = 0
    }

    private let viewModel: BackupProgressViewModel
    private let totalExpectedBytes: Int64
    private let totalCount: Int
    private let throttleIntervalNanoseconds: UInt64 = 150_000_000
    private var currentFilename: String = "Preparing uploads..."
    private var acknowledgedBytes: Int64 = 0
    private var completed: Int = 0
    private var success: Int = 0
    private var duplicates: Int = 0
    private var failed: Int = 0
    private var overallBackedUpCount: Int  // 이미 백업된 파일 수를 초기값으로 받아 0부터 세는 버그를 제거
    private var activeUploads: [String: ActiveUploadState] = [:]
    private var failedUploads: [FailedUploadProgressItem] = []
    private var lastEmissionUptime: UInt64 = 0
    private var pendingEmissionTask: Task<Void, Never>?

    private var isBackground: Bool = false
    private var isObservingNotifications: Bool = false
    private var backgroundTask: Task<Void, Never>?
    private var foregroundTask: Task<Void, Never>?

    private var lastNonZeroSpeed: Double = 0
    private var lastSpeedUpdateTime = Date()

    init(viewModel: BackupProgressViewModel, totalExpectedBytes: Int64, totalCount: Int, initialOverallBackedUpCount: Int = 0) {
        self.viewModel = viewModel
        self.totalExpectedBytes = totalExpectedBytes
        self.totalCount = totalCount
        self.overallBackedUpCount = initialOverallBackedUpCount
    }

    deinit {
        // Since deinit is nonisolated, we cannot cancel actor properties directly.
        // Instead, the Task capturing [weak self] will automatically complete when self is released.
    }

    private func setBackground(_ isBg: Bool) {
        self.isBackground = isBg
    }

    private func startObservingNotificationsIfNeeded() {
        guard !isObservingNotifications else { return }
        isObservingNotifications = true
        
        Task { [weak self] in
            let initialBg = await MainActor.run { UIApplication.shared.applicationState == .background }
            await self?.setBackground(initialBg)
            
            let bgTask = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
                    await self?.setBackground(true)
                }
            }
            
            let fgTask = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification) {
                    await self?.setBackground(false)
                }
            }
            
            // Store reference inside actor context
            await self?.storeObservationTasks(bg: bgTask, fg: fgTask)
        }
    }

    private func storeObservationTasks(bg: Task<Void, Never>, fg: Task<Void, Never>) {
        self.backgroundTask = bg
        self.foregroundTask = fg
    }

    func beginAsset(assetLocalID: String, filename: String, expectedByteSize: Int64) {
        startObservingNotificationsIfNeeded()
        currentFilename = filename
        activeUploads[assetLocalID] = ActiveUploadState(
            filename: filename,
            totalBytes: max(expectedByteSize, 0)
        )
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond)
    }

    /// checkBatch 응답 수신 후 Mac DB SSOT 기준 완료 수로 베이스라인 보정
    func setInitialOverallBackedUpCount(_ count: Int) {
        self.overallBackedUpCount = count
    }

    func updateSnapshot(
        filename: String,
        completed: Int,
        success: Int,
        duplicates: Int,
        failed: Int,
        overallBackedUpCount: Int,
        phase: BackupProgressPhase,
        bytesPerSecond: Double
    ) {
        currentFilename = filename
        self.completed = completed
        self.success = success
        self.duplicates = duplicates
        self.failed = failed
        self.overallBackedUpCount = overallBackedUpCount
        pushUpdate(bytesPerSecond: bytesPerSecond, phase: phase, immediate: phase == .complete || phase == .failed)
    }

    func setInitialFailures(_ failures: [FailedUploadProgressItem]) {
        failedUploads = failures
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond, immediate: true)
    }

    func setAcknowledgedBytes(_ bytes: Int64) {
        acknowledgedBytes = max(bytes, 0)
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond)
    }

    func didSendBytes(assetLocalID: String, filename: String, totalSent: Int64, totalExpected: Int64, bytesPerSecond: Double) {
        currentFilename = filename
        activeUploads[assetLocalID] = ActiveUploadState(
            filename: filename,
            sentBytes: totalSent,
            totalBytes: totalExpected,
            bytesPerSecond: bytesPerSecond
        )
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond)
    }

    func finishAsset(
        assetLocalID: String,
        filename: String,
        completed: Int,
        success: Int,
        duplicates: Int,
        failed: Int,
        overallBackedUpCount: Int
    ) {
        currentFilename = filename
        if let state = activeUploads.removeValue(forKey: assetLocalID) {
            acknowledgedBytes += max(state.sentBytes, state.totalBytes)
        }
        self.completed = completed
        self.success = success
        self.duplicates = duplicates
        self.failed = failed
        self.overallBackedUpCount = overallBackedUpCount
        let phase: BackupProgressPhase = activeUploads.isEmpty && completed >= totalCount ? .complete : .uploading
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond, phase: phase, immediate: phase == .complete)
    }

    func recordFailure(assetLocalID: String, filename: String, reason: String) {
        failedUploads.removeAll { $0.id == assetLocalID || $0.id == "unsupported-\(assetLocalID)" }
        failedUploads.append(
            FailedUploadProgressItem(
                id: assetLocalID,
                filename: filename,
                reason: reason,
                retryAssetLocalID: assetLocalID
            )
        )
        failedUploads.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond, phase: .failed, immediate: true)
    }

    private var aggregateBytesPerSecond: Double {
        activeUploads.values.reduce(0) { $0 + $1.bytesPerSecond }
    }

    private func pushUpdate(
        bytesPerSecond: Double,
        phase: BackupProgressPhase = .uploading,
        immediate: Bool = false
    ) {
        if bytesPerSecond > 0 {
            lastNonZeroSpeed = bytesPerSecond
            lastSpeedUpdateTime = Date()
        }

        if immediate {
            pendingEmissionTask?.cancel()
            pendingEmissionTask = nil
            Task { await emitUpdate(bytesPerSecond: bytesPerSecond, phase: phase) }
            return
        }

        let currentThrottleInterval: UInt64 = isBackground ? 3_000_000_000 : 500_000_000

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = now &- lastEmissionUptime
        if lastEmissionUptime == 0 || elapsed >= currentThrottleInterval {
            pendingEmissionTask?.cancel()
            pendingEmissionTask = nil
            Task { await emitUpdate(bytesPerSecond: bytesPerSecond, phase: phase) }
            return
        }

        guard !isBackground else { return }

        guard pendingEmissionTask == nil else { return }
        let remaining = currentThrottleInterval - elapsed
        pendingEmissionTask = Task { [self] in
            try? await Task.sleep(nanoseconds: remaining)
            await emitPendingUpdate()
        }
    }

    private func emitPendingUpdate() async {
        pendingEmissionTask = nil
        await emitUpdate(bytesPerSecond: aggregateBytesPerSecond, phase: .uploading)
    }

    private func emitUpdate(bytesPerSecond: Double, phase: BackupProgressPhase) async {
        lastEmissionUptime = DispatchTime.now().uptimeNanoseconds
        let activeBytesSent = activeUploads.values.reduce(Int64(0)) { $0 + $1.sentBytes }
        let activeBytesTotal = activeUploads.values.reduce(Int64(0)) { $0 + $1.totalBytes }
        let activeUploadItems = activeUploads
            .map { assetLocalID, state in
                ActiveUploadProgressItem(
                    id: assetLocalID,
                    assetLocalID: assetLocalID,
                    filename: state.filename,
                    sentBytes: state.sentBytes,
                    totalBytes: state.totalBytes,
                    bytesPerSecond: state.bytesPerSecond
                )
            }
            .sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }

        let snapshotFilename = currentFilename
        let snapshotCompleted = completed
        let snapshotSuccess = success
        let snapshotDuplicates = duplicates
        let snapshotFailed = failed
        let snapshotOverallBackedUpCount = overallBackedUpCount
        let snapshotSentBytes = acknowledgedBytes + activeBytesSent
        let snapshotTotalBytes = max(totalExpectedBytes, acknowledgedBytes + activeBytesTotal)
        let snapshotActiveCount = activeUploads.count
        let snapshotFailedUploads = failedUploads
        let snapshotViewModel = viewModel

        // 5초 간의 속도 래치(Latch) 적용: 파일 간 전환 기 혹은 잠깐 업로드 정지 시 0으로 요동치는 방지
        let effectiveSpeed: Double
        if bytesPerSecond > 0 {
            effectiveSpeed = bytesPerSecond
        } else if Date().timeIntervalSince(lastSpeedUpdateTime) < 5.0 {
            effectiveSpeed = lastNonZeroSpeed
        } else {
            effectiveSpeed = 0
        }

        await MainActor.run {
            snapshotViewModel.update(
                filename: snapshotFilename,
                completed: snapshotCompleted,
                success: snapshotSuccess,
                duplicates: snapshotDuplicates,
                failed: snapshotFailed,
                overallBackedUpCount: snapshotOverallBackedUpCount,
                phase: phase,
                bytesPerSecond: effectiveSpeed,
                sentBytes: snapshotSentBytes,
                totalBytes: snapshotTotalBytes,
                activeUploads: snapshotActiveCount,
                activeUploadItems: activeUploadItems,
                failedUploadItems: snapshotFailedUploads
            )

            let formattedSpeed: String
            if effectiveSpeed > 0 {
                let mb = effectiveSpeed / (1024.0 * 1024.0)
                if mb >= 1.0 {
                    formattedSpeed = String(format: "%.1fM/s", mb)
                } else {
                    let kb = effectiveSpeed / 1024.0
                    formattedSpeed = String(format: "%.0fK/s", kb)
                }
            } else {
                formattedSpeed = "—"
            }

            let progressVal = totalCount > 0 ? Double(snapshotOverallBackedUpCount) / Double(totalCount) : 0.0

            let phaseText: String
            switch phase {
            case .scanning:
                phaseText = "라이브러리 스캔 중..."
            case .checking:
                phaseText = "해시파일 비교 중..."
            case .uploading:
                phaseText = "백업 전송 중"
            case .complete:
                phaseText = "백업 완료"
            case .failed:
                phaseText = "백업 실패"
            }

            if #available(iOS 16.2, *) {
                BackupLiveActivityManager.shared.update(
                    progress: progressVal,
                    completedCount: snapshotOverallBackedUpCount,
                    totalCount: totalCount,
                    formattedSpeed: formattedSpeed,
                    filename: snapshotFilename,
                    phaseText: phaseText
                )
            }
        }
    }
}

private enum UploadTaskOutcome: Sendable {
    case success(assetLocalID: String, filename: String)
    case failure(assetLocalID: String, filename: String, reason: String)
}

private enum BackupRunReconcileError: LocalizedError {
    case unresolvedAssets([String])
    case exceededRetryRounds([String])
    case reconcileRequired

    var errorDescription: String? {
        switch self {
        case .unresolvedAssets(let assetIDs):
            return "Receiver requested assets without local metadata: \(assetIDs.joined(separator: ", "))."
        case .exceededRetryRounds(let assetIDs):
            return "Receiver still reports missing assets after reconcile retries: \(assetIDs.joined(separator: ", "))."
        case .reconcileRequired:
            return "Local cache mismatch detected. Full reconcile required."
        }
    }
}

private actor AssetUploadProgressReporter: ChunkUploadProgressDelegate {
    private let assetLocalID: String
    private let filename: String
    private let coordinator: BackupUploadProgressCoordinator
    private var startedAt = Date()

    init(assetLocalID: String, filename: String, coordinator: BackupUploadProgressCoordinator) {
        self.assetLocalID = assetLocalID
        self.filename = filename
        self.coordinator = coordinator
    }

    func didSendBytes(_ bytes: Int64, totalSent: Int64, totalExpected: Int64) async {
        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        let bytesPerSecond = Double(totalSent) / elapsed
        await coordinator.didSendBytes(
            assetLocalID: assetLocalID,
            filename: filename,
            totalSent: totalSent,
            totalExpected: totalExpected,
            bytesPerSecond: bytesPerSecond
        )
    }
}

// MARK: - Live Activity / Dynamic Island Models

@available(iOS 16.2, *)
public struct BackupActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var completedCount: Int
        public var totalCount: Int
        public var formattedSpeed: String
        public var currentFilename: String?
        public var phaseText: String

        public init(
            progress: Double,
            completedCount: Int,
            totalCount: Int,
            formattedSpeed: String,
            currentFilename: String? = nil,
            phaseText: String = "백업 진행 중"
        ) {
            self.progress = progress
            self.completedCount = completedCount
            self.totalCount = totalCount
            self.formattedSpeed = formattedSpeed
            self.currentFilename = currentFilename
            self.phaseText = phaseText
        }
    }

    public let deviceName: String
    
    public init(deviceName: String) {
        self.deviceName = deviceName
    }
}

@available(iOS 16.2, *)
@MainActor
public final class BackupLiveActivityManager {
    public static let shared = BackupLiveActivityManager()
    private init() {}
    
    private var currentActivity: Activity<BackupActivityAttributes>?
    
    public func start(deviceName: String, completedCount: Int, totalCount: Int, phaseText: String = "라이브러리 스캔 중...") {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities are disabled by user or system.")
            return
        }
        
        stop()
        
        let attributes = BackupActivityAttributes(deviceName: deviceName)
        let initialState = BackupActivityAttributes.ContentState(
            progress: totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0,
            completedCount: completedCount,
            totalCount: totalCount,
            formattedSpeed: "—",
            phaseText: phaseText
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
            print("[LiveActivity] Started Activity ID: \(activity.id)")
        } catch {
            print("[LiveActivity] Failed to request Activity: \(error)")
        }
    }
    
    public func update(progress: Double, completedCount: Int, totalCount: Int, formattedSpeed: String, filename: String?, phaseText: String) {
        guard let activity = currentActivity else { return }
        
        let updatedState = BackupActivityAttributes.ContentState(
            progress: progress,
            completedCount: completedCount,
            totalCount: totalCount,
            formattedSpeed: formattedSpeed,
            currentFilename: filename,
            phaseText: phaseText
        )
        
        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
            print("[LiveActivity] Updated Activity: \(activity.id) (\(completedCount)/\(totalCount) - \(formattedSpeed))")
        }
    }
    
    public func stop() {
        guard let activity = currentActivity else { return }
        
        Task {
            let finalState = BackupActivityAttributes.ContentState(
                progress: 1.0,
                completedCount: activity.content.state.totalCount,
                totalCount: activity.content.state.totalCount,
                formattedSpeed: "Done",
                phaseText: "백업 완료"
            )
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(3.0)))
            self.currentActivity = nil
            print("[LiveActivity] Ended Activity: \(activity.id)")
        }
    }
}

// ObservedObject 기반의 실시간 렌더링 카드 뷰
struct ExpandedBackupCardView: View {
    @ObservedObject var progressViewModel: BackupProgressViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phaseTitle(for: progressViewModel.phase))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(phaseDescription(for: progressViewModel))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if progressViewModel.phase == .uploading {
                    Text(String(format: "%.1f%%", progressViewModel.progress * 100))
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundColor(.accentColor)
                } else if progressViewModel.phase == .complete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            // ⭐️ [요구사항 반영] 실시간 병렬 다중 전송 대형 썸네일 리스트 렌더링 (가로 스크롤 & 파일명 + 생성일자 제공!)
            if progressViewModel.phase == .uploading && !progressViewModel.activeUploads.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(progressViewModel.activeUploads) { upload in
                            ActiveUploadItemView(upload: upload)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if progressViewModel.phase == .uploading {
                // 업로드가 막 시작되어 activeUploads가 빌드되기 전에는 파일명 배지만 노출
                Text(progressViewModel.currentFilename ?? "준비 중...")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundColor(.accentColor.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor.opacity(0.15), lineWidth: 0.5)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 리퀴드 프로그레스 바
            LiquidProgressBar(
                progress: progressViewModel.phase == .complete ? 1.0 : ((progressViewModel.phase == .uploading || progressViewModel.phase == .scanning || progressViewModel.phase == .checking) ? progressViewModel.progress : 0.0),
                tint: progressViewModel.phase == .complete ? .green : .accentColor
            )
            .frame(height: 14)
            
            // 진행 상세 보조 지표 배지 그리드
            HStack(spacing: 12) {
                if progressViewModel.phase == .uploading {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("전송 속도")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                        Text(progressViewModel.formattedSpeed)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(progressViewModel.phase == .scanning ? "스캔 진행률" : (progressViewModel.phase == .checking ? "비교 진행률" : "백업 진행률"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(simulatedProgressText(for: progressViewModel))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
            }
        }
        .padding(20)
        .transition(.opacity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                )
                .shadow(color: .purple.opacity(0.08), radius: 15, y: 8)
        )
    }
    
    private func phaseTitle(for phase: BackupProgressPhase) -> String {
        switch phase {
        case .scanning: return "스캔 중"
        case .checking: return "해시파일 비교 중"
        case .uploading: return "전송 중"
        case .complete: return "완료"
        case .failed: return "실패"
        }
    }
    
    private func phaseDescription(for progressViewModel: BackupProgressViewModel) -> String {
        switch progressViewModel.phase {
        case .scanning: return "최근 촬영된 라이브러리 스캔 중…"
        case .checking: return "Mac 리시버의 해시 파일과 비교 중…"
        case .uploading: return "iPhone 사진 라이브러리 전송 중"
        case .complete:
            if progressViewModel.failedCount > 0 {
                return "백업 완료 (성공 \(progressViewModel.successCount)장, 실패 \(progressViewModel.failedCount)장)"
            } else if progressViewModel.successCount > 0 {
                return "새로운 사진 \(progressViewModel.successCount)장이 안전하게 백업되었습니다."
            } else {
                return "이미 최신 상태입니다. (중복 \(progressViewModel.duplicateCount)장)"
            }
        case .failed:
            if let error = progressViewModel.errorMessage {
                return "오류: \(error)"
            } else {
                return "백업 도중 오류가 발생했습니다."
            }
        }
    }
    
    private func simulatedProgressText(for progressViewModel: BackupProgressViewModel) -> String {
        return "\(progressViewModel.overallBackedUpCount) / \(progressViewModel.totalCount)"
    }
}

// ⭐️ [요구사항 반영] 파일별 미니 pbar 제거 및 파일명 - 생성일자 매핑을 지원하는 가로 72x72 스크롤 썸네일 카드 뷰
struct ActiveUploadItemView: View {
    let upload: ActiveUploadProgressItem
    @StateObject private var loader: AssetThumbnailLoader
    
    init(upload: ActiveUploadProgressItem) {
        self.upload = upload
        _loader = StateObject(wrappedValue: AssetThumbnailLoader(assetLocalID: upload.assetLocalID))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.18))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(upload.filename)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 72, alignment: .leading)
                
                Text(loader.creationDateText ?? "확인 중...")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 72, alignment: .leading)
            }
        }
        .task {
            await loader.loadIfNeeded()
        }
    }
}

struct BackupControlsView: View {
    @ObservedObject var viewModel: BackupDashboardViewModel
    @ObservedObject var progressViewModel: BackupProgressViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            if progressViewModel.isComplete {
                // 백업 완료 혹은 실패 상태 -> 확인(닫기) 버튼 노출
                Button(action: {
                    viewModel.activeBackupProgressViewModel = nil
                }) {
                    Label("확인", systemImage: "checkmark")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.green.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.25), lineWidth: 0.8)
                        )
                }
            } else if progressViewModel.canCancel {
                // 백업 진행 중일 때 -> 취소 버튼 노출
                Button(action: {
                    progressViewModel.cancel()
                }) {
                    Label("백업 취소", systemImage: "stop.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.red.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.25), lineWidth: 0.8)
                        )
                }
            }
        }
    }
}

struct ScrollBounceBehaviorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}



