import XCTest
@testable import Patina

/// Performance tests for Patina RSS core operations
///
/// These tests use XCTest's measure() to provide reproducible benchmarks
/// for key operations. Run with Cmd+U or via xcodebuild test.
///
/// Note: Tests that require seeded data are limited because adding feeds
/// requires network calls. For comprehensive benchmarks with seeded data,
/// see the Rust Criterion benchmarks in patina-core/benches/.
final class PerformanceTests: XCTestCase {

    private var testDbPath: String!
    private var core: PatinaCore!

    override func setUpWithError() throws {
        // Create a unique temp database for each test
        let tempDir = FileManager.default.temporaryDirectory
        testDbPath = tempDir.appendingPathComponent("patina_perf_test_\(UUID().uuidString).db").path
        core = try createPatinaCore(dbPath: testDbPath)
    }

    override func tearDownWithError() throws {
        core = nil
        // Clean up test database
        try? FileManager.default.removeItem(atPath: testDbPath)
    }

    // MARK: - Core Initialization

    /// Measures the time to initialize PatinaCore (creates DB, runs migrations)
    func testPerformance_CoreInitialization() throws {
        let tempDir = FileManager.default.temporaryDirectory

        measure {
            let dbPath = tempDir.appendingPathComponent("patina_init_\(UUID().uuidString).db").path
            _ = try? createPatinaCore(dbPath: dbPath)
            try? FileManager.default.removeItem(atPath: dbPath)
        }
    }

    // MARK: - UniFFI Bridge Overhead

    /// Measures simple Rust function call overhead via UniFFI
    func testPerformance_HelloFromRust() throws {
        measure {
            for _ in 0..<1000 {
                _ = helloFromRust()
            }
        }
    }

    // MARK: - Empty Database Operations

    /// Measures getAllFeeds with empty database
    func testPerformance_GetAllFeeds_Empty() throws {
        measure {
            _ = try? core.getAllFeeds()
        }
    }

    /// Measures getAllUnreadArticles with empty database
    func testPerformance_GetAllUnreadArticles_Empty() throws {
        measure {
            _ = try? core.getAllUnreadArticles()
        }
    }

    /// Measures getSerendipityArticles with empty database
    func testPerformance_GetSerendipityArticles_Empty() throws {
        measure {
            _ = try? core.getSerendipityArticles(limit: 20)
        }
    }

    /// Measures getRecentArticles with empty database
    func testPerformance_GetRecentArticles_Empty() throws {
        measure {
            _ = try? core.getRecentArticles(limit: 50)
        }
    }

    /// Measures getReadingPatterns with empty database
    func testPerformance_GetReadingPatterns_Empty() throws {
        measure {
            _ = try? core.getReadingPatterns()
        }
    }

    // MARK: - Reading Patterns Operations

    /// Measures adding a reading pattern
    func testPerformance_AddReadingPattern() throws {
        var patternIndex = 0

        measure {
            _ = try? core.addReadingPattern(
                patternType: "topic",
                value: "test_topic_\(patternIndex)"
            )
            patternIndex += 1
        }

        // Cleanup
        try? core.resetReadingPatterns()
    }

    /// Measures getReadingPatterns with 100 patterns
    func testPerformance_GetReadingPatterns_With100() throws {
        // Seed 100 patterns
        for i in 0..<100 {
            _ = try? core.addReadingPattern(patternType: "topic", value: "topic_\(i)")
        }

        measure {
            _ = try? core.getReadingPatterns()
        }
    }

    // MARK: - Feed Discovery (requires network but measures parsing)

    /// Measures discover feeds for an invalid URL (tests error path performance)
    func testPerformance_DiscoverFeeds_InvalidUrl() throws {
        measure {
            // This will fail fast since URL is invalid
            _ = try? core.discoverFeeds(websiteUrl: "not-a-valid-url")
        }
    }
}

// MARK: - OPML Parsing Performance Tests

/// Tests for OPML parsing performance (no network required)
final class OPMLPerformanceTests: XCTestCase {

    private var testDbPath: String!
    private var core: PatinaCore!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        testDbPath = tempDir.appendingPathComponent("patina_opml_test_\(UUID().uuidString).db").path
        core = try createPatinaCore(dbPath: testDbPath)
    }

    override func tearDownWithError() throws {
        core = nil
        try? FileManager.default.removeItem(atPath: testDbPath)
    }

    /// Generates OPML content with specified number of feeds
    private func generateOPML(feedCount: Int) -> String {
        var opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head><title>Benchmark Feeds</title></head>
            <body>
        """

        for i in 0..<feedCount {
            opml += """
                    <outline type="rss" text="Feed \(i)" xmlUrl="https://invalid-benchmark-url-\(i).test/feed.xml"/>

            """
        }

        opml += """
            </body>
        </opml>
        """

        return opml
    }

    /// Measures OPML parsing with 10 feeds
    /// Note: importOpml tries to fetch each feed, so this measures parse + network failures
    func testPerformance_ImportOPML_10Feeds_ParseOnly() throws {
        let opml = generateOPML(feedCount: 10)

        // This will parse the OPML and fail on each feed fetch (invalid URLs)
        // We're primarily measuring the parsing overhead
        measure {
            _ = try? core.importOpml(opmlContent: opml)
        }
    }

    /// Measures OPML parsing with 50 feeds
    func testPerformance_ImportOPML_50Feeds_ParseOnly() throws {
        let opml = generateOPML(feedCount: 50)

        measure {
            _ = try? core.importOpml(opmlContent: opml)
        }
    }
}

// MARK: - Swift-side Operations

/// Tests for Swift-specific operations (not going through Rust)
final class SwiftPerformanceTests: XCTestCase {

    /// Measures OSLog signpost creation overhead
    func testPerformance_SignpostCreation() throws {
        measure {
            for _ in 0..<1000 {
                let id = PerformanceSignpost.begin(.database, name: "BenchmarkOp")
                PerformanceSignpost.end(.database, name: "BenchmarkOp", id: id)
            }
        }
    }
}
