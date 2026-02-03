import SwiftUI

/// Immersive articles list screen with keyboard navigation and swipe gestures
struct ArticlesScreen: View {
    let feedId: Int64
    let feedTitle: String

    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router
    @State private var selectedIndex: Int = 0
    @FocusState private var isFocused: Bool

    private var articles: [Article] {
        switch feedId {
        case -2:
            return appState.serendipityArticles
        case -3:
            return appState.recentArticles
        default:
            return appState.articles
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ScreenHeader(title: feedTitle) {
                BackButton(label: "Feeds") {
                    router.pop()
                }
            } trailing: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    HeaderButton(icon: "arrow.clockwise") {
                        Task { await refreshCurrentFeed() }
                    }
                    .help("Refresh")

                    HeaderButton(icon: "command") {
                        router.openCommandPalette()
                    }
                    .help("Command Palette (⌘K)")
                }
            }

            Divider()
                .background(DesignTokens.Colors.surfaceSubtle)

            // Articles list
            if articles.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                                SwipeableArticleRow(
                                    article: article,
                                    isSelected: index == selectedIndex,
                                    onTap: {
                                        selectedIndex = index
                                        openArticle(article)
                                    },
                                    onSwipeLeft: {
                                        Task { await toggleReadStatus(article) }
                                    }
                                )
                                .id(article.id)
                            }

                            Spacer(minLength: DesignTokens.Spacing.xxl)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.top, DesignTokens.Spacing.md)
                    }
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.backgroundPrimary)
                    .onChange(of: selectedIndex) { _, newIndex in
                        if newIndex >= 0, newIndex < articles.count {
                            withAnimation {
                                proxy.scrollTo(articles[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider()
                .background(DesignTokens.Colors.surfaceSubtle)

            // Keyboard hints footer
            KeyboardHintsFooter(hints: [
                ("j/k", "navigate"),
                ("↵", "open"),
                ("⎵", "toggle read"),
                ("esc", "back")
            ])
        }
        .background(DesignTokens.Colors.backgroundPrimary)
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
        .onKeyPress(.downArrow) { navigateDown(); return .handled }
        .onKeyPress(.upArrow) { navigateUp(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "j")) { _ in navigateDown(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "k")) { _ in navigateUp(); return .handled }
        .onKeyPress(.return) { openSelectedArticle(); return .handled }
        .onKeyPress(.space) { toggleSelectedReadStatus(); return .handled }
        .onKeyPress(.escape) { router.pop(); return .handled }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Articles",
            systemImage: "tray",
            description: Text("This feed doesn't have any articles yet")
        )
        .foregroundStyle(DesignTokens.Colors.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.backgroundPrimary)
    }

    // MARK: - Actions

    private func navigateDown() {
        guard !articles.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, articles.count - 1)
    }

    private func navigateUp() {
        guard !articles.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }

    private func openSelectedArticle() {
        guard selectedIndex >= 0, selectedIndex < articles.count else { return }
        openArticle(articles[selectedIndex])
    }

    private func openArticle(_ article: Article) {
        appState.selectedArticleId = article.id
        router.push(.reader(articleId: article.id))

        // Mark as read
        if !article.isRead {
            Task { await appState.markArticleRead(article.id) }
        }
    }

    private func toggleSelectedReadStatus() {
        guard selectedIndex >= 0, selectedIndex < articles.count else { return }
        Task { await toggleReadStatus(articles[selectedIndex]) }
    }

    private func toggleReadStatus(_ article: Article) async {
        if article.isRead {
            await appState.markArticleUnread(article.id)
        } else {
            await appState.markArticleRead(article.id)
        }
    }

    private func refreshCurrentFeed() async {
        switch feedId {
        case -1:
            await appState.loadAllUnreadArticles()
        case -2:
            await appState.loadSerendipityArticles()
        case -3:
            await appState.loadRecentArticles()
        default:
            await appState.refreshFeed(feedId)
            await appState.loadArticlesForSelectedFeed()
        }
    }
}

#Preview {
    ArticlesScreen(feedId: -1, feedTitle: "All Unread")
        .environment(AppState())
        .environment(NavigationRouter())
        .frame(width: 400, height: 600)
}
