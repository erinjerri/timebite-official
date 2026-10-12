import SwiftUI

enum TimeBiteTypography {
    static func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        switch style {
        case .largeTitle, .title, .title2, .title3, .headline:
            return .system(style, design: .serif).weight(.medium)
        case .caption, .caption2:
            return .system(style, design: .monospaced).weight(weight)
        default:
            return .system(style).weight(weight)
        }
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular,
                     relativeTo style: Font.TextStyle = .body) -> Font {
        font(style, weight: weight)
    }
}
