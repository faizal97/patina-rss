import Foundation
import Observation
import os.signpost

/// Main application state using Swift 5.9 @Observable macro
@MainActor
@Observable
final class AppState {
    // MARK: - Core State

    private(set) var core: PatinaCore?
    private(set) var isInitialized = false
    private(set) var initializationError: String?

    // MARK: - Data

    private(set) var feeds: [Feed] = []
    private(set) var articles: [Article] = []
    private(set) var serendipityArticles: [Article] = []
    private(set) var recentArticles: [Article] = []
    private(set) var readingPatterns: [ReadingPattern] = []

    // MARK: - Selection State

    var selectedFeedId: Int64?
    var selectedArticleId: Int64?

    // MARK: - UI State

    var showAddFeedSheet = false
    var showImportSheet = false
    var showPatternEditor = false
    var isLoading = false
    var errorMessage: String?
    var isFocusedMode = false

    // MARK: - Computed Properties

    var selectedFeed: Feed? {
        feeds.first { $0.id == selectedFeedId }
    }

    var selectedArticle: Article? {
        articles.first { $0.id == selectedArticleId }
    }

    var totalUnreadCount: Int32 {
        feeds.reduce(0) { $0 + $1.unreadCount }
    }

    // MARK: - Initialization

    init() {
        initializeCore()
    }

    private func initializeCore() {
        do {
            let dbPath = getAppSupportPath().appending("/patina.db")
            core = try PatinaCore(dbPath: dbPath)
            isInitialized = true

            // Load initial data
            Task {
                await loadFeeds()
                await loadReadingPatterns()
            }
        } catch {
            initializationError = "Failed to initialize: \(error.localizedDescription)"
        }
    }

    private func getAppSupportPath() -> String {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("Patina")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        return appSupportDir.path
    }

    // MARK: - Feed Management

    func loadFeeds() async {
        guard let core else { return }

        await PerformanceSignpost.measure(.database, name: "LoadFeeds") {
            do {
                feeds = try core.getAllFeeds()
            } catch {
                errorMessage = "Failed to load feeds: \(error.localizedDescription)"
            }
        }
    }

    func addFeed(url: String) async {
        guard let core else { return }

        isLoading = true
        defer { isLoading = false }

        let signpostId = PerformanceSignpost.begin(.feedRefresh, name: "AddFeed")
        defer { PerformanceSignpost.end(.feedRefresh, name: "AddFeed", id: signpostId) }

        do {
            let feed = try core.addFeed(url: url)
            feeds.append(feed)
            feeds.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            selectedFeedId = feed.id
            await loadArticlesForSelectedFeed()
        } catch let error as PatinaError {
            // Handle specific error types with friendlier messages
            let message = error.localizedDescription
            if message.contains("Feed already exists") {
                errorMessage = "This feed is already in your library"
            } else if message.contains("Network error") {
                errorMessage = "Could not connect to feed. Check the URL and try again."
            } else if message.contains("Parse error") {
                errorMessage = "This URL doesn't appear to be a valid RSS/Atom feed."
            } else {
                errorMessage = "Failed to add feed: \(message)"
            }
        } catch {
            errorMessage = "Failed to add feed: \(error.localizedDescription)"
        }
    }

    func deleteFeed(_ feedId: Int64) async {
        guard let core else { return }

        do {
            try core.deleteFeed(feedId: feedId)
            feeds.removeAll { $0.id == feedId }
            if selectedFeedId == feedId {
                selectedFeedId = nil
                articles = []
            }
        } catch {
            errorMessage = "Failed to delete feed: \(error.localizedDescription)"
        }
    }

    func refreshFeed(_ feedId: Int64) async {
        guard let core else { return }

        let signpostId = PerformanceSignpost.begin(.feedRefresh, name: "RefreshFeed")
        defer { PerformanceSignpost.end(.feedRefresh, name: "RefreshFeed", id: signpostId, "Feed \(feedId)") }

        do {
            let updatedFeed = try core.refreshFeed(feedId: feedId)
            if let index = feeds.firstIndex(where: { $0.id == feedId }) {
                feeds[index] = updatedFeed
            }
            if selectedFeedId == feedId {
                await loadArticlesForSelectedFeed()
            }
        } catch {
            errorMessage = "Failed to refresh feed: \(error.localizedDescription)"
        }
    }

    func refreshAllFeeds() async {
        guard let core else { return }

        isLoading = true
        defer { isLoading = false }

        let signpostId = PerformanceSignpost.begin(.feedRefresh, name: "RefreshAllFeeds")
        defer { PerformanceSignpost.end(.feedRefresh, name: "RefreshAllFeeds", id: signpostId, "\(feeds.count) feeds") }

        do {
            feeds = try core.refreshAllFeeds()
            if selectedFeedId != nil {
                await loadArticlesForSelectedFeed()
            }
        } catch {
            errorMessage = "Failed to refresh feeds: \(error.localizedDescription)"
        }
    }

    // MARK: - Feed Discovery

    func discoverFeeds(websiteUrl: String) async -> [DiscoveredFeed] {
        guard let core else { return [] }

        do {
            return try core.discoverFeeds(websiteUrl: websiteUrl)
        } catch {
            errorMessage = "Failed to discover feeds: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Article Management

    func loadArticlesForSelectedFeed() async {
        guard let core, let feedId = selectedFeedId else {
            articles = []
            return
        }

        await PerformanceSignpost.measure(.database, name: "LoadArticles") {
            do {
                articles = try core.getArticlesForFeed(feedId: feedId)
            } catch {
                errorMessage = "Failed to load articles: \(error.localizedDescription)"
            }
        }
    }

    func loadAllUnreadArticles() async {
        guard let core else { return }

        do {
            articles = try core.getAllUnreadArticles()
        } catch {
            errorMessage = "Failed to load unread articles: \(error.localizedDescription)"
        }
    }

    func markArticleRead(_ articleId: Int64) async {
        guard let core else { return }

        do {
            try core.markArticleRead(articleId: articleId)
            if let index = articles.firstIndex(where: { $0.id == articleId }) {
                // Create updated article with isRead = true
                let article = articles[index]
                articles[index] = Article(
                    id: article.id,
                    feedId: article.feedId,
                    title: article.title,
                    url: article.url,
                    summary: article.summary,
                    publishedAt: article.publishedAt,
                    fetchedAt: article.fetchedAt,
                    isRead: true,
                    readAt: Int64(Date().timeIntervalSince1970),
                    feedTitle: article.feedTitle
                )
            }
            // Update feed unread count
            await loadFeeds()
        } catch {
            errorMessage = "Failed to mark article as read: \(error.localizedDescription)"
        }
    }

    func markArticleUnread(_ articleId: Int64) async {
        guard let core else { return }

        do {
            try core.markArticleUnread(articleId: articleId)
            if let index = articles.firstIndex(where: { $0.id == articleId }) {
                let article = articles[index]
                articles[index] = Article(
                    id: article.id,
                    feedId: article.feedId,
                    title: article.title,
                    url: article.url,
                    summary: article.summary,
                    publishedAt: article.publishedAt,
                    fetchedAt: article.fetchedAt,
                    isRead: false,
                    readAt: nil,
                    feedTitle: article.feedTitle
                )
            }
            await loadFeeds()
        } catch {
            errorMessage = "Failed to mark article as unread: \(error.localizedDescription)"
        }
    }

    // MARK: - OPML Import

    func importOPML(content: String) async -> OpmlImportResult? {
        guard let core else { return nil }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try core.importOpml(opmlContent: content)
            await loadFeeds()
            return result
        } catch {
            errorMessage = "Failed to import OPML: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Serendipity

    func loadSerendipityArticles() async {
        guard let core else { return }

        await PerformanceSignpost.measure(.serendipity, name: "LoadSerendipity") {
            do {
                serendipityArticles = try core.getSerendipityArticles(limit: 20)
            } catch {
                errorMessage = "Failed to load serendipity articles: \(error.localizedDescription)"
            }
        }
    }

    func loadRecentArticles() async {
        guard let core else { return }

        do {
            recentArticles = try core.getRecentArticles(limit: 50)
        } catch {
            errorMessage = "Failed to load recent articles: \(error.localizedDescription)"
        }
    }

    func loadReadingPatterns() async {
        guard let core else { return }

        do {
            readingPatterns = try core.getReadingPatterns()
        } catch {
            errorMessage = "Failed to load reading patterns: \(error.localizedDescription)"
        }
    }

    func addReadingPattern(type: String, value: String) async {
        guard let core else { return }

        do {
            let pattern = try core.addReadingPattern(patternType: type, value: value)
            readingPatterns.append(pattern)
        } catch {
            errorMessage = "Failed to add reading pattern: \(error.localizedDescription)"
        }
    }

    func deleteReadingPattern(_ patternId: Int64) async {
        guard let core else { return }

        do {
            try core.deleteReadingPattern(patternId: patternId)
            readingPatterns.removeAll { $0.id == patternId }
        } catch {
            errorMessage = "Failed to delete reading pattern: \(error.localizedDescription)"
        }
    }

    func resetReadingPatterns() async {
        guard let core else { return }

        do {
            try core.resetReadingPatterns()
            readingPatterns = []
        } catch {
            errorMessage = "Failed to reset reading patterns: \(error.localizedDescription)"
        }
    }
}
