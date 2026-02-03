import SwiftUI

/// Centralized design tokens for the Patina design system
enum DesignTokens {

    // MARK: - Colors
    enum Colors {
        // Background hierarchy (deepest to surface)
        static let backgroundPrimary = Color(hex: "#0D0F12")
        static let backgroundSecondary = Color(hex: "#141619")
        static let backgroundTertiary = Color(hex: "#1A1D21")
        static let backgroundElevated = Color(hex: "#22262B")

        // Surface colors
        static let surfaceSubtle = Color(hex: "#2A2F36")
        static let surfaceActive = Color(hex: "#353B44")

        // Text hierarchy
        static let textPrimary = Color(hex: "#F2F4F7")
        static let textSecondary = Color(hex: "#9BA3AF")
        static let textTertiary = Color(hex: "#6B7280")
        static let textMuted = Color(hex: "#4B5563")

        // Accent (sage green)
        static let accent = Color(hex: "#53A27C")
        static let accentSubtle = Color(hex: "#53A27C").opacity(0.15)
        static let accentHover = Color(hex: "#68B891")

        // Semantic
        static let unread = Color(hex: "#53A27C")
        static let success = Color(hex: "#34D399")
        static let warning = Color(hex: "#FBBF24")
        static let error = Color(hex: "#F87171")

        // Pattern chips
        static let chipTopic = Color(hex: "#60A5FA")
        static let chipKeyword = Color(hex: "#34D399")
        static let chipExcluded = Color(hex: "#F87171")
    }

    // MARK: - Typography
    enum Typography {
        static let displayLarge = Font.system(size: 32, weight: .bold)
        static let displayMedium = Font.system(size: 24, weight: .semibold)
        static let headingLarge = Font.system(size: 20, weight: .semibold)
        static let headingMedium = Font.system(size: 17, weight: .semibold)
        static let headingSmall = Font.system(size: 15, weight: .medium)
        static let bodyLarge = Font.system(size: 15, weight: .regular)
        static let bodyMedium = Font.system(size: 14, weight: .regular)
        static let bodySmall = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
        static let captionMedium = Font.system(size: 12, weight: .medium)
        static let micro = Font.system(size: 11, weight: .regular)
    }

    // MARK: - Spacing (8pt grid)
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    // MARK: - Animation
    enum Animation {
        static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeOut(duration: 0.25)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
