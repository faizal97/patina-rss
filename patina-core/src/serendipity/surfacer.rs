use crate::storage::db::Database;
use crate::storage::models::Article;
use crate::PatinaError;

/// Get serendipitous articles based on reading patterns
pub fn get_serendipity_articles(db: &Database, limit: i32) -> Result<Vec<Article>, PatinaError> {
    // Get current reading patterns
    let patterns = db.get_reading_patterns()?;

    // Extract topic values (excluding excluded patterns)
    let topics: Vec<String> = patterns
        .iter()
        .filter(|p| p.pattern_type == "topic" || p.pattern_type == "keyword")
        .map(|p| p.value.clone())
        .collect();

    let excluded: Vec<String> = patterns
        .iter()
        .filter(|p| p.pattern_type == "excluded")
        .map(|p| p.value.clone())
        .collect();

    // Get articles matching topics
    let mut articles = db.get_unread_articles_with_topics(&topics, limit * 2)?;

    // Filter out excluded topics
    if !excluded.is_empty() {
        articles.retain(|article| {
            let title_lower = article.title.to_lowercase();
            let summary_lower = article
                .summary
                .as_ref()
                .map(|s| s.to_lowercase())
                .unwrap_or_default();

            !excluded.iter().any(|ex| {
                let ex_lower = ex.to_lowercase();
                title_lower.contains(&ex_lower) || summary_lower.contains(&ex_lower)
            })
        });
    }

    // Take only the requested limit
    articles.truncate(limit as usize);

    Ok(articles)
}

#[cfg(test)]
mod tests {
    // Integration tests would go here, requiring a database
}
