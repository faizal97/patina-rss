import SwiftUI

/// Generic header component for immersive screens
struct ScreenHeader<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Leading content (e.g., back button, icon)
            leading()

            // Title section
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(DesignTokens.Typography.headingMedium)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Trailing content (e.g., action buttons)
            trailing()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary)
    }
}

// MARK: - Convenience Initializers

extension ScreenHeader where Leading == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = { EmptyView() }
        self.trailing = trailing
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = { EmptyView() }
    }
}

extension ScreenHeader where Leading == EmptyView, Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.leading = { EmptyView() }
        self.trailing = { EmptyView() }
    }
}

#Preview {
    VStack(spacing: 0) {
        ScreenHeader(title: "Feeds", subtitle: "12 unread") {
            Image(systemName: "leaf.fill")
                .foregroundStyle(DesignTokens.Colors.accent)
        } trailing: {
            HeaderButton(icon: "plus") {}
            HeaderButton(icon: "arrow.clockwise") {}
        }

        Divider()

        Spacer()
    }
    .background(DesignTokens.Colors.backgroundPrimary)
}
