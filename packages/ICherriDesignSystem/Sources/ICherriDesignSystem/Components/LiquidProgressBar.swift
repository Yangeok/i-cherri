import SwiftUI

// Liquid Glass-inspired animated progress bar for iOS 26 / macOS Tahoe aesthetics.
public struct LiquidProgressBar: View {
    public let progress: Double
    public var height: CGFloat = 14
    public var tint: Color = .accentColor

    @State private var shimmerOffset: CGFloat = -200

    public init(progress: Double, height: CGFloat = 14, tint: Color = .accentColor) {
        self.progress = progress
        self.height = height
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2)
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )

                // Fill with shimmer
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(fillGradient)
                    .frame(width: max(0, geo.size.width * progress))
                    .overlay(shimmerOverlay(width: geo.size.width))
                    .clipShape(RoundedRectangle(cornerRadius: height / 2))
            }
        }
        .frame(height: height)
        .onAppear { animateShimmer() }
        .onChange(of: progress) { _ in animateShimmer() }
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.85), tint],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func shimmerOverlay(width: CGFloat) -> some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.4), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 80)
        .offset(x: shimmerOffset)
        .blendMode(.screen)
        .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: shimmerOffset)
    }

    private func animateShimmer() {
        shimmerOffset = -80
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            shimmerOffset = 300
        }
    }
}

// Dynamic gradient glow badge used in summary screens.
public struct GlowBadge: View {
    public let label: String
    public let value: String
    public var color: Color = .accentColor

    public init(label: String, value: String, color: Color = .accentColor) {
        self.label = label
        self.value = value
        self.color = color
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.3), radius: 8, y: 4)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        LiquidProgressBar(progress: 0.65)
            .padding(.horizontal)
        HStack(spacing: 16) {
            GlowBadge(label: "Success", value: "142", color: .green)
            GlowBadge(label: "Duplicate", value: "12", color: .orange)
            GlowBadge(label: "Failed", value: "1", color: .red)
        }
    }
    .padding()
}
#endif
