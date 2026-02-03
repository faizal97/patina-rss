import SwiftUI

/// Data model for a command palette command
struct PaletteCommand: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let shortcut: String?
    let action: () -> Void
}

/// A row displaying a command in the command palette
struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Icon
                Image(systemName: command.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.Colors.accent)
                    .frame(width: 24)

                // Title and subtitle
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(command.title)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                }

                Spacer()

                // Shortcut
                if let shortcut = command.shortcut {
                    Text(shortcut)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textMuted)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .fill(DesignTokens.Colors.surfaceSubtle)
                        )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(backgroundColor)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return DesignTokens.Colors.accentSubtle
        }
        return isHovered ? DesignTokens.Colors.backgroundTertiary : .clear
    }
}
