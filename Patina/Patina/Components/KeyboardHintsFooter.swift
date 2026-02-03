import SwiftUI

/// Footer displaying keyboard shortcut hints
struct KeyboardHintsFooter: View {
    let hints: [(key: String, action: String)]

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                HStack(spacing: DesignTokens.Spacing.xs) {
                    KeyboardKey(hint.key)
                    Text(hint.action)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.Colors.backgroundSecondary)
    }
}

/// Visual representation of a keyboard key
struct KeyboardKey: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(DesignTokens.Typography.micro)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(DesignTokens.Colors.surfaceSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(DesignTokens.Colors.surfaceActive, lineWidth: 1)
            )
    }
}

#Preview {
    VStack {
        Spacer()

        KeyboardHintsFooter(hints: [
            ("j/k", "navigate"),
            ("↵", "open"),
            ("⎵", "toggle read"),
            ("⌘K", "palette")
        ])
    }
    .background(DesignTokens.Colors.backgroundPrimary)
}
