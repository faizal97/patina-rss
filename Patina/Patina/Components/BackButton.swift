import SwiftUI

/// Back navigation button with chevron and optional label
struct BackButton: View {
    var label: String = "Back"
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .font(DesignTokens.Typography.bodySmall)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(isHovered ? DesignTokens.Colors.backgroundTertiary : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }

    private var foregroundColor: Color {
        isHovered ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.md) {
        BackButton(label: "Back") {}
        BackButton(label: "Feeds") {}
        BackButton(label: "All Unread") {}
    }
    .padding()
    .background(DesignTokens.Colors.backgroundSecondary)
}
