use crate::storage::models::OpmlFeed;
use crate::PatinaError;

/// Parse an OPML file and extract feed URLs
pub fn parse_opml(content: &str) -> Result<Vec<OpmlFeed>, PatinaError> {
    let opml = opml::OPML::from_str(content).map_err(|e| PatinaError::ParseError(e.to_string()))?;

    let mut feeds = Vec::new();
    extract_feeds_recursive(&opml.body.outlines, &mut feeds);

    Ok(feeds)
}

/// Recursively extract feeds from OPML outline structure
fn extract_feeds_recursive(outlines: &[opml::Outline], feeds: &mut Vec<OpmlFeed>) {
    for outline in outlines {
        // Check if this is a feed (has xmlUrl)
        if let Some(xml_url) = &outline.xml_url {
            if !xml_url.is_empty() {
                // Get title from text or title field
                let title = if !outline.text.is_empty() {
                    Some(outline.text.clone())
                } else {
                    outline.title.clone()
                };

                feeds.push(OpmlFeed {
                    url: xml_url.clone(),
                    title,
                });
            }
        }

        // Recurse into child outlines (folders)
        extract_feeds_recursive(&outline.outlines, feeds);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_opml() {
        let opml_content = r#"<?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title>My Feeds</title>
            </head>
            <body>
                <outline text="Tech" title="Tech">
                    <outline type="rss" text="Hacker News" title="Hacker News"
                             xmlUrl="https://news.ycombinator.com/rss"
                             htmlUrl="https://news.ycombinator.com"/>
                </outline>
                <outline type="rss" text="Example Blog"
                         xmlUrl="https://example.com/feed.xml"/>
            </body>
        </opml>"#;

        let feeds = parse_opml(opml_content).unwrap();

        assert_eq!(feeds.len(), 2);
        assert!(feeds.iter().any(|f| f.url.contains("ycombinator")));
        assert!(feeds.iter().any(|f| f.url.contains("example.com")));
    }
}
