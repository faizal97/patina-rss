import Foundation

/// Represents the possible navigation destinations in the immersive navigation flow
enum NavigationDestination: Equatable, Hashable {
    /// The feeds list screen (home)
    case feeds

    /// The articles list for a specific feed
    case articles(feedId: Int64, feedTitle: String)

    /// The reader view for a specific article
    case reader(articleId: Int64)
}
