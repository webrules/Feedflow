# Product Requirement Document (PRD): Feedflow

## 1. Executive Summary
Feedflow is a unified mobile forum reader application currently integrated with V2EX, Hacker News, RSS feeds, and Discourse forums (e.g., Linux.do). It provides a native, seamless reading experience with features like infinite scrolling, AI-powered summarization, and cross-platform syncing.

## 2. Core Features (Functional Requirements)

### 2.1 Content Consumption
*   **Multi-Source Aggregation**: Unified interface for browsing threads from V2EX, Discourse, and RSS feeds.
*   **Infinite Scrolling**: Automatically loads next pages of threads or comments when the user reaches the bottom.
*   **Readability Mode**: Parsing of HTML content into native text and image components (via `ParsedContentView`).
*   **Media Support**: Native rendering of avatars and threading images.

### 2.2 Navigation & Organization
*   **Community Management**: Users can switch between predefined tabs (Tech, Creative, Apple, etc. for V2EX) or different forum sources.
*   **Thread Details**: Rich detail view displaying author info, role tags, thread content, tags, and linear comment threads.
*   **Deep Linking**: Ability to open original web URLs for threads.

### 2.3 User Interaction
*   **Authentication (Partial)**: Supports login (e.g., Discourse/V2EX web session cookies) for authorized content access.
*   **Comments**: View nested or linear comments. (Posting is currently restricted/read-only for V2EX).
*   **Read State**: Tracks read threads (implied feature for future sync).

### 2.4 AI Integration
*   **Summarization**: Integration with Google Gemini (`GoogleGenerativeAI`) to generate concise summaries of long threads.
*   **Translation**: On-demand translation of thread content.

## 3. Data Sources & Logic

### 3.1 V2EX Service
*   **Type**: HTML Scraping (Web Parse).
*   **Endpoint**: `https://v2ex.com/?tab={tab_id}`.
*   **Parsing Logic**:
    *   **Structure**: Uses Regex to find `<div class="cell item">`.
    *   **Extraction**: Captures Thread ID, Title, Author, Avatar URL, and Reply Count using `NSRegularExpression`.
    *   **Constraint**: Standard API is not used; relies on specific DOM structure stability.
    *   **Pagination**: Tab pages are typically single-page; Node pages support pagination.

### 3.2 RSS Service
*   **Type**: XML Parsing.
*   **Endpoints**: Standard Atom/RSS URLs.
*   **Logic**: Parses standard XML tags (`<title>`, `<link>`, `<content:encoded>`) into common `Thread` models.

### 3.3 Data Models
*   **User**: `id`, `username`, `avatar`, `role`.
*   **Thread**: `id`, `title`, `content`, `author`, `community`, `timeAgo`, `likeCount`, `commentCount`, `tags`.
*   **Comment**: `id`, `author`, `content`, `timeAgo`, `replies`.

## 4. UI/UX Structure

### 4.1 Navigation Hierarchy
1.  **SiteListView** (Root):
    *   Grid/List of available services (V2EX, Hacker News, etc.).
2.  **CommunitiesView** (Category Level):
    *   Horizontal tabs or list for sub-categories (e.g. "Tech", "Apple").
3.  **ThreadListView**:
    *   Linear list of threads with "Time Ago", "Author", and "Reply Count" metadata.
4.  **ThreadDetailView**:
    *   Scrollable content area.
    *   Header: Author Avatar + Name + Role.
    *   Body: Title + Parsed Markdown/HTML Content.
    *   Footer: Lazy-loaded list of `CommentRow`s.

### 4.2 Interaction Models
*   **Swipe**: Swipe to go back (NavigationStack).
*   **Tap**: Tap thread to view details.
*   **Scroll**: Pull-to-refresh (Refreshable), Infinite scroll at bottom.

## 5. Technical Constraints & Dependencies
*   **Network**: Uses standard `URLSession` (Swift).
*   **Concurrency**: Heavy reliance on Swift 5.5 `async/await`.
*   **Parsing**: Swift `NSRegularExpression` is critical for V2EX.
*   **Limitations**:
    *   V2EX functionality is Read-Only due to CSRF/API restrictions (403 on post).
    *   Dependency on Google Generative AI SDK.

---

# HarmonyOS Conversion Strategy (Migration Plan)

## 1. Architecture Mapping

The architecture will remain MVVM (Model-View-ViewModel), leveraging ArkTS's reactive capabilities to mirror SwiftUI's state management.

### 1.1 Data Models (`struct` -> `class` with Interface)
SwiftUI `structs` are value types. In ArkTS, we use `class` to support observation or simple interfaces for data transfer. Use interfaces for API responses and classes for observable state if needed.

| Swift | ArkTS (HarmonyOS) | Notes |
| :--- | :--- | :--- |
| `struct User: Codable` | `export class User` | Plain Data Class |
| `struct Thread` | `export class Thread` | Plain Data Class |
| `struct Comment` | `export class Comment` | Plain Data Class |

### 1.2 State Management
| Swift | ArkTS | Notes |
| :--- | :--- | :--- |
| `ObservableObject` | `@ObservedObject` / class | Use standard class |
| `@Published` | `@State` / `@Prop` | In ViewModel, fields trigger UI updates |
| `@StateObject` | `@State` (holding class instance) | Lifecycle management in `aboutToAppear` |
| `EnvironmentObject` | `LocalStorage` or `AppStorage` | Or pass via Props/dependency injection |

### 1.3 UI Components
| SwiftUI | ArkUI | Notes |
| :--- | :--- | :--- |
| `VStack` / `HStack` | `Column` / `Row` | Standard Layout containers |
| `List` / `ScrollView` | `List` / `ListItemGroup` | native List is highly optimized |
| `AsyncImage` | `Image` | Use `Image(url)` directly |
| `NavigationStack` | `Navigation` + `NavPathStack` | API 9+ Routing standard |

## 2. Key Challenges & Solutions

### 2.1 Networking (`@ohos.net.http`)
Swift uses `URLSession`. HarmonyOS uses the `http` module.
*   **Strategy**: Create a `HttpClient` wrapper class that utilizes `http.createHttp()`.
*   **Implementation**: Wrap the callback-based or promise-based `request` method into a clean `async/await` function returning generic types.

### 2.2 HTML Parsing (Regex Replacement)
Swift uses `NSRegularExpression`. ArkTS (JS/TS engine) uses standard standard `RegExp`.
*   **Challenge**: Need to port the Regex patterns. JS RegExp has slightly different syntax (e.g., named groups, flags).
*   **Strategy**:
    *   Manually convert regex patterns.
    *   Example: Swift `(?<name>pattern)` -> JS `(?<name>pattern)` (Supported in ES2018+).
    *   Instead of `NSRegularExpression`, use `string.matchAll(regex)` for iteration.
*   **Fallback**: If Regex becomes too complex, use a lightweight pure-JS DOM parser (e.g., `dom-parser` ported functionality) or string splitting.

### 2.3 Concurrency
Swift uses `Task { await ... }`. ArkTS uses standard JavaScript `Promise` and `async/await`.
*   **Mapping**:
    *   `Task { ... }` → `setTimeout(() => { ... })` or direct async function call.
    *   `await` → `await` (identical syntax).
    *   `MainActor` → All ArkUI updates are already on the UI thread; no explicit dispatch needed usually, but can use `router` or specific context methods if background-threaded.
