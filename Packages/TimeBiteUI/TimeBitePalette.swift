import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum TimeBitePalette {
    static let blue = adaptive((0.15, 0.40, 0.65), (0.50, 0.72, 0.96))
    static let green = adaptive((0.20, 0.43, 0.28), (0.48, 0.80, 0.60))
    static let teal = adaptive((0.08, 0.43, 0.39), (0.45, 0.79, 0.73))
    static let sky = blue
    static let violet = adaptive((0.49, 0.33, 0.65), (0.78, 0.65, 0.96))
    static let gold = adaptive((0.48, 0.36, 0.10), (0.94, 0.80, 0.45))
    static let accentFill = Color(red: 0.08, green: 0.43, blue: 0.39)

    private static func adaptive(_ light: (Double, Double, Double),
                                 _ dark: (Double, Double, Double)) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
        #elseif canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
        #else
        return Color(red: dark.0, green: dark.1, blue: dark.2)
        #endif
    }

    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.07, blue: 0.11)
            : .white
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
            : Color(red: 0.36, green: 0.38, blue: 0.42)
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
    }

    static let amRingColor = sky
    static let pmRingColor = violet
    static let totalRingColor = teal
}
