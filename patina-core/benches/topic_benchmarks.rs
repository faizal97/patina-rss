//! Topic extraction benchmarks for Patina RSS
//!
//! These benchmarks measure the performance of topic extraction from article
//! content with varying text lengths and complexity.

use criterion::{BenchmarkId, Criterion, black_box, criterion_group, criterion_main};
use patina_core::serendipity::patterns::extract_topics;

/// Short text (tweet-length, ~50 words)
const SHORT_TEXT_TITLE: &str = "Breaking: Rust 2.0 Released with Major Performance Improvements";
const SHORT_TEXT_SUMMARY: &str = "The Rust programming language team has announced version 2.0, featuring significant performance improvements and new syntax features.";

/// Medium text (article summary, ~150 words)
const MEDIUM_TEXT_TITLE: &str = "Understanding Modern Software Architecture: A Comprehensive Guide";
const MEDIUM_TEXT_SUMMARY: &str = r#"
Software architecture plays a crucial role in building scalable and maintainable applications.
This comprehensive guide explores microservices, event-driven architecture, and domain-driven design.
We examine how modern teams approach system design, considering factors like performance,
reliability, and developer experience. The article covers patterns such as CQRS, event sourcing,
and the hexagonal architecture pattern. Real-world examples from companies like Netflix and
Spotify illustrate how these concepts apply in practice. Whether you're building a startup
MVP or scaling enterprise software, understanding these architectural principles will help
you make better technical decisions.
"#;

/// Long text (full article, ~500 words)
const LONG_TEXT_TITLE: &str =
    "The Future of Programming: AI-Assisted Development and Its Impact on Software Engineering";
const LONG_TEXT_SUMMARY: &str = r#"
Artificial intelligence is transforming software development in unprecedented ways. From code
completion to automated testing, AI tools are becoming essential companions for developers
worldwide. This article examines the current state of AI-assisted programming and explores
what the future might hold.

Machine learning models trained on vast codebases can now suggest entire functions, identify
potential bugs before they reach production, and even explain complex algorithms in natural
language. Tools like GitHub Copilot and similar AI assistants have demonstrated that AI can
significantly boost developer productivity when used appropriately.

However, the integration of AI into development workflows raises important questions about
code quality, security, and the role of human expertise. While AI excels at pattern matching
and generating boilerplate code, it still struggles with novel problems that require deep
understanding of business requirements and system constraints.

The most successful development teams are finding ways to leverage AI capabilities while
maintaining human oversight and critical thinking. This hybrid approach combines the speed
and consistency of automated suggestions with the creativity and judgment of experienced
engineers.

Looking ahead, we can expect AI tools to become more sophisticated, with better understanding
of project context and coding standards. Natural language interfaces may allow developers to
describe their intent at a higher level, with AI handling more of the implementation details.

Yet the fundamental skills of software engineering remain crucial. Understanding algorithms,
data structures, system design, and debugging techniques will continue to differentiate
great engineers from those who merely follow AI suggestions. The tools may change, but the
need for thoughtful, well-designed software never goes away.

As the industry evolves, developers who embrace AI assistance while deepening their core
technical knowledge will be best positioned for success. The future of programming is not
about replacing human developers but augmenting their capabilities to build better software
faster than ever before.
"#;

/// Text with many stop words (to measure filtering overhead)
const STOP_WORD_HEAVY_TITLE: &str =
    "This is the article about all of the things that are important";
const STOP_WORD_HEAVY_SUMMARY: &str = r#"
This is an article that has been written about all of the things which are very
important to us. We have included many of the words that are commonly used in
the English language. The purpose of this text is to test how well the topic
extraction handles content that contains a high proportion of stop words. It
should be able to filter these out efficiently and identify the meaningful
terms that remain. Words like technology, programming, and software should
still be detected even when surrounded by many common function words.
"#;

/// Technical jargon text
const TECHNICAL_TITLE: &str = "Implementing Zero-Copy Deserialization in Rust with Serde";
const TECHNICAL_SUMMARY: &str = r#"
Zero-copy deserialization is a powerful optimization technique that avoids unnecessary memory
allocations when parsing data. In Rust, the serde framework provides excellent support for
this pattern through borrowed data types. This article demonstrates how to implement custom
deserializers that reference the original input buffer, reducing memory usage and improving
throughput for high-performance applications. We cover lifetimes, the Cow type, and advanced
serde attributes like borrow. Benchmarks show 3x improvement over traditional deserialization
for large payloads.
"#;

/// Benchmark extract_topics with varying text lengths
fn bench_extract_topics_by_length(c: &mut Criterion) {
    let mut group = c.benchmark_group("extract_topics_length");

    group.bench_with_input(BenchmarkId::new("text", "short"), &(), |b, _| {
        b.iter(|| black_box(extract_topics(SHORT_TEXT_TITLE, Some(SHORT_TEXT_SUMMARY)).unwrap()));
    });

    group.bench_with_input(BenchmarkId::new("text", "medium"), &(), |b, _| {
        b.iter(|| black_box(extract_topics(MEDIUM_TEXT_TITLE, Some(MEDIUM_TEXT_SUMMARY)).unwrap()));
    });

    group.bench_with_input(BenchmarkId::new("text", "long"), &(), |b, _| {
        b.iter(|| black_box(extract_topics(LONG_TEXT_TITLE, Some(LONG_TEXT_SUMMARY)).unwrap()));
    });

    group.finish();
}

/// Benchmark extract_topics with title only (no summary)
fn bench_extract_topics_title_only(c: &mut Criterion) {
    let mut group = c.benchmark_group("extract_topics_title_only");

    group.bench_function("short_title", |b| {
        b.iter(|| black_box(extract_topics(SHORT_TEXT_TITLE, None).unwrap()));
    });

    group.bench_function("long_title", |b| {
        b.iter(|| black_box(extract_topics(LONG_TEXT_TITLE, None).unwrap()));
    });

    group.finish();
}

/// Benchmark stop word filtering overhead
fn bench_stop_word_filtering(c: &mut Criterion) {
    let mut group = c.benchmark_group("stop_word_filtering");

    group.bench_function("normal_text", |b| {
        b.iter(|| black_box(extract_topics(TECHNICAL_TITLE, Some(TECHNICAL_SUMMARY)).unwrap()));
    });

    group.bench_function("stop_word_heavy", |b| {
        b.iter(|| {
            black_box(extract_topics(STOP_WORD_HEAVY_TITLE, Some(STOP_WORD_HEAVY_SUMMARY)).unwrap())
        });
    });

    group.finish();
}

/// Benchmark with technical/jargon content
/// Note: This duplicates stop_word_filtering/normal_text but provides a dedicated benchmark group
/// for tracking technical content processing performance separately.
fn bench_technical_content(c: &mut Criterion) {
    let mut group = c.benchmark_group("technical_content");

    group.bench_function("technical_jargon", |b| {
        b.iter(|| black_box(extract_topics(TECHNICAL_TITLE, Some(TECHNICAL_SUMMARY)).unwrap()));
    });

    group.finish();
}

/// Benchmark batch topic extraction (simulating processing multiple articles)
fn bench_batch_extraction(c: &mut Criterion) {
    let mut group = c.benchmark_group("batch_extraction");

    let articles = vec![
        (SHORT_TEXT_TITLE, Some(SHORT_TEXT_SUMMARY)),
        (MEDIUM_TEXT_TITLE, Some(MEDIUM_TEXT_SUMMARY)),
        (LONG_TEXT_TITLE, Some(LONG_TEXT_SUMMARY)),
        (TECHNICAL_TITLE, Some(TECHNICAL_SUMMARY)),
        (STOP_WORD_HEAVY_TITLE, Some(STOP_WORD_HEAVY_SUMMARY)),
    ];

    group.bench_function("5_articles", |b| {
        b.iter(|| {
            for (title, summary) in &articles {
                black_box(extract_topics(title, *summary).unwrap());
            }
        });
    });

    // Simulate processing 20 articles
    let large_batch: Vec<_> = articles.iter().cycle().take(20).cloned().collect();

    group.bench_function("20_articles", |b| {
        b.iter(|| {
            for (title, summary) in &large_batch {
                black_box(extract_topics(title, *summary).unwrap());
            }
        });
    });

    group.finish();
}

/// Benchmark with empty/edge case inputs
fn bench_edge_cases(c: &mut Criterion) {
    let mut group = c.benchmark_group("edge_cases");

    group.bench_function("empty_summary", |b| {
        b.iter(|| black_box(extract_topics("Test Article Title", None).unwrap()));
    });

    group.bench_function("empty_strings", |b| {
        b.iter(|| black_box(extract_topics("", Some("")).unwrap()));
    });

    group.bench_function("single_word", |b| {
        b.iter(|| black_box(extract_topics("Rust", Some("Programming")).unwrap()));
    });

    group.finish();
}

criterion_group!(
    benches,
    bench_extract_topics_by_length,
    bench_extract_topics_title_only,
    bench_stop_word_filtering,
    bench_technical_content,
    bench_batch_extraction,
    bench_edge_cases,
);

criterion_main!(benches);
