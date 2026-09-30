import SwiftUI

public struct ActivityRingView: View {
    public let progress: Double
    public let label: String
    public let secondaryLabel: String?
    public let accentColor: Color
    public let lineWidth: CGFloat

    public init(
        progress: Double,
        label: String,
        secondaryLabel: String? = nil,
        accentColor: Color = .accentColor,
        lineWidth: CGFloat = 12
    ) {
        self.progress = min(1, max(0, progress.isFinite ? progress : 0))
        self.label = label
        self.secondaryLabel = secondaryLabel
        self.accentColor = accentColor
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.14), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle().trim(from: 0, to: progress)
                .stroke(accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)

            VStack(spacing: 4) {
                Text(label)
                    .font(TimeBiteTypography.font(.headline, weight: .semibold))
                    .monospacedDigit()
                if let secondaryLabel {
                    Text(secondaryLabel)
                        .font(TimeBiteTypography.font(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
