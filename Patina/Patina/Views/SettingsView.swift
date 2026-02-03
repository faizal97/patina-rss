import SwiftUI

/// Settings view for the app
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            SerendipitySettingsTab()
                .tabItem {
                    Label("Serendipity", systemImage: "sparkles")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
        .preferredColorScheme(.dark)
    }
}

struct GeneralSettingsTab: View {
    @AppStorage("refreshOnLaunch") private var refreshOnLaunch = true
    @AppStorage("markReadOnScroll") private var markReadOnScroll = true
    @AppStorage("openLinksInBrowser") private var openLinksInBrowser = false

    var body: some View {
        Form {
            Section {
                Toggle("Refresh feeds on launch", isOn: $refreshOnLaunch)
                Toggle("Mark articles as read when selected", isOn: $markReadOnScroll)
                Toggle("Open article links in external browser", isOn: $openLinksInBrowser)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.Colors.backgroundPrimary)
        .padding()
    }
}

struct SerendipitySettingsTab: View {
    @Environment(AppState.self) private var appState
    @AppStorage("serendipityEnabled") private var serendipityEnabled = true
    @AppStorage("serendipityArticleCount") private var articleCount = 20

    var body: some View {
        Form {
            Section {
                Toggle("Enable Serendipity mode", isOn: $serendipityEnabled)

                Stepper("Articles to show: \(articleCount)", value: $articleCount, in: 5...50, step: 5)
            }

            Section {
                Button {
                    appState.showPatternEditor = true
                } label: {
                    HStack {
                        Text("Edit Reading Patterns...")
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    Task {
                        await appState.resetReadingPatterns()
                    }
                } label: {
                    Text("Reset All Patterns")
                        .foregroundStyle(DesignTokens.Colors.error)
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.Colors.backgroundPrimary)
        .padding()
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()

            // App icon with glow effect
            ZStack {
                // Glow layer
                Image(systemName: "leaf.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignTokens.Colors.accent)
                    .blur(radius: 20)
                    .opacity(0.5)

                // Main icon
                Image(systemName: "leaf.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignTokens.Colors.accent)
            }

            Text("Patina")
                .font(DesignTokens.Typography.displayMedium)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Text("A thoughtful RSS reader")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Text("Version 1.0.0")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            Spacer()

            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("Built with")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textMuted)

                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "swift")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Colors.accent)
                    Text("SwiftUI")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }

                Text("&")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textMuted)

                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.Colors.accent)
                    Text("Rust")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            .padding(.bottom, DesignTokens.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.backgroundPrimary)
        .padding()
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
