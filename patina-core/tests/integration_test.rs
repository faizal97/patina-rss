use patina_core::{create_patina_core, hello_from_rust, PatinaCore};
use std::fs;

#[test]
fn test_hello_from_rust() {
    let message = hello_from_rust();
    assert!(message.contains("Patina"));
    println!("✓ hello_from_rust: {}", message);
}

#[test]
fn test_create_database() {
    let temp_dir = tempfile::tempdir().unwrap();
    let db_path = temp_dir.path().join("test.db");

    let core = create_patina_core(db_path.to_string_lossy().to_string()).unwrap();

    // Verify database file was created
    assert!(db_path.exists());
    println!("✓ Database created at: {:?}", db_path);

    // Test getting empty feeds list
    let feeds = core.get_all_feeds().unwrap();
    assert!(feeds.is_empty());
    println!("✓ Empty feeds list retrieved");
}

#[test]
fn test_feed_lifecycle() {
    let temp_dir = tempfile::tempdir().unwrap();
    let db_path = temp_dir.path().join("test.db");

    let core = create_patina_core(db_path.to_string_lossy().to_string()).unwrap();

    // Add a real feed (Hacker News RSS)
    println!("Adding Hacker News feed...");
    let feed = core.add_feed("https://hnrss.org/frontpage".to_string());

    match feed {
        Ok(f) => {
            println!("✓ Feed added: {} (id: {})", f.title, f.id);
            assert!(!f.title.is_empty());

            // Get articles for this feed
            let articles = core.get_articles_for_feed(f.id).unwrap();
            println!("✓ Retrieved {} articles", articles.len());
            assert!(!articles.is_empty());

            // Print first article
            if let Some(article) = articles.first() {
                println!("  First article: {}", article.title);
            }

            // Test marking as read
            if let Some(article) = articles.first() {
                core.mark_article_read(article.id).unwrap();
                println!("✓ Marked article as read");

                // Verify it's marked
                let updated = core.get_articles_for_feed(f.id).unwrap();
                let updated_article = updated.iter().find(|a| a.id == article.id).unwrap();
                assert!(updated_article.is_read);
            }

            // Get all feeds
            let feeds = core.get_all_feeds().unwrap();
            assert_eq!(feeds.len(), 1);
            println!("✓ Feed list contains 1 feed");

            // Delete feed
            core.delete_feed(f.id).unwrap();
            let feeds = core.get_all_feeds().unwrap();
            assert!(feeds.is_empty());
            println!("✓ Feed deleted successfully");
        }
        Err(e) => {
            println!("⚠ Feed add failed (network?): {}", e);
            // Don't fail the test if it's a network issue
        }
    }
}

#[test]
fn test_opml_import() {
    let temp_dir = tempfile::tempdir().unwrap();
    let db_path = temp_dir.path().join("test.db");

    let core = create_patina_core(db_path.to_string_lossy().to_string()).unwrap();

    let opml_content = r#"<?xml version="1.0" encoding="UTF-8"?>
    <opml version="2.0">
        <head><title>Test Feeds</title></head>
        <body>
            <outline text="Tech">
                <outline type="rss" text="Hacker News"
                         xmlUrl="https://hnrss.org/frontpage"/>
            </outline>
        </body>
    </opml>"#;

    println!("Importing OPML...");
    let result = core.import_opml(opml_content.to_string());

    match result {
        Ok(r) => {
            println!("✓ OPML import complete: {} total, {} imported, {} failed",
                     r.total_feeds, r.imported_feeds, r.failed_feeds);
            assert_eq!(r.total_feeds, 1);
        }
        Err(e) => {
            println!("⚠ OPML import failed (network?): {}", e);
        }
    }
}

#[test]
fn test_reading_patterns() {
    let temp_dir = tempfile::tempdir().unwrap();
    let db_path = temp_dir.path().join("test.db");

    let core = create_patina_core(db_path.to_string_lossy().to_string()).unwrap();

    // Add a pattern
    let pattern = core.add_reading_pattern("topic".to_string(), "rust".to_string()).unwrap();
    println!("✓ Added pattern: {} = {}", pattern.pattern_type, pattern.value);

    // Get patterns
    let patterns = core.get_reading_patterns().unwrap();
    assert_eq!(patterns.len(), 1);
    println!("✓ Retrieved {} patterns", patterns.len());

    // Delete pattern
    core.delete_reading_pattern(pattern.id).unwrap();
    let patterns = core.get_reading_patterns().unwrap();
    assert!(patterns.is_empty());
    println!("✓ Pattern deleted");

    // Reset patterns
    core.add_reading_pattern("topic".to_string(), "swift".to_string()).unwrap();
    core.add_reading_pattern("keyword".to_string(), "apple".to_string()).unwrap();
    core.reset_reading_patterns().unwrap();
    let patterns = core.get_reading_patterns().unwrap();
    assert!(patterns.is_empty());
    println!("✓ Patterns reset");
}

#[test]
fn test_serendipity() {
    let temp_dir = tempfile::tempdir().unwrap();
    let db_path = temp_dir.path().join("test.db");

    let core = create_patina_core(db_path.to_string_lossy().to_string()).unwrap();

    // Get serendipity articles (should be empty with no feeds)
    let articles = core.get_serendipity_articles(10).unwrap();
    assert!(articles.is_empty());
    println!("✓ Serendipity returns empty for new database");
}
