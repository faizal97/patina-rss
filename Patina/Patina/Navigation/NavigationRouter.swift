import SwiftUI
import Observation

/// Central navigation state manager for immersive single-pane navigation
@MainActor
@Observable
final class NavigationRouter {
    // MARK: - State

    /// The navigation stack - current path of destinations
    private(set) var path: [NavigationDestination] = []

    /// Whether the command palette overlay is visible
    var isCommandPaletteOpen = false

    // MARK: - Computed Properties

    /// The current destination (top of the stack), defaults to feeds
    var currentDestination: NavigationDestination {
        path.last ?? .feeds
    }

    /// Whether we can navigate back
    var canGoBack: Bool {
        !path.isEmpty
    }

    /// The depth of the current navigation stack
    var depth: Int {
        path.count
    }

    // MARK: - Navigation Actions

    /// Push a new destination onto the stack with animation
    func push(_ destination: NavigationDestination) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            path.append(destination)
        }
    }

    /// Pop the top destination off the stack with animation
    @discardableResult
    func pop() -> NavigationDestination? {
        guard !path.isEmpty else { return nil }

        var popped: NavigationDestination?
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            popped = path.removeLast()
        }
        return popped
    }

    /// Pop all destinations and return to the root (feeds)
    func popToRoot() {
        guard !path.isEmpty else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            path.removeAll()
        }
    }

    /// Replace the current destination with a new one
    func replace(with destination: NavigationDestination) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if path.isEmpty {
                path.append(destination)
            } else {
                path[path.count - 1] = destination
            }
        }
    }

    /// Navigate to a specific destination, handling the path appropriately
    func navigate(to destination: NavigationDestination) {
        switch destination {
        case .feeds:
            popToRoot()

        case .articles:
            // If we're deeper than articles level, pop back first
            if path.count > 1 {
                popToRoot()
            }
            push(destination)

        case .reader:
            push(destination)
        }
    }

    // MARK: - Command Palette

    /// Toggle the command palette visibility
    func toggleCommandPalette() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isCommandPaletteOpen.toggle()
        }
    }

    /// Close the command palette
    func closeCommandPalette() {
        guard isCommandPaletteOpen else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isCommandPaletteOpen = false
        }
    }

    /// Open the command palette
    func openCommandPalette() {
        guard !isCommandPaletteOpen else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isCommandPaletteOpen = true
        }
    }
}
