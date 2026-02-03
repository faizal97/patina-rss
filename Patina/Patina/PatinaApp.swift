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
                    if router.isCommandPaletteOpen {
                        router.closeCommandPalette()
                    } else {
                        router.pop()
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(!router.canGoBack && !router.isCommandPaletteOpen)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
                .environment(router)
        }
    }
}
