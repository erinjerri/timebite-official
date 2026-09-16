import SwiftUI

public struct ActivityRingView: View {
    public let progress: Double
    public let label: String

    public init(progress: Double, label: String) {
        self.progress = min(1, max(0, progress.isFinite ? progress : 0))
        self.label = label
    }

    public var body: some View {
        ZStack {
            Circle().stroke(Color.accentColor.opacity(0.15), lineWidth: 12)
            Circle().trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label).font(.headline).monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
