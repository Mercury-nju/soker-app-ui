import UIKit

/// Enterprise-only visual tokens. Keep the consumer app palette in BeanBase untouched.
enum ENTAppColors {
    static let pageBackground = UIColor(hex: 0xF0F0F4)
    static let chatUserBubble = UIColor(hex: 0xE8E8F0)
    static let chatComposerBorderGradient = [0x327DFF, 0x65B8FF, 0x8DC8FF, 0x327DFF].map { UIColor(hex: $0).cgColor }
    static let secondaryPageBackground = UIColor(hex: 0xF0F0F0)
    static let cardBackground = UIColor.white
    static let primary = UIColor(hex: 0x1D40A7)
    static let success = UIColor(hex: 0x628B6D)
    static let auxiliaryBackground = UIColor(hex: 0xD7DFEA)
    static let primaryText = UIColor.black
    static let secondaryText = UIColor.black.withAlphaComponent(0.6)
    static let tertiaryText = UIColor.black.withAlphaComponent(0.4)
    static let hex0000004D = UIColor(rgba: 0x0000004D)
    static let separator = UIColor.black.withAlphaComponent(0.1)
    static let controlBackground = UIColor.black.withAlphaComponent(0.04)
    static let actionSecondaryBackground = UIColor(hex: 0xEEEEEE)
    static let customerSearchBackground = UIColor(hex: 0xE8E7EC)
    static let cardBorder = UIColor.black.withAlphaComponent(0.02)
    static let cardShadow = UIColor.black.withAlphaComponent(0.025)
    static let reminderBackground = auxiliaryBackground
    static let reminderTag = primary
    static let reminderTitle = UIColor(hex: 0x111111)
    static let reminderDescription = UIColor(hex: 0x7A7A7A)
    static let error = UIColor(hex: 0xFF4737)
    static let hex2DBF43 = UIColor(hex: 0x2DBF43)
    static let hexFF4444 = UIColor(hex: 0xFF4444)

    static let theme = BeanAppTheme(
        primary: primary,
        primaryHex: "#1D40A7",
        blue: primary,
        primaryGradient: [primary, primary],
        selectionGradient: [primary, primary],
        primarySoft: primary.withAlphaComponent(0.1),
        primaryPale: primary.withAlphaComponent(0.1),
        accentShadow: primary.withAlphaComponent(0.25),
        secondaryGradient: [primary, primary.withAlphaComponent(0.1)],
        playbackHighlight: primary.withAlphaComponent(0.1),
        speakerColors: [
            primary,
            UIColor(hex: 0xE14420),
            UIColor(hex: 0x0088FF),
            UIColor.black,
            UIColor(hex: 0x6251FD),
            UIColor(hex: 0xD10074),
            UIColor(hex: 0x155DEE),
            UIColor(hex: 0xE2733A),
            UIColor(hex: 0x2A5086),
            UIColor(hex: 0x546E7A),
            UIColor(hex: 0x00897B)
        ]
    )
}
