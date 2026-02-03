use crate::storage::models::{Article, Feed, ParsedArticle, ParsedFeed, ReadingPattern};
use crate::PatinaError;
use rusqlite::{params, Connection};
use std::sync::Mutex;

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    pub fn new(path: &str) -> Result<Self, PatinaError> {
        let conn = Connection::open(path)?;
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

        let feed = stmt
            .query_row(params![id], |row| {
                Ok(Feed {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    url: row.get(2)?,
                    site_url: row.get(3)?,
                    last_fetched_at: row.get(4)?,
                    created_at: row.get(5)?,
                    unread_count: row.get(6)?,
                })
            })
            .optional()?;

        Ok(feed)
    }

    pub fn get_all_feeds(&self) -> Result<Vec<Feed>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
            r#"
            SELECT f.id, f.title, f.url, f.site_url, f.last_fetched_at, f.created_at,
                   (SELECT COUNT(*) FROM articles a WHERE a.feed_id = f.id AND a.is_read = 0) as unread_count
            FROM feeds f
            ORDER BY f.title COLLATE NOCASE
            "#,
        )?;

        let feeds = stmt
            .query_map([], |row| {
                Ok(Feed {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    url: row.get(2)?,
                    site_url: row.get(3)?,
                    last_fetched_at: row.get(4)?,
                    created_at: row.get(5)?,
                    unread_count: row.get(6)?,
                })
            })?
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

        let feed = stmt
            .query_row(params![url], |row| {
                Ok(Feed {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    url: row.get(2)?,
                    site_url: row.get(3)?,
                    last_fetched_at: row.get(4)?,
                    created_at: row.get(5)?,
                    unread_count: row.get(6)?,
                })
            })
            .optional()?;

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
    pub fn insert_article(&self, feed_id: i64, article: &ParsedArticle) -> Result<Article, PatinaError> {
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

        let article = stmt
            .query_row(params![id], |row| {
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
            })
            .optional()?;

        Ok(article)
    }

    pub fn get_articles_for_feed(&self, feed_id: i64) -> Result<Vec<Article>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
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
            .query_map(params![feed_id], |row| {
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
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(articles)
    }

    pub fn get_all_unread_articles(&self) -> Result<Vec<Article>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
            r#"
            SELECT a.id, a.feed_id, a.title, a.url, a.summary, a.published_at, a.fetched_at,
                   a.is_read, a.read_at, f.title as feed_title
            FROM articles a
            JOIN feeds f ON f.id = a.feed_id
            WHERE a.is_read = 0
            ORDER BY COALESCE(a.published_at, a.fetched_at) DESC
            "#,
        )?;

        let articles = stmt
            .query_map([], |row| {
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
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(articles)
    }

    /// Get recent articles (both read and unread) sorted by publication date
    pub fn get_recent_articles(&self, limit: i32) -> Result<Vec<Article>, PatinaError> {
        let conn = self.conn.lock().unwrap();

        let mut stmt = conn.prepare(
            r#"
            SELECT a.id, a.feed_id, a.title, a.url, a.summary, a.published_at, a.fetched_at,
                   a.is_read, a.read_at, f.title as feed_title
            FROM articles a
            JOIN feeds f ON f.id = a.feed_id
            ORDER BY COALESCE(a.published_at, a.fetched_at) DESC
            LIMIT ?1
            "#,
        )?;

        let articles = stmt
            .query_map([limit], |row| {
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
            })?
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
    pub fn record_article_topic(&self, article_id: i64, topic: &str, score: f64) -> Result<(), PatinaError> {
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
            let mut stmt = conn.prepare(
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
                .query_map(params![limit], |row| {
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
                })?
                .collect::<Result<Vec<_>, _>>()?;

            return Ok(articles);
        }

        // Build query with topic matching
        let placeholders: Vec<String> = topics.iter().enumerate().map(|(i, _)| format!("?{}", i + 2)).collect();
        let query = format!(
            r#"
            SELECT DISTINCT a.id, a.feed_id, a.title, a.url, a.summary, a.published_at, a.fetched_at,
                   a.is_read, a.read_at, f.title as feed_title,
                   COALESCE(SUM(at.score), 0) as topic_score
            FROM articles a
            JOIN feeds f ON f.id = a.feed_id
            LEFT JOIN article_topics at ON at.article_id = a.id AND at.topic IN ({})
            WHERE a.is_read = 0
            GROUP BY a.id
            ORDER BY topic_score DESC, RANDOM()
            LIMIT ?1
            "#,
            placeholders.join(", ")
        );

        let mut stmt = conn.prepare(&query)?;

        // Bind parameters
        let mut params_vec: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();
        params_vec.push(Box::new(limit));
        for topic in topics {
            params_vec.push(Box::new(topic.clone()));
        }

        let refs: Vec<&dyn rusqlite::ToSql> = params_vec.iter().map(|b| b.as_ref()).collect();

        let articles = stmt
            .query_map(refs.as_slice(), |row| {
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
            })?
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
