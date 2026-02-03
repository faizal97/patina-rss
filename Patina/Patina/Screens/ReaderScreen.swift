import SwiftUI
import WebKit

/// Immersive reader screen for viewing article content
struct ReaderScreen: View {
    let articleId: Int64

    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router
    @State private var isWebViewLoading = false
    @FocusState private var isFocused: Bool

    private var article: Article? {
        appState.articles.first { $0.id == articleId }
    }

    private var currentIndex: Int? {
        appState.articles.firstIndex { $0.id == articleId }
    }

    private var hasPrevious: Bool {
        guard let index = currentIndex else { return false }
        return index > 0
    }

    private var hasNext: Bool {
        guard let index = currentIndex else { return false }
        return index < appState.articles.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            if let article {
                // Header
                readerHeader(article: article)

                Divider()
                    .background(DesignTokens.Colors.surfaceSubtle)

                // Web content
                ZStack {
                    WebView(url: URL(string: article.url), isLoading: $isWebViewLoading)

                    if isWebViewLoading {
                        loadingOverlay
                    }
                }

                Divider()
                    .background(DesignTokens.Colors.surfaceSubtle)

                // Footer with navigation
                ReaderFooter(
                    hasPrevious: hasPrevious,
                    hasNext: hasNext,
                    onPrevious: navigateToPrevious,
                    onNext: navigateToNext
                )
            } else {
                ContentUnavailableView(
                    "Article Not Found",
                    systemImage: "doc.richtext",
                    description: Text("The article could not be loaded")
                )
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .background(DesignTokens.Colors.backgroundPrimary)
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
            isWebViewLoading = true
        }
        .onKeyPress(.escape) { router.pop(); return .handled }
        .onKeyPress(.leftArrow) { navigateToPrevious(); return .handled }
        .onKeyPress(.rightArrow) { navigateToNext(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "h")) { _ in navigateToPrevious(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "l")) { _ in navigateToNext(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "j")) { _ in return .ignored }
        .onKeyPress(characters: CharacterSet(charactersIn: "k")) { _ in return .ignored }
    }

    // MARK: - Header

    @ViewBuilder
    private func readerHeader(article: Article) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Top row with back and actions
            HStack {
                BackButton(label: "Articles") {
                    router.pop()
                }

                Spacer()

                HStack(spacing: DesignTokens.Spacing.xs) {
                    if isWebViewLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(DesignTokens.Colors.accent)
                            .frame(width: 32, height: 32)
                    }

                    HeaderButton(icon: "safari") {
                        if let url = URL(string: article.url) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .help("Open in Browser")

                    HeaderButton(icon: "link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(article.url, forType: .string)
                    }
                    .help("Copy Link")

                    HeaderButton(
                        icon: article.isRead ? "circle" : "circle.fill",
                        isActive: !article.isRead,
                        activeColor: DesignTokens.Colors.unread
                    ) {
                        Task {
                            if article.isRead {
                                await appState.markArticleUnread(article.id)
                            } else {
                                await appState.markArticleRead(article.id)
                            }
                        }
                    }
                    .help(article.isRead ? "Mark as Unread" : "Mark as Read")

                    HeaderButton(icon: "command") {
                        router.openCommandPalette()
                    }
                    .help("Command Palette (⌘K)")
                }
            }

            // Article title
            Text(article.title)
                .font(DesignTokens.Typography.headingLarge)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(3)

            // Metadata row
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let feedTitle = article.feedTitle {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Circle()
                            .fill(DesignTokens.Colors.accent)
                            .frame(width: 6, height: 6)
                        Text(feedTitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }

                Spacer()

                if let publishedAt = article.publishedAt {
                    Text(formatDate(publishedAt))
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.backgroundSecondary)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(DesignTokens.Colors.accent)

            Text("Loading article...")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.backgroundPrimary.opacity(0.95))
    }

    // MARK: - Navigation

    private func navigateToPrevious() {
        guard let index = currentIndex, hasPrevious else { return }
        let previousArticle = appState.articles[index - 1]
        appState.selectedArticleId = previousArticle.id
        router.replace(with: .reader(articleId: previousArticle.id))

        if !previousArticle.isRead {
            Task { await appState.markArticleRead(previousArticle.id) }
        }
    }

    private func navigateToNext() {
        guard let index = currentIndex, hasNext else { return }
        let nextArticle = appState.articles[index + 1]
        appState.selectedArticleId = nextArticle.id
        router.replace(with: .reader(articleId: nextArticle.id))

        if !nextArticle.isRead {
            Task { await appState.markArticleRead(nextArticle.id) }
        }
    }

    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Reader Footer

struct ReaderFooter: View {
    let hasPrevious: Bool
    let hasNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            // Previous button
            NavigationFooterButton(
                icon: "chevron.left",
                label: "Previous",
                isEnabled: hasPrevious,
                action: onPrevious
            )

            Spacer()

            // Keyboard hints
            HStack(spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    KeyboardKey("h/←")
                    Text("prev")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }

                HStack(spacing: DesignTokens.Spacing.xs) {
                    KeyboardKey("l/→")
                    Text("next")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }

                HStack(spacing: DesignTokens.Spacing.xs) {
                    KeyboardKey("esc")
                    Text("back")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }

            Spacer()

            // Next button
            NavigationFooterButton(
                icon: "chevron.right",
                label: "Next",
                isTrailing: true,
                isEnabled: hasNext,
                action: onNext
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary)
    }
}

struct NavigationFooterButton: View {
    let icon: String
    let label: String
    var isTrailing: Bool = false
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if !isTrailing {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }

                Text(label)
                    .font(DesignTokens.Typography.bodySmall)

                if isTrailing {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(isHovered && isEnabled ? DesignTokens.Colors.backgroundTertiary : .clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return DesignTokens.Colors.textMuted
        }
        return isHovered ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary
    }
}

#Preview {
    ReaderScreen(articleId: 1)
        .environment(AppState())
        .environment(NavigationRouter())
        .frame(width: 600, height: 800)
}
