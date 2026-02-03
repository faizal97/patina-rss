pub mod feed;
pub mod http;
pub mod serendipity;
pub mod storage;

use storage::db::Database;
use storage::models::{Article, DiscoveredFeed, Feed, OpmlImportResult, ReadingPattern};
use std::sync::Arc;
use thiserror::Error;

// Use setup_scaffolding for proc-macro based bindings
uniffi::setup_scaffolding!();

#[derive(Error, Debug, uniffi::Error)]
#[uniffi(flat_error)]
pub enum PatinaError {
    #[error("Database error: {0}")]
    DatabaseError(String),
    #[error("Network error: {0}")]
    NetworkError(String),
    #[error("Parse error: {0}")]
    ParseError(String),
    #[error("Not found")]
    NotFound,
    #[error("Invalid URL: {0}")]
    InvalidUrl(String),
    #[error("IO error: {0}")]
    IoError(String),
    #[error("Feed already exists: {0}")]
    FeedAlreadyExists(String),
}

impl From<rusqlite::Error> for PatinaError {
    fn from(e: rusqlite::Error) -> Self {
        PatinaError::DatabaseError(e.to_string())
    }
}

impl From<reqwest::Error> for PatinaError {
    fn from(e: reqwest::Error) -> Self {
        PatinaError::NetworkError(e.to_string())
    }
}

impl From<url::ParseError> for PatinaError {
    fn from(e: url::ParseError) -> Self {
        PatinaError::InvalidUrl(e.to_string())
    }
}

impl From<std::io::Error> for PatinaError {
    fn from(e: std::io::Error) -> Self {
        PatinaError::IoError(e.to_string())
    }
}

/// Simple hello function to verify the bridge works
#[uniffi::export]
pub fn hello_from_rust() -> String {
    "Hello from Rust! Patina Core is ready.".to_string()
}

/// Factory function to create PatinaCore
#[uniffi::export]
pub fn create_patina_core(db_path: String) -> Result<Arc<PatinaCore>, PatinaError> {
    Ok(Arc::new(PatinaCore::new(db_path)?))
}

/// The main interface to the Patina RSS core functionality
#[derive(uniffi::Object)]
pub struct PatinaCore {
    db: Database,
}

#[uniffi::export]
impl PatinaCore {
    #[uniffi::constructor]
    pub fn new(db_path: String) -> Result<Self, PatinaError> {
        let db = Database::new(&db_path)?;
        db.run_migrations()?;
        Ok(Self { db })
    }

    // Feed management
    pub fn add_feed(&self, url: String) -> Result<Feed, PatinaError> {
        let url = url::Url::parse(&url)?;

        // Check if feed already exists
        if let Some(existing_feed) = self.db.get_feed_by_url(url.as_str())? {
            return Err(PatinaError::FeedAlreadyExists(existing_feed.title));
        }

        let feed_data = feed::parser::fetch_and_parse_feed(url.as_str())?;
        let feed = self.db.insert_feed(&feed_data)?;

        // Insert articles
        for article in feed_data.articles {
            let _ = self.db.insert_article(feed.id, &article);
        }

        // Return feed with updated unread count
        self.db.get_feed(feed.id)?.ok_or(PatinaError::NotFound)
    }

    pub fn get_all_feeds(&self) -> Result<Vec<Feed>, PatinaError> {
        self.db.get_all_feeds()
    }

    pub fn delete_feed(&self, feed_id: i64) -> Result<(), PatinaError> {
        self.db.delete_feed(feed_id)
    }

    pub fn refresh_feed(&self, feed_id: i64) -> Result<Feed, PatinaError> {
        let feed = self.db.get_feed(feed_id)?.ok_or(PatinaError::NotFound)?;
        let feed_data = feed::parser::fetch_and_parse_feed(&feed.url)?;

        // Update feed metadata
        self.db.update_feed_metadata(feed_id, &feed_data)?;

        // Insert new articles (duplicates will be ignored)
        for article in feed_data.articles {
            let _ = self.db.insert_article(feed_id, &article);
        }

        // Return updated feed
        self.db.get_feed(feed_id)?.ok_or(PatinaError::NotFound)
    }

    pub fn refresh_all_feeds(&self) -> Result<Vec<Feed>, PatinaError> {
        let feeds = self.db.get_all_feeds()?;
        let mut results = Vec::new();

        for feed in feeds {
            match self.refresh_feed(feed.id) {
                Ok(updated_feed) => results.push(updated_feed),
                Err(_) => results.push(feed), // Keep original on error
            }
        }

        Ok(results)
    }

    // Feed discovery
    pub fn discover_feeds(&self, website_url: String) -> Result<Vec<DiscoveredFeed>, PatinaError> {
        feed::discovery::discover_feeds(&website_url)
    }

    // Article management
    pub fn get_articles_for_feed(&self, feed_id: i64) -> Result<Vec<Article>, PatinaError> {
        self.db.get_articles_for_feed(feed_id)
    }

    pub fn get_all_unread_articles(&self) -> Result<Vec<Article>, PatinaError> {
        self.db.get_all_unread_articles()
    }

    pub fn get_recent_articles(&self, limit: i32) -> Result<Vec<Article>, PatinaError> {
        self.db.get_recent_articles(limit)
    }

    pub fn mark_article_read(&self, article_id: i64) -> Result<(), PatinaError> {
        self.db.mark_article_read(article_id)?;

        // Record reading for serendipity
        if let Ok(Some(article)) = self.db.get_article(article_id) {
            self.serendipity_record_reading(&article);
        }

        Ok(())
    }

    pub fn mark_article_unread(&self, article_id: i64) -> Result<(), PatinaError> {
        self.db.mark_article_unread(article_id)
    }

    // OPML import
    pub fn import_opml(&self, opml_content: String) -> Result<OpmlImportResult, PatinaError> {
        let feeds = feed::opml::parse_opml(&opml_content)?;
        let total_feeds = feeds.len() as i32;
        let mut imported_feeds = 0;
        let mut failed_feeds = 0;
        let mut errors = Vec::new();

        for opml_feed in feeds {
            match self.add_feed(opml_feed.url.clone()) {
                Ok(_) => imported_feeds += 1,
                Err(e) => {
                    failed_feeds += 1;
                    errors.push(format!("{}: {}", opml_feed.url, e));
                }
            }
        }

        Ok(OpmlImportResult {
            total_feeds,
            imported_feeds,
            failed_feeds,
            errors,
        })
    }

    // Serendipity
    pub fn get_serendipity_articles(&self, limit: i32) -> Result<Vec<Article>, PatinaError> {
        serendipity::surfacer::get_serendipity_articles(&self.db, limit)
    }

    pub fn get_reading_patterns(&self) -> Result<Vec<ReadingPattern>, PatinaError> {
        self.db.get_reading_patterns()
    }

    pub fn add_reading_pattern(
        &self,
        pattern_type: String,
        value: String,
    ) -> Result<ReadingPattern, PatinaError> {
        self.db.add_reading_pattern(&pattern_type, &value, "manual")
    }

    pub fn delete_reading_pattern(&self, pattern_id: i64) -> Result<(), PatinaError> {
        self.db.delete_reading_pattern(pattern_id)
    }

    pub fn reset_reading_patterns(&self) -> Result<(), PatinaError> {
        self.db.reset_reading_patterns()
    }
}

impl PatinaCore {
    // Internal serendipity helper (not exported)
    fn serendipity_record_reading(&self, article: &Article) {
        // Extract topics and record reading
        if let Ok(topics) = serendipity::patterns::extract_topics(&article.title, article.summary.as_deref()) {
            for topic in topics {
                let _ = self.db.record_article_topic(article.id, &topic.0, topic.1);
            }
            // Update auto patterns
            let _ = serendipity::patterns::update_auto_patterns(&self.db);
        }
    }
}
