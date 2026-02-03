# Patina RSS

A native macOS RSS reader with an AI-powered Serendipity Mode that resurfaces forgotten articles based on your reading patterns.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![Rust 1.85+](https://img.shields.io/badge/Rust-1.85%2B-brown)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## ✨ Features

- **Native Performance** — SwiftUI frontend with Rust core for a responsive, fast reading experience
- **Serendipity Mode** — AI-powered article surfacing based on topics extracted from your reading history
- **Immersive Reading** — Single-pane navigation that prioritizes focus over clutter
- **Feed Discovery** — Auto-detect feeds from any website URL
- **OPML Import/Export** — Migrate subscriptions from other RSS readers
- **Privacy-First** — All data stored locally in SQLite, no cloud sync required
- **Keyboard-Driven** — Power user shortcuts for efficient navigation

## 🎹 Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘N` | Add Feed |
| `⌘⇧I` | Import OPML |
| `⌘R` | Refresh All Feeds |
| `⌘K` | Command Palette |
| `Esc` / `←` | Go Back |
| `j` / `k` | Navigate Articles |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftUI Application                       │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ FeedsScreen │→ │ArticlesScreen│→ │   ReaderScreen    │  │
│  └─────────────┘  └──────────────┘  └───────────────────┘  │
│                          ↓                                   │
│              ┌───────────────────────┐                      │
│              │       AppState        │ @Observable          │
│              │   NavigationRouter    │ @MainActor           │
│              └───────────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
                           │ UniFFI
┌─────────────────────────────────────────────────────────────┐
│                      Rust Core                               │
│  ┌──────────┐  ┌───────────────┐  ┌─────────────────────┐  │
│  │  Feed    │  │   Storage     │  │    Serendipity      │  │
│  │ Parser   │  │  (SQLite)     │  │  (Topic Extraction) │  │
│  └──────────┘  └───────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 📦 Prerequisites

- **macOS 14.0+**
- **Xcode 15+** with Swift 6
- **Rust 1.85+** with `aarch64-apple-darwin` target
- **XcodeGen** (`brew install xcodegen`)

## 🚀 Building from Source

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/patina-rss.git
cd patina-rss
```

### 2. Install Rust target (if needed)

```bash
rustup target add aarch64-apple-darwin
```

### 3. Generate Xcode project

```bash
xcodegen generate
```

### 4. Build and run

```bash
# Build the Rust library
cd patina-core && cargo build && cd ..

# Build the Swift app
cd Patina && xcodebuild -scheme Patina -configuration Debug build
```

Or open `Patina/Patina.xcodeproj` in Xcode and press `⌘R`.

## 📁 Project Structure

```
patina-rss/
├── Patina/                    # SwiftUI Application
│   ├── project.yml            # XcodeGen configuration
│   └── Patina/
│       ├── Navigation/        # Immersive single-pane navigation
│       ├── Screens/           # Full-screen views
│       ├── State/             # @Observable app state
│       ├── Views/             # Sheets and dialogs
│       ├── Components/        # Reusable UI components
│       └── Theme/             # Design tokens
├── patina-core/               # Rust Core Library
│   └── src/
│       ├── feed/              # RSS/Atom parsing & discovery
│       ├── storage/           # SQLite database operations
│       └── serendipity/       # Topic extraction & surfacing
├── generated/                 # UniFFI Swift bindings (auto-generated)
└── scripts/                   # Build automation
```

## 🧠 How Serendipity Mode Works

Patina analyzes your reading habits to surface articles you might have missed:

1. **Topic Extraction** — When you read articles, Patina extracts weighted topics from titles (3x weight) and summaries (1x weight)
2. **Pattern Learning** — Topics are stored as reading patterns, building a profile of your interests
3. **Smart Surfacing** — Serendipity Mode finds older articles matching your patterns that you haven't read yet
4. **Manual Tuning** — Add custom keywords or exclude topics you're not interested in

## 🔧 Development

### Running Tests

```bash
# Rust tests
cd patina-core && cargo test

# Build verification
cd Patina && xcodebuild -scheme Patina -configuration Debug build
```

### Database Location

Patina stores data at:
```
~/Library/Application Support/Patina/patina.db
```

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Built with:
- [UniFFI](https://github.com/mozilla/uniffi-rs) — Rust ↔ Swift bridge
- [feed-rs](https://github.com/feed-rs/feed-rs) — RSS/Atom parsing
- [reqwest](https://github.com/seanmonstar/reqwest) — HTTP client
- [rusqlite](https://github.com/rusqlite/rusqlite) — SQLite bindings
