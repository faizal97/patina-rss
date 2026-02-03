import SwiftUI

/// Full-screen command palette overlay with search and keyboard navigation
struct CommandPalette: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationRouter.self) private var router

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var commands: [PaletteCommand] {
        let allCommands = buildCommands()
        if searchText.isEmpty {
            return allCommands
        }
        return allCommands.filter { command in
            command.title.localizedCaseInsensitiveContains(searchText) ||
            (command.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            DesignTokens.Colors.backgroundPrimary.opacity(0.85)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    router.closeCommandPalette()
                }

            // Palette content
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)

                        TextField("Search commands...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(DesignTokens.Typography.bodyLarge)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .focused($isSearchFocused)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.backgroundSecondary)

                    Divider()
                        .background(DesignTokens.Colors.surfaceSubtle)

                    // Commands list
                    if commands.isEmpty {
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundStyle(DesignTokens.Colors.textMuted)

                            Text("No commands found")
                                .font(DesignTokens.Typography.bodyMedium)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.xxl)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                                        CommandRow(
                                            command: command,
                                            isSelected: index == selectedIndex
                                        ) {
                                            executeCommand(command)
                                        }
                                        .id(command.id)
                                    }
                                }
                                .padding(.vertical, DesignTokens.Spacing.xs)
                            }
                            .frame(maxHeight: 400)
                            .onChange(of: selectedIndex) { _, newIndex in
                                if newIndex >= 0, newIndex < commands.count {
                                    withAnimation {
                                        proxy.scrollTo(commands[newIndex].id, anchor: .center)
                                    }
                                }
                            }
                        }
                    }

                    Divider()
                        .background(DesignTokens.Colors.surfaceSubtle)

                    // Keyboard hints
                    HStack(spacing: DesignTokens.Spacing.lg) {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            KeyboardKey("↑↓")
                            Text("navigate")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }

                        HStack(spacing: DesignTokens.Spacing.xs) {
                            KeyboardKey("↵")
                            Text("select")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }

                        HStack(spacing: DesignTokens.Spacing.xs) {
                            KeyboardKey("esc")
                            Text("close")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(DesignTokens.Colors.backgroundSecondary)
                }
                .frame(width: 500)
                .background(DesignTokens.Colors.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                Spacer()
            }
        }
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onKeyPress(.downArrow) { navigateDown(); return .handled }
        .onKeyPress(.upArrow) { navigateUp(); return .handled }
        .onKeyPress(.return) { executeSelectedCommand(); return .handled }
        .onKeyPress(.escape) { router.closeCommandPalette(); return .handled }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }

    // MARK: - Navigation

    private func navigateDown() {
        guard !commands.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, commands.count - 1)
    }

    private func navigateUp() {
        guard !commands.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }

    private func executeSelectedCommand() {
        guard selectedIndex >= 0, selectedIndex < commands.count else { return }
        executeCommand(commands[selectedIndex])
    }

    private func executeCommand(_ command: PaletteCommand) {
        // Store action before closing palette
        let action = command.action
        router.closeCommandPalette()

        // Execute after a brief delay to let the palette dismiss animation complete
        // This prevents state conflicts between the closing animation and sheet presentation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            action()
        }
    }

    // MARK: - Build Commands

    private func buildCommands() -> [PaletteCommand] {
        var commands: [PaletteCommand] = []

        // Navigation commands
        commands.append(PaletteCommand(
            icon: "leaf.fill",
            title: "Go to Feeds",
            subtitle: "Return to the feeds list",
            shortcut: nil
        ) {
            router.popToRoot()
        })

        commands.append(PaletteCommand(
            icon: "tray.full.fill",
            title: "All Unread",
            subtitle: "View all unread articles",
            shortcut: nil
        ) {
            router.popToRoot()
            router.push(.articles(feedId: -1, feedTitle: "All Unread"))
            Task { await appState.loadAllUnreadArticles() }
        })

        commands.append(PaletteCommand(
            icon: "sparkles",
            title: "Serendipity",
            subtitle: "Discover articles based on your patterns",
            shortcut: nil
        ) {
            router.popToRoot()
            router.push(.articles(feedId: -2, feedTitle: "Serendipity"))
            Task { await appState.loadSerendipityArticles() }
        })

        commands.append(PaletteCommand(
            icon: "clock.fill",
            title: "Recent",
            subtitle: "View recently published articles",
            shortcut: nil
        ) {
            router.popToRoot()
            router.push(.articles(feedId: -3, feedTitle: "Recent"))
            Task { await appState.loadRecentArticles() }
        })

        // Action commands
        commands.append(PaletteCommand(
            icon: "plus",
            title: "Add Feed",
            subtitle: "Subscribe to a new RSS feed",
            shortcut: "⌘N"
        ) {
            appState.showAddFeedSheet = true
        })

        commands.append(PaletteCommand(
            icon: "arrow.clockwise",
            title: "Refresh All Feeds",
            subtitle: "Update all your subscriptions",
            shortcut: "⌘R"
        ) {
            Task { await appState.refreshAllFeeds() }
        })

        commands.append(PaletteCommand(
            icon: "square.and.arrow.down",
            title: "Import OPML",
            subtitle: "Import feeds from an OPML file",
            shortcut: "⇧⌘I"
        ) {
            appState.showImportSheet = true
        })

        commands.append(PaletteCommand(
            icon: "wand.and.stars",
            title: "Reading Patterns",
            subtitle: "Configure your reading preferences",
            shortcut: nil
        ) {
            appState.showPatternEditor = true
        })

        // Feed-specific commands (if we have feeds)
        for feed in appState.feeds.prefix(5) {
            commands.append(PaletteCommand(
                icon: "doc.text.fill",
                title: feed.title,
                subtitle: feed.unreadCount > 0 ? "\(feed.unreadCount) unread" : "No unread",
                shortcut: nil
            ) {
                router.popToRoot()
                router.push(.articles(feedId: feed.id, feedTitle: feed.title))
                appState.selectedFeedId = feed.id
                Task { await appState.loadArticlesForSelectedFeed() }
            })
        }

        return commands
    }
}

// MARK: - Palette Command

struct PaletteCommand: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let shortcut: String?
    let action: () -> Void
}

// MARK: - Command Row

struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Icon
                Image(systemName: command.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.Colors.accent)
                    .frame(width: 24)

                // Title and subtitle
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
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

                // Shortcut
                if let shortcut = command.shortcut {
                    Text(shortcut)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textMuted)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .fill(DesignTokens.Colors.surfaceSubtle)
                        )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(backgroundColor)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return DesignTokens.Colors.accentSubtle
        }
        return isHovered ? DesignTokens.Colors.backgroundTertiary : .clear
    }
}

#Preview {
    ZStack {
        DesignTokens.Colors.backgroundPrimary
            .ignoresSafeArea()

        CommandPalette()
    }
    .environment(AppState())
    .environment(NavigationRouter())
}
