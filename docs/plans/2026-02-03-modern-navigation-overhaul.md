# Modern Navigation Overhaul - Reeder-Style Immersive

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform Patina from a traditional 3-column layout to an immersive, single-pane reading experience with animated transitions, keyboard navigation, swipe gestures, and a command palette.

**Architecture:** Replace `NavigationSplitView` with a custom `NavigationRouter` that manages view stack state. Each screen (Feeds → Articles → Reader) animates in/out using matched geometry and spring animations. Input handling is centralized through a `KeyboardNavigator` and gesture recognizers.

**Tech Stack:** SwiftUI, macOS 14+, Swift 6, `@Observable` for state, custom transitions via `matchedGeometryEffect` and `transition()` modifiers.

---

## Design Direction: "Immersive Reading"

```
┌─────────────────────────────────────────────────────────────┐
│  ← All Unread                                    ⌘K  ⚙     │  ← Minimal header with back + actions
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Article Title Here                                        │
│   Source Name · 2 hours ago                                 │
│                                                             │
│   ─────────────────────────────────────────────────────     │
│                                                             │
│   Article content renders here in a beautiful               │
│   reader view with proper typography...                     │
│                                                             │
│                                                             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  ← Previous    j/k navigate  ⎵ scroll           Next →     │  ← Footer with keyboard hints
└─────────────────────────────────────────────────────────────┘
```

**Navigation Flow:**
- **Feeds View** → Click feed → **Articles View** (slides in from right)
- **Articles View** → Click article → **Reader View** (slides in from right)
- **Any View** → Press `Escape` or `←` → Go back (slides out to right)
- **Any View** → Press `⌘K` → **Command Palette** (overlays with fade)

---

## Task 1: Create Navigation Router

**Files:**
- Create: `Patina/Patina/Navigation/NavigationRouter.swift`
- Create: `Patina/Patina/Navigation/NavigationDestination.swift`

**Step 1: Create the Navigation directory**

```bash
mkdir -p Patina/Patina/Navigation
```

**Step 2: Write NavigationDestination.swift**

```swift
import Foundation

/// Represents a navigation destination in the app
enum NavigationDestination: Equatable, Hashable {
    case feeds
    case articles(feedId: Int64, feedTitle: String)
    case reader(articleId: Int64)

    var title: String {
        switch self {
        case .feeds:
            return "Feeds"
        case .articles(_, let feedTitle):
            return feedTitle
        case .reader:
            return ""
        }
    }
}
```

**Step 3: Write NavigationRouter.swift**

```swift
import SwiftUI
import Observation

/// Centralized navigation state manager
@MainActor
@Observable
final class NavigationRouter {
    // MARK: - Navigation Stack

    private(set) var path: [NavigationDestination] = []

    var currentDestination: NavigationDestination {
        path.last ?? .feeds
    }

    var canGoBack: Bool {
        !path.isEmpty
    }

    // MARK: - Command Palette

    var isCommandPaletteOpen = false

    // MARK: - Navigation Actions

    func push(_ destination: NavigationDestination) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            path.append(destination)
        }
    }

    func pop() {
        guard canGoBack else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            _ = path.removeLast()
        }
    }

    func popToRoot() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            path.removeAll()
        }
    }

    func replace(with destination: NavigationDestination) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if !path.isEmpty {
                path[path.count - 1] = destination
            } else {
                path.append(destination)
            }
        }
    }

    // MARK: - Convenience Navigation

    func openFeed(id: Int64, title: String) {
        push(.articles(feedId: id, feedTitle: title))
    }

    func openArticle(id: Int64) {
        push(.reader(articleId: id))
    }

    func toggleCommandPalette() {
        withAnimation(.easeOut(duration: 0.15)) {
            isCommandPaletteOpen.toggle()
        }
    }
}
```

**Step 4: Regenerate Xcode project**

```bash
cd Patina && xcodegen generate
```

**Step 5: Build and verify**

```bash
cd Patina && xcodebuild -scheme Patina -configuration Debug build 2>&1 | tail -10
```

---

## Task 2: Create Immersive Container View

**Files:**
- Create: `Patina/Patina/Navigation/ImmersiveContainer.swift`
- Modify: `Patina/Patina/ContentView.swift`
- Modify: `Patina/Patina/PatinaApp.swift`

**Step 1: Write ImmersiveContainer.swift**

```swift
import SwiftUI

/// Main container that handles immersive navigation transitions
struct ImmersiveContainer: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router

    @Namespace private var namespace

    var body: some View {
        ZStack {
            // Background
            DesignTokens.Colors.backgroundPrimary
                .ignoresSafeArea()

            // Main content with transitions
            Group {
                switch router.currentDestination {
                case .feeds:
                    FeedsScreen(namespace: namespace)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .articles(let feedId, _):
                    ArticlesScreen(feedId: feedId, namespace: namespace)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))

                case .reader(let articleId):
                    ReaderScreen(articleId: articleId, namespace: namespace)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .id(router.currentDestination)

            // Command palette overlay
            if router.isCommandPaletteOpen {
                CommandPaletteOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder for command palette (implemented in Task 6)
struct CommandPaletteOverlay: View {
    var body: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
    }
}
```

**Step 2: Update PatinaApp.swift to inject NavigationRouter**

```swift
import SwiftUI

@main
struct PatinaApp: App {
    @State private var appState = AppState()
    @State private var router = NavigationRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(router)
                .preferredColorScheme(.dark)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Feed...") {
                    appState.showAddFeedSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Import OPML...") {
                    appState.showImportSheet = true
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()

                Button("Refresh All Feeds") {
                    Task {
                        await appState.refreshAllFeeds()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandGroup(after: .toolbar) {
                Button("Command Palette") {
                    router.toggleCommandPalette()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Divider()

                Button("Go Back") {
                    router.pop()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(!router.canGoBack)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
```

**Step 3: Update ContentView.swift to use ImmersiveContainer**

```swift
import SwiftUI

/// Main content view with immersive navigation
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        @Bindable var state = appState

        ImmersiveContainer()
            .sheet(isPresented: $state.showAddFeedSheet) {
                AddFeedSheet()
            }
            .sheet(isPresented: $state.showImportSheet) {
                ImportOPMLSheet()
            }
            .sheet(isPresented: $state.showPatternEditor) {
                ReadingPatternEditor()
            }
            .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
                Button("OK") {
                    appState.errorMessage = nil
                }
            } message: {
                if let error = appState.errorMessage {
                    Text(error)
                }
            }
            .overlay {
                if appState.isLoading {
                    ZStack {
                        DesignTokens.Colors.backgroundPrimary.opacity(0.9)
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(DesignTokens.Colors.accent)
                    }
                }
            }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(NavigationRouter())
}
```

**Step 4: Regenerate and build**

```bash
cd Patina && xcodegen generate && xcodebuild -scheme Patina -configuration Debug build 2>&1 | tail -10
```

---

## Task 3: Create Immersive Screens (Feeds, Articles, Reader)

**Files:**
- Create: `Patina/Patina/Screens/FeedsScreen.swift`
- Create: `Patina/Patina/Screens/ArticlesScreen.swift`
- Create: `Patina/Patina/Screens/ReaderScreen.swift`

**Step 1: Create Screens directory**

```bash
mkdir -p Patina/Patina/Screens
```

**Step 2: Write FeedsScreen.swift**

```swift
import SwiftUI

/// Immersive feeds screen with header and full-height list
struct FeedsScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router

    let namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ScreenHeader(
                title: "Patina",
                subtitle: "\(appState.totalUnreadCount) unread",
                leadingContent: {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.accent)
                },
                trailingContent: {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        HeaderButton(icon: "arrow.clockwise") {
                            Task { await appState.refreshAllFeeds() }
                        }
                        HeaderButton(icon: "plus") {
                            appState.showAddFeedSheet = true
                        }
                        HeaderButton(icon: "command") {
                            router.toggleCommandPalette()
                        }
                    }
                }
            )

            Divider()
                .background(DesignTokens.Colors.surfaceSubtle)

            // Feed list
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Smart sections
                    SmartFeedRow(
                        icon: "tray.full.fill",
                        title: "All Unread",
                        count: Int(appState.totalUnreadCount),
                        namespace: namespace
                    ) {
                        router.openFeed(id: -1, title: "All Unread")
                        Task { await appState.loadAllUnreadArticles() }
                    }

                    SmartFeedRow(
                        icon: "sparkles",
                        title: "Serendipity",
                        count: nil,
                        namespace: namespace
                    ) {
                        router.openFeed(id: -2, title: "Serendipity")
                        Task { await appState.loadSerendipityArticles() }
                    }

                    // Section divider
                    HStack {
                        Text("FEEDS")
                            .font(DesignTokens.Typography.micro)
                            .foregroundStyle(DesignTokens.Colors.textMuted)
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.sm)

                    // Feed rows
                    ForEach(appState.feeds, id: \.id) { feed in
                        FeedListRow(feed: feed, namespace: namespace) {
                            router.openFeed(id: feed.id, title: feed.title)
                            Task {
                                appState.selectedFeedId = feed.id
                                await appState.loadArticlesForSelectedFeed()
                            }
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
            .scrollContentBackground(.hidden)
            .background(DesignTokens.Colors.backgroundPrimary)
        }
    }
}

struct SmartFeedRow: View {
    let icon: String
    let title: String
    let count: Int?
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                        .fill(DesignTokens.Colors.accentSubtle)
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(DesignTokens.Colors.accent)
                }

                Text(title)
                    .font(DesignTokens.Typography.bodyLarge)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Spacer()

                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundStyle(DesignTokens.Colors.backgroundPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(DesignTokens.Colors.accent)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(isHovered ? DesignTokens.Colors.backgroundSecondary : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

struct FeedListRow: View {
    let feed: Feed
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(DesignTokens.Colors.surfaceSubtle)
                        .frame(width: 36, height: 36)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
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

                if feed.unreadCount > 0 {
                    Text("\(feed.unreadCount)")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundStyle(DesignTokens.Colors.accent)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(DesignTokens.Colors.accentSubtle)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isHovered ? DesignTokens.Colors.backgroundSecondary : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}
```

**Step 3: Write ArticlesScreen.swift**

```swift
import SwiftUI

/// Immersive articles screen for a single feed
struct ArticlesScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router

    let feedId: Int64
    let namespace: Namespace.ID

    @State private var selectedIndex: Int = 0

    private var articles: [Article] {
        feedId == -2 ? appState.serendipityArticles : appState.articles
    }

    private var feedTitle: String {
        switch feedId {
        case -1: return "All Unread"
        case -2: return "Serendipity"
        default: return appState.feeds.first { $0.id == feedId }?.title ?? "Articles"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            ScreenHeader(
                title: feedTitle,
                subtitle: "\(articles.count) articles",
                leadingContent: {
                    BackButton {
                        router.pop()
                    }
                },
                trailingContent: {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        HeaderButton(icon: "arrow.clockwise") {
                            if feedId > 0 {
                                Task { await appState.refreshFeed(feedId) }
                            }
                        }
                        HeaderButton(icon: "command") {
                            router.toggleCommandPalette()
                        }
                    }
                }
            )

            Divider()
                .background(DesignTokens.Colors.surfaceSubtle)

            if articles.isEmpty {
                Spacer()
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                    Text("No Articles")
                        .font(DesignTokens.Typography.headingMedium)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                    Text("This feed doesn't have any articles yet")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                Spacer()
            } else {
                // Article list with swipe gestures
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                                SwipeableArticleRow(
                                    article: article,
                                    isSelected: index == selectedIndex,
                                    namespace: namespace,
                                    onTap: {
                                        selectedIndex = index
                                        router.openArticle(id: article.id)
                                        appState.selectedArticleId = article.id
                                        if !article.isRead {
                                            Task { await appState.markArticleRead(article.id) }
                                        }
                                    },
                                    onMarkRead: {
                                        Task {
                                            if article.isRead {
                                                await appState.markArticleUnread(article.id)
                                            } else {
                                                await appState.markArticleRead(article.id)
                                            }
                                        }
                                    }
                                )
                                .id(article.id)
                            }
                        }
                        .padding(DesignTokens.Spacing.md)
                    }
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.backgroundPrimary)
                }
            }

            // Footer with keyboard hints
            KeyboardHintsFooter(hints: [
                ("↑↓", "navigate"),
                ("↵", "open"),
                ("⎵", "mark read"),
                ("⌘K", "commands")
            ])
        }
        .onKeyPress(.downArrow) {
            navigateArticle(direction: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            navigateArticle(direction: -1)
            return .handled
        }
        .onKeyPress(characters: "j") {
            navigateArticle(direction: 1)
            return .handled
        }
        .onKeyPress(characters: "k") {
            navigateArticle(direction: -1)
            return .handled
        }
        .onKeyPress(.return) {
            if !articles.isEmpty && selectedIndex < articles.count {
                let article = articles[selectedIndex]
                router.openArticle(id: article.id)
                appState.selectedArticleId = article.id
            }
            return .handled
        }
        .onKeyPress(.space) {
            if !articles.isEmpty && selectedIndex < articles.count {
                let article = articles[selectedIndex]
                Task {
                    if article.isRead {
                        await appState.markArticleUnread(article.id)
                    } else {
                        await appState.markArticleRead(article.id)
                    }
                }
            }
            return .handled
        }
    }

    private func navigateArticle(direction: Int) {
        let newIndex = selectedIndex + direction
        if newIndex >= 0 && newIndex < articles.count {
            selectedIndex = newIndex
        }
    }
}

struct SwipeableArticleRow: View {
    let article: Article
    let isSelected: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void
    let onMarkRead: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isHovered = false

    var body: some View {
        ZStack {
            // Swipe background
            HStack {
                Spacer()
                ZStack {
                    DesignTokens.Colors.accent
                    Image(systemName: article.isRead ? "envelope.badge" : "envelope.open")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
                .frame(width: 80)
            }

            // Main content
            Button(action: onTap) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    // Unread indicator
                    Circle()
                        .fill(article.isRead ? .clear : DesignTokens.Colors.unread)
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)

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

                        HStack(spacing: DesignTokens.Spacing.xs) {
                            if let feedTitle = article.feedTitle {
                                Text(feedTitle)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                            }

                            if article.feedTitle != nil && article.publishedAt != nil {
                                Text("·")
                                    .foregroundStyle(DesignTokens.Colors.textMuted)
                            }

                            if let publishedAt = article.publishedAt {
                                Text(formatDate(publishedAt))
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                            }
                        }

                        if let summary = article.summary, !summary.isEmpty {
                            Text(summary)
                                .font(DesignTokens.Typography.bodySmall)
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .padding(.top, 6)
                }
                .padding(DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                        .fill(isSelected
                            ? DesignTokens.Colors.accentSubtle
                            : isHovered
                                ? DesignTokens.Colors.backgroundTertiary
                                : DesignTokens.Colors.backgroundSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                        .stroke(isSelected ? DesignTokens.Colors.accent : .clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -80)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if value.translation.width < -50 {
                                onMarkRead()
                            }
                            offset = 0
                        }
                    }
            )
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.fast) {
                    isHovered = hovering
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
```

**Step 4: Write ReaderScreen.swift**

```swift
import SwiftUI

/// Immersive reader screen for reading articles
struct ReaderScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router

    let articleId: Int64
    let namespace: Namespace.ID

    @State private var isWebViewLoading = true

    private var article: Article? {
        appState.articles.first { $0.id == articleId } ??
        appState.serendipityArticles.first { $0.id == articleId }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let article = article {
                // Minimal header
                ReaderHeader(article: article, isLoading: isWebViewLoading)

                Divider()
                    .background(DesignTokens.Colors.surfaceSubtle)

                // Web content
                ZStack {
                    WebView(url: URL(string: article.url), isLoading: $isWebViewLoading)

                    if isWebViewLoading {
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
                }

                // Footer with navigation
                ReaderFooter(
                    onPrevious: navigateToPrevious,
                    onNext: navigateToNext,
                    hasPrevious: hasPreviousArticle,
                    hasNext: hasNextArticle
                )
            } else {
                Spacer()
                Text("Article not found")
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                Spacer()
            }
        }
        .background(DesignTokens.Colors.backgroundPrimary)
        .onKeyPress(.leftArrow) {
            navigateToPrevious()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateToNext()
            return .handled
        }
        .onKeyPress(characters: "h") {
            navigateToPrevious()
            return .handled
        }
        .onKeyPress(characters: "l") {
            navigateToNext()
            return .handled
        }
    }

    private var currentArticleIndex: Int? {
        let articles = appState.articles.isEmpty ? appState.serendipityArticles : appState.articles
        return articles.firstIndex { $0.id == articleId }
    }

    private var hasPreviousArticle: Bool {
        guard let index = currentArticleIndex else { return false }
        return index > 0
    }

    private var hasNextArticle: Bool {
        let articles = appState.articles.isEmpty ? appState.serendipityArticles : appState.articles
        guard let index = currentArticleIndex else { return false }
        return index < articles.count - 1
    }

    private func navigateToPrevious() {
        let articles = appState.articles.isEmpty ? appState.serendipityArticles : appState.articles
        guard let index = currentArticleIndex, index > 0 else { return }
        let prevArticle = articles[index - 1]
        router.replace(with: .reader(articleId: prevArticle.id))
        appState.selectedArticleId = prevArticle.id
        if !prevArticle.isRead {
            Task { await appState.markArticleRead(prevArticle.id) }
        }
    }

    private func navigateToNext() {
        let articles = appState.articles.isEmpty ? appState.serendipityArticles : appState.articles
        guard let index = currentArticleIndex, index < articles.count - 1 else { return }
        let nextArticle = articles[index + 1]
        router.replace(with: .reader(articleId: nextArticle.id))
        appState.selectedArticleId = nextArticle.id
        if !nextArticle.isRead {
            Task { await appState.markArticleRead(nextArticle.id) }
        }
    }
}

struct ReaderHeader: View {
    let article: Article
    let isLoading: Bool
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            BackButton {
                router.pop()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(article.title)
                    .font(DesignTokens.Typography.bodyMedium.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                if let feedTitle = article.feedTitle {
                    Text(feedTitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }

            Spacer()

            HStack(spacing: DesignTokens.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(DesignTokens.Colors.accent)
                        .frame(width: 28, height: 28)
                }

                HeaderButton(icon: "safari") {
                    if let url = URL(string: article.url) {
                        NSWorkspace.shared.open(url)
                    }
                }

                HeaderButton(icon: "link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(article.url, forType: .string)
                }

                HeaderButton(
                    icon: article.isRead ? "circle" : "circle.fill",
                    isActive: !article.isRead
                ) {
                    Task {
                        if article.isRead {
                            await appState.markArticleUnread(article.id)
                        } else {
                            await appState.markArticleRead(article.id)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary)
    }
}

struct ReaderFooter: View {
    let onPrevious: () -> Void
    let onNext: () -> Void
    let hasPrevious: Bool
    let hasNext: Bool

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .font(DesignTokens.Typography.bodySmall)
                .foregroundStyle(hasPrevious
                    ? DesignTokens.Colors.textSecondary
                    : DesignTokens.Colors.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(!hasPrevious)

            Spacer()

            Text("h/l or ←/→ to navigate")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textMuted)

            Spacer()

            Button(action: onNext) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(DesignTokens.Typography.bodySmall)
                .foregroundStyle(hasNext
                    ? DesignTokens.Colors.textSecondary
                    : DesignTokens.Colors.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(!hasNext)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary)
    }
}
```

**Step 5: Regenerate and build**

```bash
cd Patina && xcodegen generate && xcodebuild -scheme Patina -configuration Debug build 2>&1 | tail -10
```

---

## Task 4: Create Shared UI Components

**Files:**
- Create: `Patina/Patina/Components/ScreenHeader.swift`
- Create: `Patina/Patina/Components/HeaderButton.swift`
- Create: `Patina/Patina/Components/BackButton.swift`
- Create: `Patina/Patina/Components/KeyboardHintsFooter.swift`

**Step 1: Write ScreenHeader.swift**

```swift
import SwiftUI

/// Consistent header component for all screens
struct ScreenHeader<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let leadingContent: () -> Leading
    @ViewBuilder let trailingContent: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leadingContent: @escaping () -> Leading,
        @ViewBuilder trailingContent: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingContent = leadingContent
        self.trailingContent = trailingContent
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            leadingContent()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.headingMedium)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }

            Spacer()

            trailingContent()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary)
    }
}
```

**Step 2: Write HeaderButton.swift**

```swift
import SwiftUI

/// Consistent header action button with hover state
struct HeaderButton: View {
    let icon: String
    var isActive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(isActive
                    ? DesignTokens.Colors.accent
                    : DesignTokens.Colors.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(isHovered
                            ? DesignTokens.Colors.backgroundTertiary
                            : .clear)
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
```

**Step 3: Write BackButton.swift**

```swift
import SwiftUI

/// Back navigation button with hover state
struct BackButton: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Back")
                    .font(DesignTokens.Typography.bodySmall)
            }
            .foregroundStyle(isHovered
                ? DesignTokens.Colors.textPrimary
                : DesignTokens.Colors.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(isHovered
                        ? DesignTokens.Colors.backgroundTertiary
                        : .clear)
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
```

**Step 4: Write KeyboardHintsFooter.swift**

```swift
import SwiftUI

/// Footer showing available keyboard shortcuts
struct KeyboardHintsFooter: View {
    let hints: [(key: String, action: String)]

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            ForEach(hints, id: \.key) { hint in
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(hint.key)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignTokens.Colors.surfaceSubtle)
                        )

                    Text(hint.action)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary)
    }
}
```

**Step 5: Regenerate and build**

```bash
cd Patina && xcodegen generate && xcodebuild -scheme Patina -configuration Debug build 2>&1 | tail -10
```

---

## Task 5: Create Command Palette

**Files:**
- Create: `Patina/Patina/Navigation/CommandPalette.swift`
- Modify: `Patina/Patina/Navigation/ImmersiveContainer.swift`

**Step 1: Write CommandPalette.swift**

```swift
import SwiftUI

/// Command palette action
struct PaletteCommand: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let shortcut: String?
    let action: () -> Void
}

/// Full-screen command palette overlay
struct CommandPalette: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var commands: [PaletteCommand] {
        var cmds: [PaletteCommand] = []

        // Navigation commands
        cmds.append(PaletteCommand(
            icon: "tray.full.fill",
            title: "Go to All Unread",
            subtitle: "\(appState.totalUnreadCount) articles",
            shortcut: nil
        ) {
            router.popToRoot()
            router.openFeed(id: -1, title: "All Unread")
            Task { await appState.loadAllUnreadArticles() }
            router.toggleCommandPalette()
        })

        cmds.append(PaletteCommand(
            icon: "sparkles",
            title: "Go to Serendipity",
            subtitle: "Discover articles",
            shortcut: nil
        ) {
            router.popToRoot()
            router.openFeed(id: -2, title: "Serendipity")
            Task { await appState.loadSerendipityArticles() }
            router.toggleCommandPalette()
        })

        // Feed commands
        for feed in appState.feeds {
            cmds.append(PaletteCommand(
                icon: "doc.text.fill",
                title: feed.title,
                subtitle: feed.unreadCount > 0 ? "\(feed.unreadCount) unread" : nil,
                shortcut: nil
            ) {
                router.popToRoot()
                router.openFeed(id: feed.id, title: feed.title)
                appState.selectedFeedId = feed.id
                Task { await appState.loadArticlesForSelectedFeed() }
                router.toggleCommandPalette()
            })
        }

        // Action commands
        cmds.append(PaletteCommand(
            icon: "plus",
            title: "Add Feed",
            subtitle: "Subscribe to a new RSS feed",
            shortcut: "⌘N"
        ) {
            appState.showAddFeedSheet = true
            router.toggleCommandPalette()
        })

        cmds.append(PaletteCommand(
            icon: "arrow.clockwise",
            title: "Refresh All Feeds",
            subtitle: "Fetch latest articles",
            shortcut: "⌘R"
        ) {
            Task { await appState.refreshAllFeeds() }
            router.toggleCommandPalette()
        })

        cmds.append(PaletteCommand(
            icon: "doc.badge.plus",
            title: "Import OPML",
            subtitle: "Import feeds from file",
            shortcut: "⇧⌘I"
        ) {
            appState.showImportSheet = true
            router.toggleCommandPalette()
        })

        cmds.append(PaletteCommand(
            icon: "slider.horizontal.3",
            title: "Reading Patterns",
            subtitle: "Manage Serendipity settings",
            shortcut: nil
        ) {
            appState.showPatternEditor = true
            router.toggleCommandPalette()
        })

        return cmds
    }

    private var filteredCommands: [PaletteCommand] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter { cmd in
            cmd.title.localizedCaseInsensitiveContains(searchText) ||
            (cmd.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    router.toggleCommandPalette()
                }

            // Palette
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)

                    TextField("Search commands and feeds...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.bodyLarge)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .focused($isSearchFocused)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.backgroundTertiary)

                Divider()
                    .background(DesignTokens.Colors.surfaceSubtle)

                // Results
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                            CommandRow(
                                command: command,
                                isSelected: index == selectedIndex
                            )
                        }
                    }
                }
                .frame(maxHeight: 400)

                // Footer
                HStack {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        KeyHint(key: "↑↓")
                        Text("navigate")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textMuted)
                    }

                    HStack(spacing: DesignTokens.Spacing.sm) {
                        KeyHint(key: "↵")
                        Text("select")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textMuted)
                    }

                    Spacer()

                    HStack(spacing: DesignTokens.Spacing.sm) {
                        KeyHint(key: "esc")
                        Text("close")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textMuted)
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundTertiary)
            }
            .frame(width: 500)
            .background(DesignTokens.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        }
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredCommands.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < filteredCommands.count {
                filteredCommands[selectedIndex].action()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            router.toggleCommandPalette()
            return .handled
        }
    }
}

struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        Button(action: command.action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: command.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                }

                Spacer()

                if let shortcut = command.shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignTokens.Colors.surfaceSubtle)
                        )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isSelected || isHovered
                ? DesignTokens.Colors.backgroundTertiary
                : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct KeyHint: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(DesignTokens.Colors.textTertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(DesignTokens.Colors.surfaceSubtle)
            )
    }
}
```

**Step 2: Update ImmersiveContainer.swift to use CommandPalette**

Replace the `CommandPaletteOverlay` placeholder:

```swift
// In ImmersiveContainer.swift, replace:
// struct CommandPaletteOverlay: View { ... }
// With nothing - delete it

// And update the overlay in ImmersiveContainer body:
if router.isCommandPaletteOpen {
    CommandPalette()
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
}
```

**Step 3: Regenerate and build**

```bash
cd Patina && xcodegen generate && xcodebuild -scheme Patina -configuration Debug build 2>&1 | tail -10
```

---

## Task 6: Clean Up Old Views

**Files:**
- Delete: `Patina/Patina/Views/SidebarView.swift` (replaced by FeedsScreen)
- Delete: `Patina/Patina/Views/ArticleListView.swift` (replaced by ArticlesScreen)
- Delete: `Patina/Patina/Views/ArticleDetailView.swift` (replaced by ReaderScreen)

**Step 1: Remove old views**

```bash
rm Patina/Patina/Views/SidebarView.swift
rm Patina/Patina/Views/ArticleListView.swift
rm Patina/Patina/Views/ArticleDetailView.swift
```

**Step 2: Regenerate Xcode project**

```bash
cd Patina && xcodegen generate
```

**Step 3: Build and verify**

```bash
cd Patina && xcodebuild -scheme Patina -configuration Debug build 2>&1 | tail -20
```

---

## Task 7: Final Integration and Testing

**Step 1: Run the app**

```bash
open ~/Library/Developer/Xcode/DerivedData/Patina-*/Build/Products/Debug/Patina.app
```

**Step 2: Test checklist**

- [ ] **Feeds screen** displays with all feeds and smart sections
- [ ] **Click feed** → Slides to articles screen
- [ ] **Click article** → Slides to reader screen
- [ ] **Back button** → Returns to previous screen with animation
- [ ] **Escape key** → Goes back one level
- [ ] **j/k keys** → Navigate article list
- [ ] **↑/↓ keys** → Navigate article list
- [ ] **Enter key** → Opens selected article
- [ ] **Space key** → Toggles read/unread
- [ ] **h/l keys** → Navigate between articles in reader
- [ ] **←/→ keys** → Navigate between articles in reader
- [ ] **⌘K** → Opens command palette
- [ ] **Command palette search** → Filters commands
- [ ] **Swipe left on article** → Marks read/unread
- [ ] **Hover states** → All interactive elements respond

**Step 3: Fix any issues found during testing**

---

## File Summary

### New Files
| File | Purpose |
|------|---------|
| `Navigation/NavigationRouter.swift` | Central navigation state |
| `Navigation/NavigationDestination.swift` | Navigation destination enum |
| `Navigation/ImmersiveContainer.swift` | Main container with transitions |
| `Navigation/CommandPalette.swift` | ⌘K command palette |
| `Screens/FeedsScreen.swift` | Immersive feeds view |
| `Screens/ArticlesScreen.swift` | Immersive articles view |
| `Screens/ReaderScreen.swift` | Immersive reader view |
| `Components/ScreenHeader.swift` | Consistent header component |
| `Components/HeaderButton.swift` | Header action button |
| `Components/BackButton.swift` | Back navigation button |
| `Components/KeyboardHintsFooter.swift` | Keyboard shortcuts footer |

### Modified Files
| File | Changes |
|------|---------|
| `PatinaApp.swift` | Inject NavigationRouter, add ⌘K command |
| `ContentView.swift` | Use ImmersiveContainer |

### Deleted Files
| File | Replaced By |
|------|-------------|
| `Views/SidebarView.swift` | `Screens/FeedsScreen.swift` |
| `Views/ArticleListView.swift` | `Screens/ArticlesScreen.swift` |
| `Views/ArticleDetailView.swift` | `Screens/ReaderScreen.swift` |

---

## Keyboard Shortcuts Reference

| Key | Action |
|-----|--------|
| `j` / `↓` | Next article in list |
| `k` / `↑` | Previous article in list |
| `↵` Enter | Open selected article |
| `⎵` Space | Toggle read/unread |
| `h` / `←` | Previous article (in reader) |
| `l` / `→` | Next article (in reader) |
| `Escape` | Go back / Close palette |
| `⌘K` | Open command palette |
| `⌘N` | Add feed |
| `⌘R` | Refresh all |
| `⇧⌘I` | Import OPML |
