import SwiftUI

/// A row for smart feeds (All Unread, Serendipity, Recent)
struct SmartFeedRow: View {
    let icon: String
    let title: String
    let count: Int32?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(DesignTokens.Colors.accent)
                    .frame(width: 24)

                // Title
                Text(title)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Spacer()

                // Count badge
                if let count, count > 0 {
                    Text("\(count)")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundStyle(DesignTokens.Colors.backgroundPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(DesignTokens.Colors.accent)
                        .clipShape(Capsule())
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textMuted)
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(isHovered
                        ? DesignTokens.Colors.backgroundTertiary
                        : DesignTokens.Colors.backgroundSecondary)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

/// A row for displaying a feed in the feeds list
struct FeedListRow: View {
    let feed: Feed
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Feed icon
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(DesignTokens.Colors.surfaceSubtle)
                        .frame(width: 28, height: 28)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }

                // Feed info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(feed.title)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    if let siteUrl = feed.siteUrl {
                        Text(siteUrl)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Unread count
                if feed.unreadCount > 0 {
                    Text("\(feed.unreadCount)")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundStyle(DesignTokens.Colors.accent)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(DesignTokens.Colors.accentSubtle)
                        .clipShape(Capsule())
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textMuted)
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(isHovered
                        ? DesignTokens.Colors.backgroundTertiary
                        : DesignTokens.Colors.backgroundSecondary)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Refresh") {
                Task { await AppState().refreshFeed(feed.id) }
            }

            Divider()

            Button("Delete", role: .destructive) {
                Task { await AppState().deleteFeed(feed.id) }
            }
        }
    }
}
