import Foundation
import os.signpost

// MARK: - OSLog Extensions

extension OSLog {
    /// Signpost category for feed refresh operations
    static let feedRefresh = OSLog(subsystem: "com.patina.rss", category: "FeedRefresh")

    /// Signpost category for database operations
    static let database = OSLog(subsystem: "com.patina.rss", category: "Database")

    /// Signpost category for UI-related performance tracking
    static let ui = OSLog(subsystem: "com.patina.rss", category: "UI")

    /// Signpost category for serendipity/discovery features
    static let serendipity = OSLog(subsystem: "com.patina.rss", category: "Serendipity")
}

// MARK: - PerformanceSignpost

/// Helper struct for managing performance signposts in Instruments
///
/// Use this to measure the duration of operations in your code:
/// ```swift
/// let id = PerformanceSignpost.begin(.feedRefresh, name: "RefreshAllFeeds")
/// // ... perform operation ...
/// PerformanceSignpost.end(.feedRefresh, name: "RefreshAllFeeds", id: id)
/// ```
///
/// Or use the scoped version for automatic cleanup:
/// ```swift
/// await PerformanceSignpost.measure(.feedRefresh, name: "RefreshAllFeeds") {
///     await performRefresh()
/// }
/// ```
enum PerformanceSignpost {
    /// Begin a signpost interval
    /// - Parameters:
    ///   - log: The OSLog category to use
    ///   - name: The name of the operation (appears in Instruments timeline)
    /// - Returns: A signpost ID to use when ending the interval
    static func begin(_ log: OSLog, name: StaticString) -> OSSignpostID {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return id
    }

    /// End a signpost interval
    /// - Parameters:
    ///   - log: The OSLog category (must match the begin call)
    ///   - name: The name of the operation (must match the begin call)
    ///   - id: The signpost ID returned from begin()
    static func end(_ log: OSLog, name: StaticString, id: OSSignpostID) {
        os_signpost(.end, log: log, name: name, signpostID: id)
    }

    /// End a signpost interval with additional metadata
    /// - Parameters:
    ///   - log: The OSLog category (must match the begin call)
    ///   - name: The name of the operation (must match the begin call)
    ///   - id: The signpost ID returned from begin()
    ///   - message: Additional context to display in Instruments
    static func end(_ log: OSLog, name: StaticString, id: OSSignpostID, _ message: String) {
        os_signpost(.end, log: log, name: name, signpostID: id, "%{public}s", message)
    }

    /// Emit a single event (point in time, not an interval)
    /// - Parameters:
    ///   - log: The OSLog category to use
    ///   - name: The name of the event
    ///   - message: Optional message describing the event
    static func event(_ log: OSLog, name: StaticString, _ message: String? = nil) {
        guard let message else {
            os_signpost(.event, log: log, name: name)
            return
        }
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }

    /// Measure the duration of an async operation
    /// - Parameters:
    ///   - log: The OSLog category to use
    ///   - name: The name of the operation
    ///   - operation: The async operation to measure
    /// - Returns: The result of the operation
    @discardableResult
    static func measure<T>(
        _ log: OSLog,
        name: StaticString,
        operation: () async throws -> T
    ) async rethrows -> T {
        let id = begin(log, name: name)
        defer { end(log, name: name, id: id) }
        return try await operation()
    }

    /// Measure the duration of a synchronous operation
    /// - Parameters:
    ///   - log: The OSLog category to use
    ///   - name: The name of the operation
    ///   - operation: The operation to measure
    /// - Returns: The result of the operation
    @discardableResult
    static func measureSync<T>(
        _ log: OSLog,
        name: StaticString,
        operation: () throws -> T
    ) rethrows -> T {
        let id = begin(log, name: name)
        defer { end(log, name: name, id: id) }
        return try operation()
    }
}

// MARK: - SignpostScope

/// A scoped signpost that automatically ends when deallocated
///
/// Useful for measuring operations where you can't easily use defer:
/// ```swift
/// var scope: SignpostScope? = SignpostScope(.database, name: "LoadFeeds")
/// // ... operation ...
/// scope = nil  // Ends the signpost
/// ```
final class SignpostScope {
    private let log: OSLog
    private let name: StaticString
    private let id: OSSignpostID

    init(_ log: OSLog, name: StaticString) {
        self.log = log
        self.name = name
        self.id = PerformanceSignpost.begin(log, name: name)
    }

    deinit {
        PerformanceSignpost.end(log, name: name, id: id)
    }

    /// End the signpost with a message
    func end(message: String) {
        PerformanceSignpost.end(log, name: name, id: id, message)
    }
}
