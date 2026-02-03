use crate::storage::models::{ParsedArticle, ParsedFeed};
use crate::PatinaError;
use feed_rs::parser;

/// Fetch a feed from a URL and parse it
pub fn fetch_and_parse_feed(url: &str) -> Result<ParsedFeed, PatinaError> {
    let client = reqwest::blocking::Client::builder()
        .user_agent("Patina RSS Reader/1.0")
        .timeout(std::time::Duration::from_secs(30))
        .build()?;

    let response = client.get(url).send()?;
    let bytes = response.bytes()?;

    parse_feed_content(&bytes, url)
}

/// Parse feed content from bytes
pub fn parse_feed_content(content: &[u8], url: &str) -> Result<ParsedFeed, PatinaError> {
    let feed = parser::parse(content).map_err(|e| PatinaError::ParseError(e.to_string()))?;

    let title = feed
        .title
        .map(|t| t.content)
        .unwrap_or_else(|| "Untitled Feed".to_string());

    let site_url = feed.links.first().map(|l| l.href.clone());

    let articles: Vec<ParsedArticle> = feed
        .entries
        .into_iter()
        .filter_map(|entry| {
            let entry_url = entry.links.first().map(|l| l.href.clone())?;
            let entry_title = entry
                .title
                .map(|t| t.content)
                .unwrap_or_else(|| "Untitled".to_string());

            let summary = entry
                .summary
                .map(|s| s.content)
                .or_else(|| entry.content.and_then(|c| c.body));

            // Clean HTML from summary if present
            let summary = summary.map(|s| clean_html(&s));

            let published_at = entry
                .published
                .or(entry.updated)
                .map(|dt| dt.timestamp());

            Some(ParsedArticle {
                title: entry_title,
                url: entry_url,
                summary,
                published_at,
            })
        })
        .collect();

    Ok(ParsedFeed {
        title,
        url: url.to_string(),
        site_url,
        articles,
    })
}

/// Strip HTML tags from a string (simple implementation)
fn clean_html(html: &str) -> String {
    let mut result = String::new();
    let mut in_tag = false;
    let mut in_entity = false;
    let mut entity = String::new();

    for c in html.chars() {
        if c == '<' {
            in_tag = true;
        } else if c == '>' {
            in_tag = false;
        } else if c == '&' && !in_tag {
            in_entity = true;
            entity.clear();
        } else if c == ';' && in_entity {
            in_entity = false;
            // Decode common entities
            match entity.as_str() {
                "amp" => result.push('&'),
                "lt" => result.push('<'),
                "gt" => result.push('>'),
                "quot" => result.push('"'),
                "apos" => result.push('\''),
                "nbsp" => result.push(' '),
                _ => {
                    // Unknown entity, keep as-is
                    result.push('&');
                    result.push_str(&entity);
                    result.push(';');
                }
            }
        } else if in_entity {
            entity.push(c);
        } else if !in_tag {
            result.push(c);
        }
    }

    // Normalize whitespace
    let mut normalized = String::new();
    let mut last_was_space = true;
    for c in result.chars() {
        if c.is_whitespace() {
            if !last_was_space {
                normalized.push(' ');
                last_was_space = true;
            }
        } else {
            normalized.push(c);
            last_was_space = false;
        }
    }

    normalized.trim().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_clean_html() {
        assert_eq!(clean_html("<p>Hello</p>"), "Hello");
        assert_eq!(clean_html("Hello &amp; World"), "Hello & World");
        assert_eq!(clean_html("  Multiple   spaces  "), "Multiple spaces");
    }
}
