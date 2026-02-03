//! OPML import benchmarks for Patina RSS
//!
//! These benchmarks measure the performance of OPML parsing with varying
//! feed counts to identify potential bottlenecks during feed import.

use criterion::{BenchmarkId, Criterion, black_box, criterion_group, criterion_main};
use patina_core::feed::opml::parse_opml;

/// Generate OPML content with a flat list of feeds
fn generate_flat_opml(feed_count: usize) -> String {
    let mut opml = String::from(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
    <head>
        <title>Benchmark Feeds</title>
    </head>
    <body>
"#,
    );

    for i in 0..feed_count {
        opml.push_str(&format!(
            r#"        <outline type="rss" text="Feed {i}" title="Feed {i}" xmlUrl="https://example{i}.com/feed.xml" htmlUrl="https://example{i}.com"/>
"#
        ));
    }

    opml.push_str(
        r#"    </body>
</opml>
"#,
    );

    opml
}

/// Generate OPML content with feeds organized in folders (nested structure)
fn generate_nested_opml(folder_count: usize, feeds_per_folder: usize) -> String {
    let mut opml = String::from(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
    <head>
        <title>Benchmark Feeds (Nested)</title>
    </head>
    <body>
"#,
    );

    for folder in 0..folder_count {
        opml.push_str(&format!(
            r#"        <outline text="Folder {folder}" title="Folder {folder}">
"#
        ));

        for feed in 0..feeds_per_folder {
            let id = folder * feeds_per_folder + feed;
            opml.push_str(&format!(
                r#"            <outline type="rss" text="Feed {id}" title="Feed {id}" xmlUrl="https://example{id}.com/feed.xml" htmlUrl="https://example{id}.com"/>
"#
            ));
        }

        opml.push_str(
            r#"        </outline>
"#,
        );
    }

    opml.push_str(
        r#"    </body>
</opml>
"#,
    );

    opml
}

/// Generate deeply nested OPML (folders within folders)
fn generate_deeply_nested_opml(depth: usize, feeds_per_level: usize) -> String {
    let mut opml = String::from(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
    <head>
        <title>Benchmark Feeds (Deep)</title>
    </head>
    <body>
"#,
    );

    let base_indent = "        ";
    let mut feed_id = 0;

    // Build nested structure
    for level in 0..depth {
        let indent = base_indent.to_string() + &"    ".repeat(level);
        opml.push_str(&format!(
            r#"{indent}<outline text="Level {level}" title="Level {level}">
"#
        ));

        // Add feeds at this level
        let feed_indent = base_indent.to_string() + &"    ".repeat(level + 1);
        for _ in 0..feeds_per_level {
            opml.push_str(&format!(
                r#"{feed_indent}<outline type="rss" text="Feed {feed_id}" title="Feed {feed_id}" xmlUrl="https://example{feed_id}.com/feed.xml"/>
"#
            ));
            feed_id += 1;
        }
    }

    // Close all nested outlines
    for level in (0..depth).rev() {
        let indent = base_indent.to_string() + &"    ".repeat(level);
        opml.push_str(&format!("{indent}</outline>\n"));
    }

    opml.push_str(
        r#"    </body>
</opml>
"#,
    );

    opml
}

/// Benchmark parsing flat OPML with varying feed counts
fn bench_parse_flat_opml(c: &mut Criterion) {
    let mut group = c.benchmark_group("parse_opml_flat");

    for feed_count in [10, 50, 100, 500] {
        let opml_content = generate_flat_opml(feed_count);

        group.bench_with_input(
            BenchmarkId::from_parameter(format!("{}_feeds", feed_count)),
            &opml_content,
            |b, content| {
                b.iter(|| {
                    black_box(parse_opml(content).unwrap());
                });
            },
        );
    }

    group.finish();
}

/// Benchmark parsing nested OPML (feeds in folders)
fn bench_parse_nested_opml(c: &mut Criterion) {
    let mut group = c.benchmark_group("parse_opml_nested");

    // 10 folders × 10 feeds = 100 feeds
    let opml_100 = generate_nested_opml(10, 10);
    group.bench_with_input(
        BenchmarkId::from_parameter("10x10_100_feeds"),
        &opml_100,
        |b, content| {
            b.iter(|| {
                black_box(parse_opml(content).unwrap());
            });
        },
    );

    // 20 folders × 25 feeds = 500 feeds
    let opml_500 = generate_nested_opml(20, 25);
    group.bench_with_input(
        BenchmarkId::from_parameter("20x25_500_feeds"),
        &opml_500,
        |b, content| {
            b.iter(|| {
                black_box(parse_opml(content).unwrap());
            });
        },
    );

    group.finish();
}

/// Benchmark parsing deeply nested OPML
fn bench_parse_deep_opml(c: &mut Criterion) {
    let mut group = c.benchmark_group("parse_opml_deep");

    // 5 levels deep, 10 feeds per level = 50 feeds
    let opml_5_deep = generate_deeply_nested_opml(5, 10);
    group.bench_with_input(
        BenchmarkId::from_parameter("5_levels_50_feeds"),
        &opml_5_deep,
        |b, content| {
            b.iter(|| {
                black_box(parse_opml(content).unwrap());
            });
        },
    );

    // 10 levels deep, 5 feeds per level = 50 feeds
    let opml_10_deep = generate_deeply_nested_opml(10, 5);
    group.bench_with_input(
        BenchmarkId::from_parameter("10_levels_50_feeds"),
        &opml_10_deep,
        |b, content| {
            b.iter(|| {
                black_box(parse_opml(content).unwrap());
            });
        },
    );

    group.finish();
}

criterion_group!(
    benches,
    bench_parse_flat_opml,
    bench_parse_nested_opml,
    bench_parse_deep_opml,
);

criterion_main!(benches);
