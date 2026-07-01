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
            .frame(height: 190)
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: isBackingUpSimulated)
            .background(morphingBackgroundGlow)
            
            triggerAndControls
        }
        .padding()
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(20)
    }
    
    private var defaultDiscView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Online")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text(selectedMacReceiver)
                .font(.system(.headline, design: .rounded, weight: .bold))
            
            Text("최근 백업: 3시간 전")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .transition(.scale.combined(with: .opacity))
        .frame(width: 160, height: 160)
        .background(
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                )
                .shadow(color: .blue.opacity(0.12), radius: 12, y: 6)
        )
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
            } else {
                // ⭐️ [iOS 26 디자인 언어 반영] 로즈골드 보더 글래스 버튼
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
            Text("설정 및 기기 연결 상태 (2열 그리드)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
                
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
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
                
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
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
                
                // 연결 기기 선택 카드
                VStack(alignment: .leading, spacing: 8) {
                    Label("백업 대상", systemImage: "macbook.and.iphone")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Text(selectedMacReceiver)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("🟢 Online")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.green)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
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
}

#Preview {
    ComponentGalleryView()
}
