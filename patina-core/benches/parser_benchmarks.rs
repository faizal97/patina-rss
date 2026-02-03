//! Feed parsing benchmarks for Patina RSS
//!
//! These benchmarks measure the performance of HTML cleaning and feed parsing
//! using embedded sample content (no network calls).

use criterion::{BenchmarkId, Criterion, black_box, criterion_group, criterion_main};
use patina_core::feed::parser::{clean_html, parse_feed_content};

/// Small HTML content (~100 chars)
const SMALL_HTML: &str =
    r##"<p>Hello <strong>world</strong>! This is a <a href="#">test</a>.</p>"##;

/// Medium HTML content (~500 chars)
const MEDIUM_HTML: &str = r##"
<div class="article">
    <h1>Article Title</h1>
    <p>This is the first paragraph with some <strong>bold text</strong> and <em>italic text</em>.</p>
    <p>Here's another paragraph with a <a href="https://example.com">link</a> and some more content.</p>
    <ul>
        <li>First item</li>
        <li>Second item</li>
        <li>Third item</li>
    </ul>
    <p>Final paragraph with &amp; HTML entities &lt;like&gt; these &quot;quotes&quot;.</p>
</div>
"##;

/// Large HTML content (~2000 chars)
const LARGE_HTML: &str = r##"
<article class="post-content">
    <header>
        <h1>Understanding Modern Software Architecture</h1>
        <p class="meta">Published on <time>2024-01-15</time> by <span class="author">John Doe</span></p>
    </header>

    <section>
        <h2>Introduction</h2>
        <p>Software architecture is a critical aspect of building scalable and maintainable systems. In this article, we'll explore the key principles that guide modern architectural decisions.</p>
        <p>The landscape of software development has evolved significantly over the past decade, with new paradigms and patterns emerging to address the challenges of distributed systems.</p>
    </section>

    <section>
        <h2>Key Principles</h2>
        <ul>
            <li><strong>Separation of Concerns</strong>: Divide your application into distinct features with as little overlap as possible.</li>
            <li><strong>Single Responsibility</strong>: Each module should have one, and only one, reason to change.</li>
            <li><strong>Dependency Inversion</strong>: High-level modules should not depend on low-level modules. Both should depend on abstractions.</li>
            <li><strong>Interface Segregation</strong>: No client should be forced to depend on methods it does not use.</li>
        </ul>
    </section>

    <section>
        <h2>Microservices Architecture</h2>
        <p>Microservices have become increasingly popular for building complex applications. This approach involves breaking down a monolithic application into smaller, independently deployable services.</p>
        <blockquote>
            <p>&quot;The microservices architectural style is an approach to developing a single application as a suite of small services.&quot;</p>
            <cite>&mdash; Martin Fowler</cite>
        </blockquote>
    </section>

    <footer>
        <p>Tags: <a href="#">architecture</a>, <a href="#">microservices</a>, <a href="#">software-design</a></p>
    </footer>
</article>
"##;

/// Sample RSS 2.0 feed content
const SAMPLE_RSS_FEED: &[u8] = br##"<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
    <channel>
        <title>Tech News Daily</title>
        <link>https://technews.example.com</link>
        <description>Daily technology news and updates</description>
        <language>en-us</language>
        <lastBuildDate>Mon, 15 Jan 2024 10:00:00 GMT</lastBuildDate>

        <item>
            <title>New Programming Language Released</title>
            <link>https://technews.example.com/articles/1</link>
            <description><![CDATA[<p>A new programming language has been <strong>released</strong> today, promising improved performance and developer experience.</p>]]></description>
            <pubDate>Mon, 15 Jan 2024 09:00:00 GMT</pubDate>
        </item>

        <item>
            <title>Cloud Computing Trends for 2024</title>
            <link>https://technews.example.com/articles/2</link>
            <description>Industry experts share their predictions for cloud computing in the coming year.</description>
            <pubDate>Mon, 15 Jan 2024 08:00:00 GMT</pubDate>
        </item>

        <item>
            <title>Open Source Project Reaches Milestone</title>
            <link>https://technews.example.com/articles/3</link>
            <description><![CDATA[<p>The popular open source project has reached 100,000 stars on GitHub, marking a significant community achievement.</p>]]></description>
            <pubDate>Sun, 14 Jan 2024 16:00:00 GMT</pubDate>
        </item>

        <item>
            <title>AI Assistant Capabilities Expand</title>
            <link>https://technews.example.com/articles/4</link>
            <description>New features bring enhanced natural language processing to AI assistants.</description>
            <pubDate>Sun, 14 Jan 2024 12:00:00 GMT</pubDate>
        </item>

        <item>
            <title>Security Vulnerability Patched</title>
            <link>https://technews.example.com/articles/5</link>
            <description><![CDATA[<p>A critical <em>security vulnerability</em> has been patched in a widely-used software library.</p>]]></description>
            <pubDate>Sat, 13 Jan 2024 14:00:00 GMT</pubDate>
        </item>
    </channel>
</rss>
"##;

/// Sample Atom feed content
const SAMPLE_ATOM_FEED: &[u8] = br##"<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
    <title>Developer Blog</title>
    <link href="https://devblog.example.com"/>
    <link href="https://devblog.example.com/feed.atom" rel="self"/>
    <updated>2024-01-15T10:00:00Z</updated>
    <id>https://devblog.example.com/</id>

    <entry>
        <title>Building Rust Applications</title>
        <link href="https://devblog.example.com/posts/rust-apps"/>
        <id>https://devblog.example.com/posts/rust-apps</id>
        <updated>2024-01-15T09:00:00Z</updated>
        <summary type="html"><![CDATA[<p>Learn how to build <strong>performant</strong> applications using the Rust programming language.</p>]]></summary>
        <author><name>Jane Developer</name></author>
    </entry>

    <entry>
        <title>Swift UI Best Practices</title>
        <link href="https://devblog.example.com/posts/swiftui-practices"/>
        <id>https://devblog.example.com/posts/swiftui-practices</id>
        <updated>2024-01-14T15:00:00Z</updated>
        <summary>Discover the best practices for building modern iOS and macOS applications with SwiftUI.</summary>
        <author><name>Jane Developer</name></author>
    </entry>

    <entry>
        <title>Database Optimization Techniques</title>
        <link href="https://devblog.example.com/posts/db-optimization"/>
        <id>https://devblog.example.com/posts/db-optimization</id>
        <updated>2024-01-13T12:00:00Z</updated>
        <content type="html"><![CDATA[<article><h2>Introduction</h2><p>Database optimization is crucial for application performance. This guide covers indexing strategies, query optimization, and connection pooling.</p></article>]]></content>
        <author><name>Jane Developer</name></author>
    </entry>
</feed>
"##;

/// Benchmark clean_html with varying HTML sizes
fn bench_clean_html(c: &mut Criterion) {
    let mut group = c.benchmark_group("clean_html");

    group.bench_with_input(BenchmarkId::new("size", "small"), &SMALL_HTML, |b, html| {
        b.iter(|| black_box(clean_html(html)));
    });

    group.bench_with_input(
        BenchmarkId::new("size", "medium"),
        &MEDIUM_HTML,
        |b, html| {
            b.iter(|| black_box(clean_html(html)));
        },
    );

    group.bench_with_input(BenchmarkId::new("size", "large"), &LARGE_HTML, |b, html| {
        b.iter(|| black_box(clean_html(html)));
    });

    group.finish();
}

/// Benchmark RSS feed parsing
fn bench_parse_rss_feed(c: &mut Criterion) {
    let mut group = c.benchmark_group("parse_feed");

    group.bench_function("rss_5_items", |b| {
        b.iter(|| {
            black_box(
                parse_feed_content(SAMPLE_RSS_FEED, "https://technews.example.com/feed.xml")
                    .unwrap(),
            );
        });
    });

    group.finish();
}

/// Benchmark Atom feed parsing
fn bench_parse_atom_feed(c: &mut Criterion) {
    let mut group = c.benchmark_group("parse_feed");

    group.bench_function("atom_3_items", |b| {
        b.iter(|| {
            black_box(
                parse_feed_content(SAMPLE_ATOM_FEED, "https://devblog.example.com/feed.atom")
                    .unwrap(),
            );
        });
    });

    group.finish();
}

/// Generate a larger RSS feed for stress testing
fn generate_large_rss_feed(item_count: usize) -> Vec<u8> {
    let mut feed = String::from(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
    <channel>
        <title>Large Test Feed</title>
        <link>https://largefeed.example.com</link>
        <description>A feed with many items for benchmark testing</description>
"#,
    );

    for i in 0..item_count {
        feed.push_str(&format!(
            r#"
        <item>
            <title>Article Number {} - Testing Feed Parser Performance</title>
            <link>https://largefeed.example.com/articles/{}</link>
            <description><![CDATA[<p>This is article number {}. It contains <strong>HTML content</strong> that needs to be cleaned and processed. The parser should handle this efficiently even with many items.</p>]]></description>
            <pubDate>Mon, 15 Jan 2024 {:02}:00:00 GMT</pubDate>
        </item>
"#,
            i,
            i,
            i,
            i % 24
        ));
    }

    feed.push_str(
        r#"
    </channel>
</rss>
"#,
    );

    feed.into_bytes()
}

/// Benchmark parsing feeds with varying item counts
fn bench_parse_large_feeds(c: &mut Criterion) {
    let mut group = c.benchmark_group("parse_large_feed");

    for item_count in [10, 50, 100] {
        let feed_content = generate_large_rss_feed(item_count);

        group.bench_with_input(
            BenchmarkId::from_parameter(format!("{}_items", item_count)),
            &feed_content,
            |b, content| {
                b.iter(|| {
                    black_box(
                        parse_feed_content(content, "https://largefeed.example.com/feed.xml")
                            .unwrap(),
                    );
                });
            },
        );
    }

    group.finish();
}

criterion_group!(
    benches,
    bench_clean_html,
    bench_parse_rss_feed,
    bench_parse_atom_feed,
    bench_parse_large_feeds,
);

criterion_main!(benches);
