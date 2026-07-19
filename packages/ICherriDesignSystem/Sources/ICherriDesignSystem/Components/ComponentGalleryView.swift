import SwiftUI

public struct ComponentGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 시뮬레이션용 상태 변수
    @State private var isBackingUpSimulated: Bool = false
    @State private var sampleProgress: Double = 0.45
    @State private var simulatedPhase: SimulatedBackupPhase = .uploading
    
    // 설정/권한 가상 상태 변수
    @State private var isAutoBackupEnabled: Bool = true
    @State private var photoPermissionGranted: Bool = true
    @State private var localNetworkGranted: Bool = true
    @State private var selectedMacReceiver: String = "Yangeok-Mac"
    @State private var isScanningReceiversSimulated: Bool = false
    
    enum SimulatedBackupPhase: String, CaseIterable, Identifiable {
        case scanning = "스캔 중"
        case checking = "백업 확인 중"
        case uploading = "전송 중"
        case complete = "완료"
        
        var id: String { self.rawValue }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    simulatorSection
                    
                    if !isBackingUpSimulated {
                        settingsGridSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Component Gallery")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews (컴파일러 타입 추론 과부하 방지를 위한 분할)
    
    private var simulatorSection: some View {
        VStack(spacing: 20) {
            Text("안 1. 단일 대화형 대시보드 (Unified Dashboard Prototype)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 디스크 & 카드 Morphing 컨테이너
            VStack {
                if !isBackingUpSimulated {
                    defaultDiscView
                } else {
                    expandedCardView
                }
            }
            .frame(height: isBackingUpSimulated ? 270 : 190) // 썸네일 리스트 추가로 인한 가변 높이 확장
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: isBackingUpSimulated)
            .background(morphingBackgroundGlow)
            
            triggerAndControls
        }
        .padding()
        .modifier(GalleryGlassContainerModifier())
    }
    
    private var defaultDiscView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                if selectedMacReceiver == "선택 안 됨" {
                    Circle()
                        .fill(.gray)
                        .frame(width: 8, height: 8)
                    Text("연결 없음")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(.gray)
                } else {
                    Circle()
                        .fill(selectedMacReceiver == "Office-Mini" ? .orange : .green)
                        .frame(width: 8, height: 8)
                    Text(selectedMacReceiver == "Office-Mini" ? "Offline" : "Online")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(selectedMacReceiver == "Office-Mini" ? .orange : .green)
                }
            }
            
            Text(selectedMacReceiver)
                .font(.system(.headline, design: .rounded, weight: .bold))
            
            Text(selectedMacReceiver == "선택 안 됨" ? "기기를 먼저 등록해 주세요" : "최근 백업: 3시간 전")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .transition(.scale.combined(with: .opacity))
        .frame(width: 160, height: 160)
        .modifier(GalleryGlassCircleModifier())
    }
    
    private var expandedCardView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(simulatedPhase.rawValue)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(simulatedPhaseDescription)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if simulatedPhase == .uploading {
                    Text(String(format: "%.1f%%", sampleProgress * 100))
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundColor(.accentColor)
                } else if simulatedPhase == .complete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            // ⭐️ [요구사항 반영] 실시간 병렬 다중 전송 썸네일 리스트 렌더링!
            if simulatedPhase == .uploading {
                HStack(spacing: 10) {
                    ForEach(0..<3) { idx in
                        VStack(alignment: .leading, spacing: 4) {
                            // 썸네일 가상 이미지 뷰 (Glassmorphism & Shimmer 느낌)
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.1 + Double(idx) * 0.05),
                                        Color.purple.opacity(0.15 - Double(idx) * 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                
                                Image(systemName: idx % 2 == 0 ? "photo.fill" : "video.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .frame(width: 54, height: 54)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
                            )
                            
                            // 파일명 텍스트
                            Text(simulatedConcurrentFilename(index: idx))
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(width: 54)
                            
                            // 미니 진행바 (병렬 전송 상태 연동)
                            ProgressView(value: min(1.0, max(0.0, sampleProgress + Double(idx) * 0.15 - 0.1)))
                                .progressViewStyle(.linear)
                                .scaleEffect(x: 1, y: 0.5, anchor: .center)
                                .tint(.accentColor)
                        }
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // 리퀴드 프로그레스 바
            LiquidProgressBar(
                progress: simulatedPhase == .complete ? 1.0 : (simulatedPhase == .uploading ? sampleProgress : 0.0),
                tint: simulatedPhase == .complete ? .green : .accentColor
            )
            .frame(height: 14)
            
            // 진행 상세 보조 지표 배지 그리드
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("전송 속도")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(simulatedPhase == .uploading ? "14.5 MB/s" : "—")
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
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("백업 진행률")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(simulatedProgressText)
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
        .transition(.scale.combined(with: .opacity))
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
    
    private var morphingBackgroundGlow: some View {
        ZStack {
            if !isBackingUpSimulated {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .blur(radius: 20)
            } else {
                RoundedRectangle(cornerRadius: 30)
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blur(radius: 25)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: isBackingUpSimulated)
    }
    
    private var triggerAndControls: some View {
        VStack(spacing: 12) {
            if !isBackingUpSimulated {
                Button(action: {
                    isBackingUpSimulated = true
                }) {
                    Label("백업 시작", systemImage: "arrow.up.to.line.compact")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(selectedMacReceiver == "선택 안 됨" || selectedMacReceiver == "Office-Mini")
            } else {
                Button(action: {
                    isBackingUpSimulated = false
                }) {
                    Label("백업 취소 / 일시정지", systemImage: "stop.fill")
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
            
            if isBackingUpSimulated {
                VStack(alignment: .leading, spacing: 8) {
                    Text("단계 시뮬레이터 (Phase Selector)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                    
                    Picker("Simulated Phase", selection: $simulatedPhase) {
                        ForEach(SimulatedBackupPhase.allCases) { phase in
                            Text(phase.rawValue).tag(phase)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if simulatedPhase == .uploading {
                        HStack {
                            Text("진행률 제어:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Slider(value: $sampleProgress, in: 0...1.0)
                            Text(String(format: "%.0f%%", sampleProgress * 100))
                                .font(.system(.caption, design: .monospaced))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var settingsGridSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("설정 및 기기 연결 상태 (2열 그리드)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if isScanningReceiversSimulated {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // 자동 백업 카드
                VStack(alignment: .leading, spacing: 8) {
                    Label("자동 백업", systemImage: "bolt.badge.aod")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Toggle("", isOn: $isAutoBackupEnabled)
                        .labelsHidden()
                        .tint(.accentColor)
                    
                    Text("배터리 20% + Wi-Fi 조건")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(GalleryGlassCardModifier())
                
                // 사진 권한 카드
                VStack(alignment: .leading, spacing: 8) {
                    Label("사진 라이브러리", systemImage: "photo.fill")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(photoPermissionGranted ? "허용됨" : "차단됨")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundColor(photoPermissionGranted ? .green : .red)
                        Spacer()
                        Image(systemName: photoPermissionGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(photoPermissionGranted ? .green : .red)
                    }
                    
                    Text("라이브러리 접근 허가")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(GalleryGlassCardModifier())
                
                // 로컬 네트워크 카드
                VStack(alignment: .leading, spacing: 8) {
                    Label("로컬 네트워크", systemImage: "network")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(localNetworkGranted ? "허용됨" : "차단됨")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundColor(localNetworkGranted ? .green : .red)
                        Spacer()
                        Image(systemName: localNetworkGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(localNetworkGranted ? .green : .red)
                    }
                    
                    Text("주변 Mac 탐색 허가")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(GalleryGlassCardModifier())
                
                // ⭐️ [요구사항 완벽 반영] 백업 대상 카드에 스캔(Refresh) 및 잊기(Forget) 기능을 유기적으로 통합한 다기능 Menu!
                Menu {
                    Section("감지된 기기 (자동 탐색 완료)") {
                        Button("Yangeok-Mac (🟢 Online)") { selectedMacReceiver = "Yangeok-Mac" }
                        Button("Minyoung-Mac (🟢 Online)") { selectedMacReceiver = "Minyoung-Mac" }
                        Button("Office-Mini (🟠 Offline)") { selectedMacReceiver = "Office-Mini" }
                        Button("Studio-Pro (🟢 Online)") { selectedMacReceiver = "Studio-Pro" }
                    }
                    
                    Section("제어 및 해제") {
                        // 수동 기기 탐색 시뮬레이션
                        Button(action: {
                            isScanningReceiversSimulated = true
                            Task {
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                isScanningReceiversSimulated = false
                            }
                        }) {
                            Label("주변 기기 새로고침 (Refresh)", systemImage: "arrow.clockwise")
                        }
                        
                        // 기기 연결 해제
                        Button(role: .destructive, action: {
                            selectedMacReceiver = "선택 안 됨"
                        }) {
                            Label("이 기기 연결 끊기 (Forget)", systemImage: "trash")
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
                        
                        Text(selectedMacReceiver)
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if selectedMacReceiver == "선택 안 됨" {
                            Text("연결 없음")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.gray)
                        } else {
                            Text(selectedMacReceiver == "Office-Mini" ? "🟠 Offline" : "🟢 Online")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(selectedMacReceiver == "Office-Mini" ? .orange : .green)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(GalleryGlassCardModifier())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 도움말 보조 문자열 계산
    private var simulatedPhaseDescription: String {
        switch simulatedPhase {
        case .scanning:
            return "최근 촬영된 라이브러리 스캔 중…"
        case .checking:
            return "Mac 리시버의 해시 파일과 비교 중…"
        case .uploading:
            return "iPhone 사진 라이브러리 전송 중"
        case .complete:
            return "모든 사진이 Mac에 동기화되었습니다."
        }
    }
    
    private var simulatedProgressText: String {
        switch simulatedPhase {
        case .scanning, .checking:
            return "계산 중…"
        case .uploading:
            let completed = Int(Double(20000) * sampleProgress)
            return "\(completed) / 20,000"
        case .complete:
            return "20,000 / 20,000"
        }
    }
    
    // ⭐️ [요구사항 반영] 다중 병렬 전송 썸네일용 개별 파일명 계산
    private func simulatedConcurrentFilename(index: Int) -> String {
        let baseIndex = Int(sampleProgress * 100) + 1024 + index
        let isVideo = baseIndex % 3 == 0
        return isVideo ? "MV_\(baseIndex).mp4" : "IMG_\(idxStr(baseIndex)).heic"
    }
    
    private func idxStr(_ val: Int) -> String {
        return "\(val)"
    }
}

// MARK: - Liquid Glass ViewModifiers (Gallery-local)

private struct GalleryGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
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

private struct GalleryGlassContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
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

private struct GalleryGlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
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

#Preview {
    ComponentGalleryView()
}
