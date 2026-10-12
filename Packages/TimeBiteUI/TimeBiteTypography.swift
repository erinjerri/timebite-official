import SwiftUI
import CoreText

enum TimeBiteTypography {
    private static let registeredName: String = {
        guard let url = Bundle.module.url(forResource: "LeagueSpartan", withExtension: "ttf"),
              let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first,
              let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else {
            return "LeagueSpartan-Regular"
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        return name
    }()

    static func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        let size: CGFloat
        switch style {
        case .largeTitle: size = 34
        case .title: size = 28
        case .title2: size = 22
        case .title3: size = 20
        case .headline, .body: size = 17
        case .callout: size = 16
        case .subheadline: size = 15
        case .footnote: size = 13
        case .caption: size = 12
        case .caption2: size = 11
        @unknown default: size = 17
        }
        return .custom(registeredName, size: size, relativeTo: style).weight(weight)
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular,
                     relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(registeredName, size: size, relativeTo: style).weight(weight)
    }
}
