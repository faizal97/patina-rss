import SwiftUI

/// Main content view with immersive single-pane navigation
struct ContentView: View {
    @Environment(AppState.self) private var appState

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
