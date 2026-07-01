import SwiftUI

public struct ComponentGalleryView: View {
    @State private var sampleProgress: Double = 0.45
    @State private var useAlternatingColors: Bool = false
    @State private var isGlowBadgePulse: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
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
                
                Section(header: Text("Design Guidelines")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Liquid Glass 효과", systemImage: "sparkles")
                            .font(.headline)
                        Text("iCherri의 컴포넌트는 반투명 블러(.ultraThinMaterial)와 미세한 화이트 테두리, 그리고 애니메이션되는 쉬머(Shimmer) 하이라이트를 결합하여 차세대 프리미엄 감성을 표현합니다.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Component Gallery")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        // 모달 닫기 등을 위한 플레이스홀더
                    }
                }
            }
        }
    }
}

#Preview {
    ComponentGalleryView()
}
