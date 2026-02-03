use uniffi;

/// A feed subscription
#[derive(Debug, Clone, uniffi::Record)]
pub struct Feed {
    pub id: i64,
    pub title: String,
    pub url: String,
    pub site_url: Option<String>,
    pub last_fetched_at: Option<i64>,
    pub created_at: i64,
    pub unread_count: i32,
}

/// An article/entry from a feed
#[derive(Debug, Clone, uniffi::Record)]
pub struct Article {
    pub id: i64,
    pub feed_id: i64,
    pub title: String,
    pub url: String,
    pub summary: Option<String>,
    pub published_at: Option<i64>,
    pub fetched_at: i64,
    pub is_read: bool,
    pub read_at: Option<i64>,
    pub feed_title: Option<String>,
}

/// A feed discovered from a website
#[derive(Debug, Clone, uniffi::Record)]
pub struct DiscoveredFeed {
    pub url: String,
    pub title: Option<String>,
}

/// Result of importing an OPML file
#[derive(Debug, Clone, uniffi::Record)]
pub struct OpmlImportResult {
    pub total_feeds: i32,
    pub imported_feeds: i32,
    pub failed_feeds: i32,
    pub errors: Vec<String>,
}

/// A reading pattern for serendipity
#[derive(Debug, Clone, uniffi::Record)]
pub struct ReadingPattern {
    pub id: i64,
    pub pattern_type: String,
    pub value: String,
    pub source: String,
    pub weight: f64,
    pub created_at: i64,
}

/// Parsed feed data (internal use)
#[derive(Debug)]
pub struct ParsedFeed {
    pub title: String,
    pub url: String,
    pub site_url: Option<String>,
    pub articles: Vec<ParsedArticle>,
}

/// Parsed article data (internal use)
#[derive(Debug)]
pub struct ParsedArticle {
    pub title: String,
    pub url: String,
    pub summary: Option<String>,
    pub published_at: Option<i64>,
}

/// OPML feed entry (internal use)
#[derive(Debug)]
pub struct OpmlFeed {
    pub url: String,
    pub title: Option<String>,
}
