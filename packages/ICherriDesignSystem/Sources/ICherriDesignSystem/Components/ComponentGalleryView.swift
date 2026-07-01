import SwiftUI

public struct ComponentGalleryView: View {
    @State private var sampleProgress: Double = 0.45
    @State private var useAlternatingColors: Bool = false
    @State private var isGlowBadgePulse: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    // 안 1 시뮬레이션용 상태 변수
    @State private var isBackingUpSimulated: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
                // MARK: - 안 1. 단일 대화형 대시보드 프로토타입 시뮬레이터
                Section(header: Text("안 1. 단일 대화형 대시보드 (Unified Dashboard Prototype)")) {
                    VStack(spacing: 20) {
                        Text("실제 백업 시작 시 디스크가 팽창하는 Morphing 애니메이션을 시뮬레이션합니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 디스크 & 카드 Morphing 컨테이너
                        VStack {
                            if !isBackingUpSimulated {
                                // 1. 평소 상태: 원형 디스크 (Glassmorphism Disc)
                                VStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 8, height: 8)
                                        Text("Online")
                                            .font(.caption2.weight(.bold))
                                            .foregroundColor(.green)
                                    }
                                    
                                    Text("Yangeok-Mac")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                    
                                    Text("최근 백업: 3시간 전")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .transition(.scale.combined(with: .opacity))
                                .frame(width: 150, height: 150)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                        )
                                        .shadow(color: .blue.opacity(0.15), radius: 10, y: 5)
                                )
                            } else {
                                // 2. 백업 중 상태: 팽창된 대형 액션 카드 (Expanded Status Card)
                                VStack(spacing: 16) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("백업 전송 중…")
                                                .font(.headline)
                                            Text("iPhone 사진 라이브러리 전송 중")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(String(format: "%.1f%%", sampleProgress * 100))
                                            .font(.system(.title3, design: .rounded, weight: .black))
                                            .foregroundColor(.accentColor)
                                    }
                                    
                                    // 물결 쉬머가 장착된 리퀴드 프로그레스 바
                                    LiquidProgressBar(progress: sampleProgress)
                                        .frame(height: 16)
                                    
                                    // 진행 상세 보조 지표 배지 그리드
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("속도")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text("14.5 MB/s")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("완료 항목")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text("19,082 / 20,000")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .padding(20)
                                .transition(.scale.combined(with: .opacity))
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                        )
                                        .shadow(color: .purple.opacity(0.1), radius: 12, y: 6)
                                )
                            }
                        }
                        .frame(height: 190) // 레이아웃 흔들림 방지를 위한 최소 높이 락
                        .animation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0), value: isBackingUpSimulated)
                        .background(
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
                            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isBackingUpSimulated)
                        )
                        
                        // 제어 스위치
                        Button(action: {
                            isBackingUpSimulated.toggle()
                        }) {
                            Label(
                                isBackingUpSimulated ? "시뮬레이션 종료 (일시정지)" : "백업 시작 시뮬레이션",
                                systemImage: isBackingUpSimulated ? "pause.fill" : "play.fill"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isBackingUpSimulated ? .red : .accentColor)
                    }
                    .padding(.vertical, 10)
                }
                
                // MARK: - 기존 개별 컴포넌트 Controls
                Section(header: Text("Interactive Playground (Controls)")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("조작판 (Adjust Components)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Progress:")
                            Slider(value: $sampleProgress, in: 0...1.0)
                            Text(String(format: "%.0f%%", sampleProgress * 100))
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 45, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Liquid Progress Bar")) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("기본 틴트 컬러 (Blue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        LiquidProgressBar(progress: sampleProgress)
                        
                        Text("성공 컬러 (Green)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        LiquidProgressBar(progress: sampleProgress, tint: .green)
                        
                        Text("경고 컬러 (Orange)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        LiquidProgressBar(progress: sampleProgress, tint: .orange)
                        
                        Text("커스텀 큰 높이 (Height: 24)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        LiquidProgressBar(progress: sampleProgress, height: 24, tint: .purple)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Glow Badge")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            GlowBadge(label: "완료 파일", value: "1,248개", color: .blue)
                            GlowBadge(label: "전송 속도", value: "14.2 MB/s", color: .green)
                            GlowBadge(label: "실패 항목", value: "3개", color: .red)
                            GlowBadge(label: "남은 용량", value: "24.8 GB", color: .purple)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 2)
                    }
                }
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
}

#Preview {
    ComponentGalleryView()
}
