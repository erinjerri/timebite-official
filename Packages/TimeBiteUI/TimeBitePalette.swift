import SwiftUI

enum TimeBitePalette {
    static let blue = Color(red: 0.41, green: 0.68, blue: 0.98)
    static let green = Color(red: 0.43, green: 0.78, blue: 0.58)
    static let teal = Color(red: 0.59, green: 0.84, blue: 0.80)
    static let sky = Color(red: 0.66, green: 0.82, blue: 0.98)
    static let violet = Color(red: 0.80, green: 0.70, blue: 0.97)
    static let gold = Color(red: 0.96, green: 0.86, blue: 0.60)

    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.07, blue: 0.11)
            : Color(red: 0.97, green: 0.98, blue: 0.99)
    }

    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.09, green: 0.11, blue: 0.17)
            : .white
    }

    static func elevatedSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.16, blue: 0.23)
            : Color(red: 0.94, green: 0.96, blue: 0.99)
    }

    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.98, green: 0.98, blue: 0.99)
            : Color(red: 0.11, green: 0.13, blue: 0.17)
    }

    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.74, green: 0.76, blue: 0.80)
            : Color(red: 0.49, green: 0.51, blue: 0.56)
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        Color.black.opacity(colorScheme == .dark ? 0.26 : 0.08)
    }

    static func heroGlow(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [violet.opacity(0.14), sky.opacity(0.10), Color.clear]
                : [violet.opacity(0.08), sky.opacity(0.08), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let amRingColor = sky
    static let pmRingColor = violet
    static let totalRingColor = teal
}
