import SwiftUI

/// Main container view that manages immersive single-pane navigation with transitions
struct ImmersiveContainer: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            // Background
            DesignTokens.Colors.backgroundPrimary
                .ignoresSafeArea()

            // Main content based on current destination
            destinationView
                .id(router.currentDestination)
                .transition(slideTransition)

            // Command palette overlay
            if router.isCommandPaletteOpen {
                CommandPalette()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: router.currentDestination)
    }

    /// The view for the current navigation destination
    @ViewBuilder
    private var destinationView: some View {
        switch router.currentDestination {
        case .feeds:
            FeedsScreen()

        case .articles(let feedId, let feedTitle):
            ArticlesScreen(feedId: feedId, feedTitle: feedTitle)

        case .reader(let articleId):
            ReaderScreen(articleId: articleId)
        }
    }

    /// Asymmetric slide transition for navigation
    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

#Preview {
    ImmersiveContainer()
        .environment(NavigationRouter())
        .environment(AppState())
}
