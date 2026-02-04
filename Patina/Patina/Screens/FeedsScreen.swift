import SwiftUI

/// Immersive feeds list screen - the home view
struct FeedsScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router

    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredFeeds: [Feed] {
        if searchText.isEmpty {
            return appState.feeds
        }
        return appState.feeds.filter { feed in
            feed.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ScreenHeader(title: "Patina") {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.accent)
            } trailing: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    HeaderButton(icon: "magnifyingglass") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearching.toggle()
                            if isSearching {
                                isSearchFocused = true
                            } else {
                                searchText = ""
                            }
                        }
                    }
                    .help("Search Feeds (⌘F)")

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

            // Search field (when active)
            if isSearching {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)

                    TextField("Filter feeds...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .focused($isSearchFocused)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundSecondary)
                .transition(.move(edge: .top).combined(with: .opacity))
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

                            if filteredFeeds.isEmpty && !searchText.isEmpty {
                                Text("No feeds matching \"\(searchText)\"")
                                    .font(DesignTokens.Typography.bodyMedium)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .padding(.horizontal, DesignTokens.Spacing.md)
                                    .padding(.vertical, DesignTokens.Spacing.lg)
                            } else {
                                ForEach(filteredFeeds, id: \.id) { feed in
                                    FeedListRow(feed: feed) {
                                        router.push(.articles(feedId: feed.id, feedTitle: feed.title))
                                        appState.selectedFeedId = feed.id
                                        Task { await appState.loadArticlesForSelectedFeed() }
                                    }
                                }
                                .padding(.horizontal, DesignTokens.Spacing.md)
                            }
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
                ("⌘F", "search"),
                ("⌘N", "add feed"),
                ("⌘R", "refresh")
            ])
        }
        .background(DesignTokens.Colors.backgroundPrimary)
        .task {
            await appState.loadFeeds()
        }
        .background {
            // Hidden button to capture ⌘F keyboard shortcut
            Button("") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearching.toggle()
                    if isSearching {
                        isSearchFocused = true
                    } else {
                        searchText = ""
                    }
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .hidden()
        }
        .onKeyPress(.escape) {
            if isSearching {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearching = false
                    searchText = ""
                }
                return .handled
            }
            return .ignored
        }
    }
}

#Preview {
    FeedsScreen()
        .environment(AppState())
        .environment(NavigationRouter())
        .frame(width: 400, height: 600)
}
