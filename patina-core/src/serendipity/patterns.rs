use crate::storage::db::Database;
use crate::PatinaError;
use std::collections::HashMap;

// Common stop words to filter out
const STOP_WORDS: &[&str] = &[
    "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
    "from", "as", "is", "was", "are", "were", "been", "be", "have", "has", "had", "do", "does",
    "did", "will", "would", "could", "should", "may", "might", "must", "shall", "can", "need",
    "dare", "ought", "used", "it", "its", "this", "that", "these", "those", "i", "you", "he",
    "she", "we", "they", "what", "which", "who", "whom", "where", "when", "why", "how", "all",
    "each", "every", "both", "few", "more", "most", "other", "some", "such", "no", "nor", "not",
    "only", "own", "same", "so", "than", "too", "very", "just", "also", "now", "new", "one",
    "two", "first", "last", "many", "much", "get", "got", "go", "going", "make", "made", "take",
    "use", "using", "via", "about", "into", "over", "after", "before", "between", "through",
];

/// Extract topics from article title and summary
/// Returns a list of (topic, score) tuples
pub fn extract_topics(title: &str, summary: Option<&str>) -> Result<Vec<(String, f64)>, PatinaError> {
    let mut word_counts: HashMap<String, usize> = HashMap::new();

    // Process title (higher weight)
    for word in tokenize(title) {
        if is_valid_topic_word(&word) {
            *word_counts.entry(word).or_insert(0) += 3; // Title words count more
        }
    }

    // Process summary
    if let Some(summary) = summary {
        for word in tokenize(summary) {
            if is_valid_topic_word(&word) {
                *word_counts.entry(word).or_insert(0) += 1;
            }
        }
    }

    // Convert to scored topics
    let total_count: usize = word_counts.values().sum();
    if total_count == 0 {
        return Ok(Vec::new());
    }

    let mut topics: Vec<(String, f64)> = word_counts
        .into_iter()
        .map(|(word, count)| {
            let score = count as f64 / total_count as f64;
            (word, score)
        })
        .filter(|(_, score)| *score >= 0.05) // Minimum threshold
        .collect();

    // Sort by score descending
    topics.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    // Take top 10 topics
    topics.truncate(10);

    Ok(topics)
}

/// Tokenize text into lowercase words
fn tokenize(text: &str) -> Vec<String> {
    text.split(|c: char| !c.is_alphanumeric())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_lowercase())
        .collect()
}

/// Check if a word is a valid topic word
fn is_valid_topic_word(word: &str) -> bool {
    // Must be at least 3 characters
    if word.len() < 3 {
        return false;
    }

    // Must not be a stop word
    if STOP_WORDS.contains(&word.as_ref()) {
        return false;
    }

    // Must not be all digits
    if word.chars().all(|c| c.is_ascii_digit()) {
        return false;
    }

    true
}

/// Update auto-detected reading patterns based on reading history
pub fn update_auto_patterns(db: &Database) -> Result<(), PatinaError> {
    // Get top topics from read articles
    let top_topics = db.get_top_read_topics(20)?;

    // Add/update auto patterns
    for (topic, score) in top_topics {
        if score >= 2.0 {
            // Minimum threshold for auto-detection
            db.add_reading_pattern("topic", &topic, "auto")?;
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_topics() {
        let topics = extract_topics(
            "Rust Programming Language Guide",
            Some("Learn how to write efficient systems programming with Rust"),
        )
        .unwrap();

        assert!(!topics.is_empty());
        assert!(topics.iter().any(|(t, _)| t == "rust"));
        assert!(topics.iter().any(|(t, _)| t == "programming"));
    }

    #[test]
    fn test_tokenize() {
        let tokens = tokenize("Hello, World! This is a test.");
        assert_eq!(tokens, vec!["hello", "world", "this", "is", "a", "test"]);
    }

    #[test]
    fn test_is_valid_topic_word() {
        assert!(is_valid_topic_word("rust"));
        assert!(is_valid_topic_word("programming"));
        assert!(!is_valid_topic_word("the")); // stop word
        assert!(!is_valid_topic_word("is")); // stop word
        assert!(!is_valid_topic_word("ab")); // too short
        assert!(!is_valid_topic_word("123")); // all digits
    }
}
