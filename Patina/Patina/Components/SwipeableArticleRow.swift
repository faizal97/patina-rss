import SwiftUI

/// A swipeable article row with hover, selection, and context menu support
struct SwipeableArticleRow: View {
    let article: Article
    let isSelected: Bool
    let onTap: () -> Void
    let onSwipeLeft: () -> Void

    @State private var isHovered = false
    @State private var dragOffset: CGFloat = 0
    @State private var showingSwipeAction = false

    private let swipeThreshold: CGFloat = -80

    var body: some View {
        ZStack(alignment: .trailing) {
            // Swipe action background
            if showingSwipeAction {
                HStack {
                    Spacer()
                    Image(systemName: article.isRead ? "circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignTokens.Colors.accent)
                        .padding(.trailing, DesignTokens.Spacing.lg)
                }
                .frame(maxHeight: .infinity)
                .background(DesignTokens.Colors.accentSubtle)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            }

            // Main row content
            articleContent
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow left swipe
                            if value.translation.width < 0 {
                                dragOffset = value.translation.width
                                showingSwipeAction = dragOffset < swipeThreshold / 2
                            }
                        }
                        .onEnded { value in
                            if dragOffset < swipeThreshold {
                                onSwipeLeft()
                            }
                            withAnimation(DesignTokens.Animation.spring) {
                                dragOffset = 0
                                showingSwipeAction = false
                            }
                        }
                )
        }
    }

    private var articleContent: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                // Title row with unread indicator
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    if !article.isRead {
                        Circle()
                            .fill(DesignTokens.Colors.unread)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                    } else {
                        Color.clear
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(article.title)
                            .font(article.isRead
                                ? DesignTokens.Typography.bodyLarge
                                : DesignTokens.Typography.bodyLarge.weight(.semibold))
                            .foregroundStyle(article.isRead
                                ? DesignTokens.Colors.textSecondary
                                : DesignTokens.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        // Metadata row
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            if let feedTitle = article.feedTitle {
                                Text(feedTitle)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                                Text("·")
                                    .foregroundStyle(DesignTokens.Colors.textMuted)
                            }

                            // Show date - use publishedAt if available, otherwise fetchedAt
                            Text(formatDate(article.publishedAt ?? article.fetchedAt))
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }

                        // Summary
                        if let summary = article.summary, !summary.isEmpty {
                            Text(summary)
                                .font(DesignTokens.Typography.bodySmall)
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                                .lineLimit(2)
                                .padding(.top, DesignTokens.Spacing.xxs)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(isSelected ? DesignTokens.Colors.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if article.isRead {
                Button("Mark as Unread") {
                    onSwipeLeft()
                }
            } else {
                Button("Mark as Read") {
                    onSwipeLeft()
                }
            }

            Divider()

            Button("Open in Browser") {
                if let url = URL(string: article.url) {
                    NSWorkspace.shared.open(url)
                }
            }

            Button("Copy Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(article.url, forType: .string)
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return DesignTokens.Colors.backgroundTertiary
        }
        return isHovered
            ? DesignTokens.Colors.backgroundTertiary
            : DesignTokens.Colors.backgroundSecondary
    }

    private func formatDate(_ timestamp: Int64) -> String {
        // Handle invalid timestamps
        guard timestamp > 0 else { return "" }

        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // For very recent articles (less than a minute), show "just now"
        if interval < 60 {
            return "just now"
        }

        // For articles less than an hour old, show minutes
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        }

        // For articles less than a day old, show hours
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }

        // For articles less than a week old, show days
        if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }

        // For older articles, use the standard formatter
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
