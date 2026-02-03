//! Database operation benchmarks for Patina RSS
//!
//! These benchmarks measure the performance of database operations with
//! varying data sizes to identify potential bottlenecks.

use criterion::{BenchmarkId, Criterion, black_box, criterion_group, criterion_main};
use patina_core::storage::db::Database;
use patina_core::storage::models::{ParsedArticle, ParsedFeed};
use tempfile::TempDir;

/// Create a test database with migrations run
fn create_test_db() -> (TempDir, Database) {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let db = Database::new(db_path.to_str().unwrap()).unwrap();
    db.run_migrations().unwrap();
    (temp_dir, db)
}

/// Seed the database with test feeds
fn seed_feeds(db: &Database, count: usize) -> Vec<i64> {
    let mut feed_ids = Vec::with_capacity(count);

    for i in 0..count {
        let feed = ParsedFeed {
            title: format!("Test Feed {}", i),
            url: format!("https://example{}.com/feed.xml", i),
            site_url: Some(format!("https://example{}.com", i)),
            articles: Vec::new(),
        };

        let inserted = db.insert_feed(&feed).unwrap();
        feed_ids.push(inserted.id);
    }

    feed_ids
}

/// Seed articles for a specific feed
fn seed_articles(db: &Database, feed_id: i64, count: usize) {
    for i in 0..count {
        let article = ParsedArticle {
            title: format!("Article {} for feed {}", i, feed_id),
            url: format!("https://example.com/feed{}/article{}", feed_id, i),
            summary: Some(format!(
                "This is the summary for article {}. It contains some text about various topics \
                 including technology, science, and programming. The article discusses important \
                 developments in the field and provides insights into future trends.",
                i
            )),
            published_at: Some(chrono::Utc::now().timestamp() - (i as i64 * 3600)),
        };
        let _ = db.insert_article(feed_id, &article);
    }
}

/// Benchmark get_all_feeds with varying feed counts
fn bench_get_all_feeds(c: &mut Criterion) {
    let mut group = c.benchmark_group("get_all_feeds");

    for feed_count in [10, 100, 1000] {
        let (_temp_dir, db) = create_test_db();
        seed_feeds(&db, feed_count);

        group.bench_with_input(
            BenchmarkId::from_parameter(feed_count),
            &feed_count,
            |b, _| {
                b.iter(|| {
                    black_box(db.get_all_feeds().unwrap());
                });
            },
        );
    }

    group.finish();
}

/// Benchmark get_articles_for_feed with varying article counts
fn bench_get_articles_for_feed(c: &mut Criterion) {
    let mut group = c.benchmark_group("get_articles_for_feed");

    for article_count in [10, 100, 500] {
        let (_temp_dir, db) = create_test_db();
        let feed_id = seed_feeds(&db, 1)[0];
        seed_articles(&db, feed_id, article_count);

        group.bench_with_input(
            BenchmarkId::from_parameter(article_count),
            &article_count,
            |b, _| {
                b.iter(|| {
                    black_box(db.get_articles_for_feed(feed_id).unwrap());
                });
            },
        );
    }

    group.finish();
}

/// Benchmark get_all_unread_articles with varying total articles
fn bench_get_all_unread_articles(c: &mut Criterion) {
    let mut group = c.benchmark_group("get_all_unread_articles");

    for (feeds, articles_per_feed) in [(5, 20), (10, 50), (20, 100)] {
        let total = feeds * articles_per_feed;
        let (_temp_dir, db) = create_test_db();
        let feed_ids = seed_feeds(&db, feeds);

        for feed_id in &feed_ids {
            seed_articles(&db, *feed_id, articles_per_feed);
        }

        group.bench_with_input(BenchmarkId::from_parameter(total), &total, |b, _| {
            b.iter(|| {
                black_box(db.get_all_unread_articles().unwrap());
            });
        });
    }

    group.finish();
}

/// Benchmark get_unread_articles_with_topics for serendipity feature
fn bench_get_unread_articles_with_topics(c: &mut Criterion) {
    let mut group = c.benchmark_group("get_unread_articles_with_topics");

    // Setup: create database with articles and topics
    let (_temp_dir, db) = create_test_db();
    let feed_ids = seed_feeds(&db, 10);

    for feed_id in &feed_ids {
        seed_articles(&db, *feed_id, 100);
    }

    // Record some topics for articles
    for article_id in 1..=50 {
        let _ = db.record_article_topic(article_id, "rust", 0.8);
        let _ = db.record_article_topic(article_id, "programming", 0.6);
    }
    for article_id in 51..=100 {
        let _ = db.record_article_topic(article_id, "technology", 0.7);
        let _ = db.record_article_topic(article_id, "science", 0.5);
    }

    // Benchmark with different topic counts
    for topic_count in [0, 2, 5] {
        let topics: Vec<String> = ["rust", "programming", "technology", "science", "news"]
            .iter()
            .take(topic_count)
            .map(|s| s.to_string())
            .collect();

        group.bench_with_input(
            BenchmarkId::from_parameter(format!("{}_topics", topic_count)),
            &topics,
            |b, topics| {
                b.iter(|| {
                    black_box(db.get_unread_articles_with_topics(topics, 20).unwrap());
                });
            },
        );
    }

    group.finish();
}

/// Benchmark insert_article performance
fn bench_insert_article(c: &mut Criterion) {
    let mut group = c.benchmark_group("insert_article");

    let (_temp_dir, db) = create_test_db();
    let feed_id = seed_feeds(&db, 1)[0];

    let mut counter = 0;

    group.bench_function("single_insert", |b| {
        b.iter(|| {
            counter += 1;
            let article = ParsedArticle {
                title: format!("Benchmark Article {}", counter),
                url: format!("https://example.com/bench{}", counter),
                summary: Some("A benchmark article summary with some content.".to_string()),
                published_at: Some(chrono::Utc::now().timestamp()),
            };
            let _ = black_box(db.insert_article(feed_id, &article));
        });
    });

    group.finish();
}

/// Benchmark mark_article_read/unread operations
fn bench_mark_article_read(c: &mut Criterion) {
    let mut group = c.benchmark_group("mark_article_read");

    let (_temp_dir, db) = create_test_db();
    let feed_id = seed_feeds(&db, 1)[0];
    seed_articles(&db, feed_id, 100);

    group.bench_function("mark_read", |b| {
        let mut article_id = 1i64;
        b.iter(|| {
            black_box(db.mark_article_read(article_id).unwrap());
            article_id = (article_id % 100) + 1;
        });
    });

    group.bench_function("mark_unread", |b| {
        let mut article_id = 1i64;
        b.iter(|| {
            black_box(db.mark_article_unread(article_id).unwrap());
            article_id = (article_id % 100) + 1;
        });
    });

    group.finish();
}

criterion_group!(
    benches,
    bench_get_all_feeds,
    bench_get_articles_for_feed,
    bench_get_all_unread_articles,
    bench_get_unread_articles_with_topics,
    bench_insert_article,
    bench_mark_article_read,
);

criterion_main!(benches);
