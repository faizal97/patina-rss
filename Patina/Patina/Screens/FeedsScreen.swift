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

#Preview {
    FeedsScreen()
        .environment(AppState())
        .environment(NavigationRouter())
        .frame(width: 400, height: 600)
}
