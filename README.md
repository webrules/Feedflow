# Feedflow

A modern iOS forum reader app that aggregates content from multiple sources including forums and RSS feeds.

## Features

- **Multi-Forum Support**: Browse 4D4Y, Linux.do, Hacker News, V2EX, and RSS feeds
- **RSS Integration**: Read RSS/Atom feeds from Hacker Podcast, Ruanyifeng Blog, and O'Reilly Radar
- **AI-Powered Summaries**: Get AI-generated summaries of threads using Google Gemini
- **Offline Reading**: Intelligent prefetching and caching for offline access
- **Bookmarks**: Save your favorite threads for later
- **Reply to Posts**: Quote and reply to specific comments
- **Dark Mode**: Beautiful dark theme optimized for readability
- **Bilingual**: Supports English and Chinese (Simplified)

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/joeyzou/Feedflow.git
cd Feedflow
```

2. Open `Feedflow.xcodeproj` in Xcode

3. Build and run the project

## Configuration

### Gemini API Key (Optional)
To enable AI summaries, add your Google Gemini API key in the app's Settings:
1. Open the app
2. Tap the key icon in the top left
3. Enter your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)

### Forum Credentials (Optional)
For member-only content on forums like 4D4Y:
1. Tap the person icon in the top left
2. Select the forum
3. Enter your credentials

## Architecture

- **MVVM Pattern**: Clean separation of concerns with ViewModels
- **ForumService Protocol**: Unified interface for all content sources
- **SQLite Database**: Local caching and bookmarks
- **Async/Await**: Modern Swift concurrency throughout

## Supported Sources

- **4D4Y**: Discuz-based Chinese forum
- **Linux.do**: Discourse community
- **Hacker News**: Tech news and discussions
- **V2EX**: Chinese tech community
- **RSS Feeds**: Standard RSS 2.0 and Atom feeds

## License

MIT License - See LICENSE file for details

## Author

Joey Zou (@joeyzou)
