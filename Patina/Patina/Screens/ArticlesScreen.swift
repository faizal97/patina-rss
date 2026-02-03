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

// MARK: - Swipeable Article Row

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

#Preview {
    ArticlesScreen(feedId: -1, feedTitle: "All Unread")
        .environment(AppState())
        .environment(NavigationRouter())
        .frame(width: 400, height: 600)
}
