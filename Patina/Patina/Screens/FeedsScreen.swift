import SwiftUI

/// Immersive feeds list screen - the home view
struct FeedsScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ScreenHeader(title: "Patina") {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.accent)
            } trailing: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    HeaderButton(icon: "plus") {
                        appState.showAddFeedSheet = true
                    }
                    .help("Add Feed (⌘N)")

                    HeaderButton(icon: "arrow.clockwise") {
                        Task { await appState.refreshAllFeeds() }
                    }
                    .help("Refresh All (⌘R)")

                    HeaderButton(icon: "command") {
                        router.openCommandPalette()
                    }
                    .help("Command Palette (⌘K)")
                }
            }

            Divider()
                .background(DesignTokens.Colors.surfaceSubtle)

            // Feed list
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.xs) {
                    // Smart feeds section
                    Section {
                        SmartFeedRow(
                            icon: "tray.full.fill",
                            title: "All Unread",
                            count: appState.totalUnreadCount
                        ) {
                            router.push(.articles(feedId: -1, feedTitle: "All Unread"))
                            Task { await appState.loadAllUnreadArticles() }
                        }

                        SmartFeedRow(
                            icon: "sparkles",
                            title: "Serendipity",
                            count: nil
                        ) {
                            router.push(.articles(feedId: -2, feedTitle: "Serendipity"))
                            Task { await appState.loadSerendipityArticles() }
                        }

                        SmartFeedRow(
                            icon: "clock.fill",
                            title: "Recent",
                            count: nil
                        ) {
                            router.push(.articles(feedId: -3, feedTitle: "Recent"))
                            Task { await appState.loadRecentArticles() }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.top, DesignTokens.Spacing.md)

                    // Feeds section
                    if !appState.feeds.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("FEEDS")
                                .font(DesignTokens.Typography.captionMedium)
                                .foregroundStyle(DesignTokens.Colors.textMuted)
                                .padding(.horizontal, DesignTokens.Spacing.md)
                                .padding(.top, DesignTokens.Spacing.lg)

                            ForEach(appState.feeds, id: \.id) { feed in
                                FeedListRow(feed: feed) {
                                    router.push(.articles(feedId: feed.id, feedTitle: feed.title))
                                    appState.selectedFeedId = feed.id
                                    Task { await appState.loadArticlesForSelectedFeed() }
                                }
                            }
                            .padding(.horizontal, DesignTokens.Spacing.md)
                        }
                    }

                    Spacer(minLength: DesignTokens.Spacing.xxl)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignTokens.Colors.backgroundPrimary)

            Divider()
                .background(DesignTokens.Colors.surfaceSubtle)

            // Footer with keyboard hints
            KeyboardHintsFooter(hints: [
                ("⌘K", "palette"),
                ("⌘N", "add feed"),
                ("⌘R", "refresh")
            ])
        }
        .background(DesignTokens.Colors.backgroundPrimary)
        .task {
            await appState.loadFeeds()
        }
    }
}

// MARK: - Smart Feed Row

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

// MARK: - Feed List Row

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

#Preview {
    FeedsScreen()
        .environment(AppState())
        .environment(NavigationRouter())
        .frame(width: 400, height: 600)
}
