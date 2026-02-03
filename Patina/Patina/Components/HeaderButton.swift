import SwiftUI

/// Standard 32x32 icon button for screen headers with hover state
struct HeaderButton: View {
    let icon: String
    var isActive: Bool = false
    var activeColor: Color = DesignTokens.Colors.accent
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(foregroundColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(backgroundColor)
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
        if isActive {
            return activeColor
        }
        return isHovered ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary
    }

    private var backgroundColor: Color {
        isHovered ? DesignTokens.Colors.backgroundTertiary : .clear
    }
}

#Preview {
    HStack(spacing: DesignTokens.Spacing.sm) {
        HeaderButton(icon: "plus") {}
        HeaderButton(icon: "arrow.clockwise") {}
        HeaderButton(icon: "circle.fill", isActive: true, activeColor: DesignTokens.Colors.unread) {}
        HeaderButton(icon: "gearshape") {}
    }
    .padding()
    .background(DesignTokens.Colors.backgroundSecondary)
}
