use crate::PatinaError;
use crate::feed::http::create_client;
use crate::storage::models::DiscoveredFeed;
use scraper::{Html, Selector};

/// Discover RSS/Atom feeds from a website URL
pub fn discover_feeds(website_url: &str) -> Result<Vec<DiscoveredFeed>, PatinaError> {
    let client = create_client()?;
    let response = client.get(website_url).send()?;
    let html = response.text()?;

    let base_url = url::Url::parse(website_url)?;
    let feeds = parse_feed_links(&html, &base_url)?;

    Ok(feeds)
}

/// Parse HTML to find feed links
fn parse_feed_links(html: &str, base_url: &url::Url) -> Result<Vec<DiscoveredFeed>, PatinaError> {
    let document = Html::parse_document(html);

    // Select link elements with type="application/rss+xml" or type="application/atom+xml"
    let selector = Selector::parse(
        r#"link[rel="alternate"][type="application/rss+xml"],
           link[rel="alternate"][type="application/atom+xml"],
           link[rel="alternate"][type="text/xml"],
           a[href*="rss"], a[href*="feed"], a[href*="atom"]"#,
    )
    .map_err(|e| PatinaError::ParseError(format!("Invalid selector: {:?}", e)))?;

    let mut feeds = Vec::new();
    let mut seen_urls = std::collections::HashSet::new();

    for element in document.select(&selector) {
        let href = element.value().attr("href");

        if let Some(href) = href {
            // Resolve relative URLs
            let feed_url = match base_url.join(href) {
                Ok(url) => url.to_string(),
                Err(_) => continue,
            };

            // Skip if we've seen this URL
            if !seen_urls.insert(feed_url.clone()) {
                continue;
            }

            let title = element
                .value()
                .attr("title")
                .map(|s| s.to_string())
                .or_else(|| {
                    // Try to get text content for <a> tags
                    let text: String = element.text().collect();
                    let text = text.trim();
                    if !text.is_empty() {
                        Some(text.to_string())
                    } else {
                        None
                    }
                });

            feeds.push(DiscoveredFeed {
                url: feed_url,
                title,
            });
        }
    }

    // Also check common feed URL patterns
    let common_patterns = [
        "/feed",
        "/feed/",
        "/rss",
        "/rss.xml",
        "/atom.xml",
        "/feed.xml",
        "/index.xml",
    ];

    for pattern in common_patterns {
        if let Ok(url) = base_url.join(pattern) {
            let url_str = url.to_string();
            if !seen_urls.contains(&url_str) {
                // Check if this URL actually exists (HEAD request)
                // For now, just add it as a candidate
                feeds.push(DiscoveredFeed {
                    url: url_str,
                    title: None,
                });
            }
        }
    }

    Ok(feeds)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_feed_links() {
        let html = r#"
        <!DOCTYPE html>
        <html>
        <head>
            <link rel="alternate" type="application/rss+xml" title="RSS Feed" href="/feed.xml">
            <link rel="alternate" type="application/atom+xml" title="Atom Feed" href="/atom.xml">
        </head>
        <body></body>
        </html>
        "#;

        let base_url = url::Url::parse("https://example.com").unwrap();
        let feeds = parse_feed_links(html, &base_url).unwrap();

        assert!(!feeds.is_empty());
        assert!(feeds.iter().any(|f| f.url.contains("feed.xml")));
        assert!(feeds.iter().any(|f| f.url.contains("atom.xml")));
    }
}
