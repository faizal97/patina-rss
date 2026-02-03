use crate::PatinaError;
use crate::feed::http::create_client;
use crate::storage::models::{ParsedArticle, ParsedFeed};
use feed_rs::parser;

/// Fetch a feed from a URL and parse it
pub fn fetch_and_parse_feed(url: &str) -> Result<ParsedFeed, PatinaError> {
    let client = create_client()?;
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

            let published_at = entry.published.or(entry.updated).map(|dt| dt.timestamp());

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

/// Strip HTML tags and decode entities from a string
pub fn clean_html(html: &str) -> String {
    // Single pass: strip tags + normalize whitespace
    // Pre-allocate since output will be smaller than input
    let mut result = String::with_capacity(html.len());
    let mut in_tag = false;
    let mut last_was_space = true; // Start true to skip leading whitespace

    for c in html.chars() {
        match c {
            '<' => in_tag = true,
            '>' => in_tag = false,
            _ if in_tag => {}
            c if c.is_whitespace() => {
                if !last_was_space {
                    result.push(' ');
                    last_was_space = true;
                }
            }
            c => {
                result.push(c);
                last_was_space = false;
            }
        }
    }

    // Trim trailing space if present
    if result.ends_with(' ') {
        result.pop();
    }

    // Decode HTML entities (handles &amp;, &lt;, &#123;, &#xAB;, etc.)
    html_escape::decode_html_entities(&result).into_owned()
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
