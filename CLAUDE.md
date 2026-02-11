# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Feedflow is a native iOS forum reader app (iOS 16.0+, Swift 5.9+) that aggregates content from multiple sources including Chinese/English forums (4D4Y, Linux.do, V2EX, Zhihu) and RSS feeds. Built with SwiftUI using MVVM architecture.

## Development Commands

### Building and Running
```bash
# Open project in Xcode
open Feedflow.xcodeproj

# Build from command line (requires Xcode CLI tools)
xcodebuild -project Feedflow.xcodeproj -scheme Feedflow -configuration Debug

# Clean build folder
xcodebuild clean -project Feedflow.xcodeproj -scheme Feedflow
```

### Testing
No formal test suite currently exists. Manual testing is done via Xcode simulator or physical device.

## Architecture

### MVVM Pattern
- **Models**: `Models/Models.swift` contains core data structures (`User`, `Community`, `Thread`, `Comment`)
- **Views**: SwiftUI views in `Views/` folder
- **ViewModels**: Business logic in `ViewModels/` folder (`ForumViewModel`, `ThreadListViewModel`, `ThreadDetailViewModel`, `AuthViewModel`, `BookmarksViewModel`)

### Service Layer - ForumService Protocol
The app uses a **protocol-oriented architecture** where all content sources conform to `ForumService` protocol:

```swift
protocol ForumService {
    var name: String { get }
    var id: String { get }
    var logo: String { get }

    func fetchCategories() async throws -> [Community]
    func fetchCategoryThreads(categoryId: String, communities: [Community], page: Int) async throws -> [Thread]
    func fetchThreadDetail(threadId: String, page: Int) async throws -> (Thread, [Comment], Int?)
    func postComment(topicId: String, categoryId: String, content: String) async throws
    func createThread(categoryId: String, title: String, content: String) async throws
    func getWebURL(for thread: Thread) -> String
}
```

### Implemented Services
Each service handles platform-specific API/scraping logic:

1. **FourD4YService** (`4d4y`) - Discuz forum using GBK encoding, requires HTML scraping with regex patterns
2. **DiscourseService** (`linux_do`) - JSON API for Discourse forums (Linux.do)
3. **HackerNewsService** (`hackernews`) - Firebase JSON API
4. **V2EXService** (`v2ex`) - HTML scraping with regex patterns for tabs (tech, creative, play, apple, jobs, deals, city, qna, hot, all, r2, xna, planet)
5. **ZhihuService** (`zhihu`) - Web scraping for Zhihu hot list and feeds
6. **RSSService** (`rss`) - Standard RSS 2.0 and Atom feed parser

**Important**: Services are ordered strictly in SiteListView: 4D4Y, Linux.do, Hacker News, V2EX, RSS.

### Data Persistence (SQLite)
`DatabaseManager.swift` (singleton) manages all local storage:

**Tables**:
- `communities` - Cached categories/communities per service (PRIMARY KEY: id + serviceId)
- `settings` - App settings including Gemini API key
- `ai_summaries` - Cached AI-generated summaries (prevents re-billing)
- `thread_cache` - Cached thread content for offline reading
- `comment_cache` - Cached comments
- `bookmarks` - User-saved threads (stores full Thread JSON)
- `url_bookmarks` - Bookmarked URLs

**Access pattern**: All database operations go through `DatabaseManager.shared`

### Authentication & Security
- **AuthViewModel** manages login state for forums requiring authentication (4D4Y, V2EX)
- Credentials are **AES-256 encrypted** via `EncryptionHelper` before storage
- Cookies extracted from login responses are persisted and injected into subsequent HTTP requests
- For 4D4Y: Must extract `sid` and `formhash` from HTML, persist `cdb_sid` and `cdb_auth` cookies

### AI Integration
- **GeminiService** integrates Google's Generative AI SDK for thread summarization
- API key stored in settings table
- **AISummaryView** triggered from ThreadDetailView toolbar (sparkles icon)
- Results cached in `ai_summaries` table to avoid redundant API calls

### Localization
- **LocalizationManager** provides bilingual support (English/Chinese Simplified)
- Language preference persists in settings table
- Use `LocalizationManager.shared.localizedString(forKey:)` for all user-facing strings

### Theme System
- **ThemeManager** manages dark/light mode toggle
- Theme state injected as `@EnvironmentObject` from `ForumReaderApp`
- Colors defined in `Theme/Theme.swift`:
  - Light: Background `#F2F2F7`, Card `#FFFFFF`, Accent `#007AFF`
  - Dark: Background `#0B101B`, Card `#151C2C`, Accent `#2D62ED`

## Key Implementation Notes

### HTML Parsing Pattern
Services like FourD4YService and V2EXService use regex-based HTML parsing:
- **4D4Y**: GBK encoding - MUST decode data using GBK before string processing
- Thread list regex: Extract thread ID, title, author from `<tbody>` elements
- Content regex: Extract post content from `<div id="postmessage_...">`
- Images: Replace `<img>` tags with `[IMAGE:url]` markers for custom rendering

### Network & Caching Strategy
1. On view appear: Load from SQLite cache immediately (instant UI)
2. Background fetch: Update from network
3. Update UI when network response arrives
4. Cache fresh data to SQLite

**NetworkMonitor** tracks connectivity status for offline indicators.

### RSS-Specific Behavior
- RSS feeds are read-only (hide comment input bar in ThreadDetailView)
- Predefined feeds: Hacker Podcast, Ruanyifeng Blog, O'Reilly Radar
- Content cleaned to remove scripts/iframes before display

### Navigation
- **NavigationManager** maintains navigation state
- Uses SwiftUI `NavigationStack` for hierarchical navigation
- Flow: `SiteListView` → `CommunitiesView` → `ThreadListView` → `ThreadDetailView`

### Media Handling
- **AvatarView**: Custom view for user avatars with caching
- **FullScreenImageView**: Tappable images in thread content open full-screen view
- **InAppBrowserView**: WKWebView wrapper for external links

## Common Patterns

### Async/Await Throughout
All network operations use Swift's modern concurrency:
```swift
Task {
    do {
        let threads = try await service.fetchCategoryThreads(...)
    } catch {
        // Handle error
    }
}
```

### Service Factory Pattern
Services are instantiated based on site ID in ViewModels:
```swift
switch siteId {
    case "4d4y": return FourD4YService()
    case "linux_do": return DiscourseService()
    // ...
}
```

### State Management
ViewModels use `@Published` properties to drive UI updates:
- Loading states (spinner display)
- Error states (toast/alert display)
- Data arrays (thread lists, comments)

## Dependencies

Managed via Swift Package Manager (SPM):
- **GoogleGenerativeAI** (v0.5.6+) - For AI summaries

Resolved packages in `Feedflow.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

## File Organization

```
Feedflow/
├── Models/          - Data structures
├── Views/           - SwiftUI views
├── ViewModels/      - MVVM view models
├── Services/        - ForumService implementations + utilities
├── Theme/           - Theme definitions
├── Assets.xcassets/ - Images and icons
├── ForumReaderApp.swift - App entry point
└── DatabaseManager.swift - SQLite singleton
```

## Important Constraints

1. **Encoding**: 4D4Y requires GBK encoding, all others use UTF-8
2. **Authentication**: Different auth mechanisms per service - check service-specific implementation
3. **Pagination**: Some services support pagination (page parameter), others don't
4. **Rate Limiting**: No explicit rate limiting implemented - be mindful when adding features that make frequent requests
5. **iOS Deployment Target**: Currently set to iOS 26.0 but declared requirement is iOS 16.0+ (check project settings)

## Feature Specs References

See `FeatureSpecs.md` for detailed technical specifications including:
- Exact regex patterns for HTML parsing
- API endpoint details
- UI/UX parity requirements
- Color hex codes

See `prd.md` for product requirements and feature descriptions.
