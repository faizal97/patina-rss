import SwiftUI

/// Sheet for adding a new feed
struct AddFeedSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var urlInput = ""
    @State private var discoveredFeeds: [DiscoveredFeed] = []
    @State private var isDiscovering = false
    @State private var showDiscoveryResults = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DesignTokens.Colors.accent)
                Text("Add Feed")
                    .font(DesignTokens.Typography.headingLarge)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Feed URL")
                    .font(DesignTokens.Typography.headingSmall)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                TextField("https://example.com/feed.xml", text: $urlInput)
                    .textFieldStyle(.plain)
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                            .stroke(DesignTokens.Colors.surfaceSubtle, lineWidth: 1)
                    )
                    .onSubmit {
                        addFeedDirectly()
                    }

                Text("Enter a feed URL directly, or paste a website URL to discover feeds")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }

            if showDiscoveryResults && !discoveredFeeds.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Discovered Feeds")
                        .font(DesignTokens.Typography.headingSmall)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    ScrollView {
                        VStack(spacing: DesignTokens.Spacing.xs) {
                            ForEach(discoveredFeeds, id: \.url) { feed in
                                DiscoveredFeedRow(feed: feed) {
                                    addFeed(url: feed.url)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                }
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .keyboardShortcut(.escape)

                Spacer()

                Button("Discover Feeds") {
                    discoverFeeds()
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Colors.accent)
                .disabled(urlInput.isEmpty || isDiscovering)

                Button {
                    addFeedDirectly()
                } label: {
                    Text("Add Feed")
                        .font(DesignTokens.Typography.bodyMedium.weight(.medium))
                        .foregroundStyle(DesignTokens.Colors.backgroundPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return)
                .disabled(urlInput.isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: 450, height: showDiscoveryResults ? 450 : 220)
        .background(DesignTokens.Colors.backgroundSecondary)
        .overlay {
            if isDiscovering {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ProgressView()
                        .tint(DesignTokens.Colors.accent)
                    Text("Discovering feeds...")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .padding(DesignTokens.Spacing.lg)
                .background(DesignTokens.Colors.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            }
        }
    }

    private func addFeedDirectly() {
        guard !urlInput.isEmpty else { return }
        addFeed(url: urlInput)
    }

    private func addFeed(url: String) {
        Task {
            await appState.addFeed(url: url)
            dismiss()
        }
    }

    private func discoverFeeds() {
        guard !urlInput.isEmpty else { return }

        isDiscovering = true
        Task {
            discoveredFeeds = await appState.discoverFeeds(websiteUrl: urlInput)
            showDiscoveryResults = true
            isDiscovering = false
        }
    }
}

struct DiscoveredFeedRow: View {
    let feed: DiscoveredFeed
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(feed.title ?? "Untitled Feed")
                    .font(DesignTokens.Typography.bodyMedium.weight(.medium))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(feed.url)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.sm)
            .background(isHovered ? DesignTokens.Colors.surfaceSubtle : .clear)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    AddFeedSheet()
        .environment(AppState())
}
