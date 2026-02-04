use crate::PatinaError;
use crate::storage::models::{Article, Feed, ParsedArticle, ParsedFeed, ReadingPattern};
use rusqlite::{Connection, Row, params};
use std::sync::Mutex;

/// Maps a database row to a Feed struct.
/// Expected columns: id, title, url, site_url, last_fetched_at, created_at, unread_count
fn map_feed_row(row: &Row) -> Result<Feed, rusqlite::Error> {
    Ok(Feed {
        id: row.get(0)?,
        title: row.get(1)?,
        url: row.get(2)?,
        site_url: row.get(3)?,
        last_fetched_at: row.get(4)?,
        created_at: row.get(5)?,
        unread_count: row.get(6)?,
    })
}

/// Maps a database row to an Article struct.
/// Expected columns: id, feed_id, title, url, summary, published_at, fetched_at, is_read, read_at, feed_title
fn map_article_row(row: &Row) -> Result<Article, rusqlite::Error> {
    Ok(Article {
        id: row.get(0)?,
        feed_id: row.get(1)?,
        title: row.get(2)?,
        url: row.get(3)?,
        summary: row.get(4)?,
        published_at: row.get(5)?,
        fetched_at: row.get(6)?,
        is_read: row.get::<_, i32>(7)? != 0,
        read_at: row.get(8)?,
        feed_title: row.get(9)?,
    })
}

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    pub fn new(path: &str) -> Result<Self, PatinaError> {
        let conn = Connection::open(path)?;

        // Enable WAL mode for better concurrent read/write performance
        conn.pragma_update(None, "journal_mode", "WAL")?;

        // Synchronous NORMAL is safe with WAL and much faster than FULL
        conn.pragma_update(None, "synchronous", "NORMAL")?;

        // Increase cache size (negative = KB, so -8000 = 8MB)
        conn.pragma_update(None, "cache_size", -8000)?;

        // Enable memory-mapped I/O for faster reads (64MB)
        conn.pragma_update(None, "mmap_size", 67108864)?;

        // Enable foreign keys
        conn.pragma_update(None, "foreign_keys", "ON")?;

        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    pub fn run_migrations(&self) -> Result<(), PatinaError> {
        let conn = self.conn.lock().unwrap();

        conn.execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS feeds (
                id INTEGER PRIMARY KEY,
                title TEXT NOT NULL,
                url TEXT NOT NULL UNIQUE,
                site_url TEXT,
                last_fetched_at INTEGER,
                created_at INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS articles (
                id INTEGER PRIMARY KEY,
                feed_id INTEGER NOT NULL REFERENCES feeds(id) ON DELETE CASCADE,
                title TEXT NOT NULL,
                url TEXT NOT NULL,
                summary TEXT,
                published_at INTEGER,
                fetched_at INTEGER NOT NULL,
                is_read INTEGER DEFAULT 0,
                read_at INTEGER,
                UNIQUE(feed_id, url)
            );

            CREATE TABLE IF NOT EXISTS reading_patterns (
                id INTEGER PRIMARY KEY,
                pattern_type TEXT NOT NULL,
                value TEXT NOT NULL,
                source TEXT NOT NULL,
                weight REAL DEFAULT 1.0,
                created_at INTEGER NOT NULL,
                UNIQUE(pattern_type, value)
            );

            CREATE TABLE IF NOT EXISTS article_topics (
                article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
                topic TEXT NOT NULL,
                score REAL,
                PRIMARY KEY(article_id, topic)
            );

            CREATE INDEX IF NOT EXISTS idx_articles_feed_id ON articles(feed_id);
            CREATE INDEX IF NOT EXISTS idx_articles_is_read ON articles(is_read);
            CREATE INDEX IF NOT EXISTS idx_articles_published_at ON articles(published_at);
            CREATE INDEX IF NOT EXISTS idx_article_topics_topic ON article_topics(topic);

            -- Composite index for efficient unread count per feed
            CREATE INDEX IF NOT EXISTS idx_articles_feed_unread ON articles(feed_id, is_read) WHERE is_read = 0;

            -- Composite index for sorting articles by date
            CREATE INDEX IF NOT EXISTS idx_articles_date_sort ON articles(published_at DESC);
            "#,
        )?;

        Ok(())
    }

    // Feed operations
    pub fn insert_feed(&self, feed: &ParsedFeed) -> Result<Feed, PatinaError> {
        let conn = self.conn.lock().unwrap();
        let now = chrono::Utc::now().timestamp();

        conn.execute(
            "INSERT INTO feeds (title, url, site_url, last_fetched_at, created_at) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![feed.title, feed.url, feed.site_url, now, now],
        )?;

        let id = conn.last_insert_rowid();

        Ok(Feed {
            id,
            title: feed.title.clone(),
            url: feed.url.clone(),
            site_url: feed.site_url.clone(),
            last_fetched_at: Some(now),
            created_at: now,
            unread_count: 0,
        })
    }

    pub fn get_feed(&self, id: i64) -> Result<Option<Feed>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
            r#"
            SELECT f.id, f.title, f.url, f.site_url, f.last_fetched_at, f.created_at,
                   (SELECT COUNT(*) FROM articles a WHERE a.feed_id = f.id AND a.is_read = 0) as unread_count
            FROM feeds f
            WHERE f.id = ?1
            "#,
        )?;

        let feed = stmt.query_row(params![id], map_feed_row).optional()?;

        Ok(feed)
    }

    pub fn get_all_feeds(&self) -> Result<Vec<Feed>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        // Correlated subquery is efficient here because it uses the partial covering index
        // idx_articles_feed_unread which only indexes unread articles
        let mut stmt = conn.prepare_cached(
            r#"
            SELECT f.id, f.title, f.url, f.site_url, f.last_fetched_at, f.created_at,
                   (SELECT COUNT(*) FROM articles a WHERE a.feed_id = f.id AND a.is_read = 0) as unread_count
            FROM feeds f
            ORDER BY f.title COLLATE NOCASE
            "#,
        )?;

        let feeds = stmt
            .query_map([], map_feed_row)?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(feeds)
    }

    pub fn delete_feed(&self, id: i64) -> Result<(), PatinaError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM feeds WHERE id = ?1", params![id])?;
        Ok(())
    }

    pub fn get_feed_by_url(&self, url: &str) -> Result<Option<Feed>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
            r#"
            SELECT f.id, f.title, f.url, f.site_url, f.last_fetched_at, f.created_at,
                   (SELECT COUNT(*) FROM articles a WHERE a.feed_id = f.id AND a.is_read = 0) as unread_count
            FROM feeds f
            WHERE f.url = ?1
            "#,
        )?;

        let feed = stmt.query_row(params![url], map_feed_row).optional()?;

        Ok(feed)
    }

    pub fn update_feed_metadata(&self, id: i64, feed: &ParsedFeed) -> Result<(), PatinaError> {
        let conn = self.conn.lock().unwrap();
        let now = chrono::Utc::now().timestamp();

        conn.execute(
            "UPDATE feeds SET title = ?1, site_url = ?2, last_fetched_at = ?3 WHERE id = ?4",
            params![feed.title, feed.site_url, now, id],
        )?;

        Ok(())
    }

    // Article operations
    pub fn insert_article(
        &self,
        feed_id: i64,
        article: &ParsedArticle,
    ) -> Result<Article, PatinaError> {
        let conn = self.conn.lock().unwrap();
        let now = chrono::Utc::now().timestamp();

        conn.execute(
            r#"
            INSERT OR IGNORE INTO articles (feed_id, title, url, summary, published_at, fetched_at, is_read)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, 0)
            "#,
            params![
                feed_id,
                article.title,
                article.url,
                article.summary,
                article.published_at,
                now
            ],
        )?;

        let id = conn.last_insert_rowid();

        Ok(Article {
            id,
            feed_id,
            title: article.title.clone(),
            url: article.url.clone(),
            summary: article.summary.clone(),
            published_at: article.published_at,
            fetched_at: now,
            is_read: false,
            read_at: None,
            feed_title: None,
        })
    }

    pub fn get_article(&self, id: i64) -> Result<Option<Article>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
            r#"
            SELECT a.id, a.feed_id, a.title, a.url, a.summary, a.published_at, a.fetched_at,
                   a.is_read, a.read_at, f.title as feed_title
            FROM articles a
            JOIN feeds f ON f.id = a.feed_id
            WHERE a.id = ?1
            "#,
        )?;

        let article = stmt.query_row(params![id], map_article_row).optional()?;

        Ok(article)
    }

    pub fn get_articles_for_feed(&self, feed_id: i64) -> Result<Vec<Article>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare_cached(
            r#"
            SELECT a.id, a.feed_id, a.title, a.url, a.summary, a.published_at, a.fetched_at,
                   a.is_read, a.read_at, f.title as feed_title
            FROM articles a
            JOIN feeds f ON f.id = a.feed_id
            WHERE a.feed_id = ?1
            ORDER BY COALESCE(a.published_at, a.fetched_at) DESC
            "#,
        )?;

        let articles = stmt
            .query_map(params![feed_id], map_article_row)?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(articles)
    }

    pub fn get_all_unread_articles(&self) -> Result<Vec<Article>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare_cached(
            r#"
            SELECT a.id, a.feed_id, a.title, a.url, a.summary, a.published_at, a.fetched_at,
                   a.is_read, a.read_at, f.title as feed_title
            FROM articles a
            JOIN feeds f ON f.id = a.feed_id
            WHERE a.is_read = 0
            ORDER BY a.published_at IS NULL, a.published_at DESC
            "#,
        )?;

        let articles = stmt
            .query_map([], map_article_row)?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(articles)
    }

    /// Get recent articles (both read and unread) sorted by publication date
    pub fn get_recent_articles(&self, limit: i32) -> Result<Vec<Article>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare_cached(
            r#"
            SELECT a.id, a.feed_id, a.title, a.url, a.summary, a.published_at, a.fetched_at,
                   a.is_read, a.read_at, f.title as feed_title
            FROM articles a
            JOIN feeds f ON f.id = a.feed_id
            ORDER BY a.published_at IS NULL, a.published_at DESC
            LIMIT ?1
            "#,
        )?;

        let articles = stmt
            .query_map([limit], map_article_row)?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(articles)
    }

    pub fn mark_article_read(&self, id: i64) -> Result<(), PatinaError> {
        let conn = self.conn.lock().unwrap();
        let now = chrono::Utc::now().timestamp();

        conn.execute(
            "UPDATE articles SET is_read = 1, read_at = ?1 WHERE id = ?2",
            params![now, id],
        )?;

        Ok(())
    }

    pub fn mark_article_unread(&self, id: i64) -> Result<(), PatinaError> {
        let conn = self.conn.lock().unwrap();

        conn.execute(
            "UPDATE articles SET is_read = 0, read_at = NULL WHERE id = ?1",
            params![id],
        )?;

        Ok(())
    }

    // Reading patterns
    pub fn get_reading_patterns(&self) -> Result<Vec<ReadingPattern>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
            "SELECT id, pattern_type, value, source, weight, created_at FROM reading_patterns ORDER BY weight DESC",
        )?;

        let patterns = stmt
            .query_map([], |row| {
                Ok(ReadingPattern {
                    id: row.get(0)?,
                    pattern_type: row.get(1)?,
                    value: row.get(2)?,
                    source: row.get(3)?,
                    weight: row.get(4)?,
                    created_at: row.get(5)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(patterns)
    }

    pub fn add_reading_pattern(
        &self,
        pattern_type: &str,
        value: &str,
        source: &str,
    ) -> Result<ReadingPattern, PatinaError> {
        let conn = self.conn.lock().unwrap();
        let now = chrono::Utc::now().timestamp();

        conn.execute(
            r#"
            INSERT INTO reading_patterns (pattern_type, value, source, weight, created_at)
            VALUES (?1, ?2, ?3, 1.0, ?4)
            ON CONFLICT(pattern_type, value) DO UPDATE SET weight = weight + 0.1
            "#,
            params![pattern_type, value, source, now],
        )?;

        let id = conn.last_insert_rowid();

        Ok(ReadingPattern {
            id,
            pattern_type: pattern_type.to_string(),
            value: value.to_string(),
            source: source.to_string(),
            weight: 1.0,
            created_at: now,
        })
    }

    pub fn delete_reading_pattern(&self, id: i64) -> Result<(), PatinaError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM reading_patterns WHERE id = ?1", params![id])?;
        Ok(())
    }

    pub fn reset_reading_patterns(&self) -> Result<(), PatinaError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM reading_patterns", [])?;
        Ok(())
    }

    // Article topics
    pub fn record_article_topic(
        &self,
        article_id: i64,
        topic: &str,
        score: f64,
    ) -> Result<(), PatinaError> {
        let conn = self.conn.lock().unwrap();

        conn.execute(
            "INSERT OR REPLACE INTO article_topics (article_id, topic, score) VALUES (?1, ?2, ?3)",
            params![article_id, topic, score],
        )?;

        Ok(())
    }

    pub fn get_unread_articles_with_topics(
        &self,
        topics: &[String],
        limit: i32,
    ) -> Result<Vec<Article>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        if topics.is_empty() {
            // No patterns, return random unread articles
            let mut stmt = conn.prepare_cached(
                r#"
                SELECT a.id, a.feed_id, a.title, a.url, a.summary, a.published_at, a.fetched_at,
                       a.is_read, a.read_at, f.title as feed_title
                FROM articles a
                JOIN feeds f ON f.id = a.feed_id
                WHERE a.is_read = 0
                ORDER BY RANDOM()
                LIMIT ?1
                "#,
            )?;

            let articles = stmt
                .query_map(params![limit], map_article_row)?
                .collect::<Result<Vec<_>, _>>()?;

            return Ok(articles);
        }

        // Use JSON array with json_each() - avoids temp table overhead and allows caching
        let topics_json = serde_json::to_string(topics).unwrap_or_else(|_| "[]".to_string());

        let mut stmt = conn.prepare_cached(
            r#"
            SELECT a.id, a.feed_id, a.title, a.url, a.summary, a.published_at, a.fetched_at,
                   a.is_read, a.read_at, f.title as feed_title,
                   COALESCE(topic_scores.total_score, 0) as topic_score
            FROM articles a
            JOIN feeds f ON f.id = a.feed_id
            LEFT JOIN (
                SELECT at.article_id, SUM(at.score) as total_score
                FROM article_topics at
                WHERE at.topic IN (SELECT value FROM json_each(?2))
                GROUP BY at.article_id
            ) topic_scores ON topic_scores.article_id = a.id
            WHERE a.is_read = 0
            ORDER BY topic_score DESC, RANDOM()
            LIMIT ?1
            "#,
        )?;

        let articles = stmt
            .query_map(params![limit, topics_json], map_article_row)?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(articles)
    }

    pub fn get_top_read_topics(&self, limit: i32) -> Result<Vec<(String, f64)>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
            r#"
            SELECT at.topic, SUM(at.score) as total_score
            FROM article_topics at
            JOIN articles a ON a.id = at.article_id
            WHERE a.is_read = 1
            GROUP BY at.topic
            ORDER BY total_score DESC
            LIMIT ?1
            "#,
        )?;

        let topics = stmt
            .query_map(params![limit], |row| Ok((row.get(0)?, row.get(1)?)))?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(topics)
    }
}

// Extension trait for Option
trait OptionalExt<T> {
    fn optional(self) -> Result<Option<T>, rusqlite::Error>;
}

impl<T> OptionalExt<T> for Result<T, rusqlite::Error> {
    fn optional(self) -> Result<Option<T>, rusqlite::Error> {
        match self {
            Ok(v) => Ok(Some(v)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }
}
