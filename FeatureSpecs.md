# Application Feature Specification (Full Clone) - Definitive v5.0

## 1. Core Service Specifications (Technical)

### 1.1 Site Order (Strict)
1.  **4D4Y** (`4d4y`)
2.  **Linux.do** (`linux_do`)
3.  **Hacker News** (`hackernews`)
4.  **V2EX** (`v2ex`)
5.  **RSS Feeds** (`rss`)

### 1.2 Data Source Details
#### **1.2.1 4D4Y** (`FourD4YService`)
-   **Base URL**: `https://www.4d4y.com/forum`
-   **Encoding**: **GBK** (Must decode data using GBK encoding before string processing).
-   **Authentication**:
    -   **Login**: POST `loginsubmit=yes&inajax=1` to `/logging.php?action=login`.
    -   **Headers**: `User-Agent` (Mac Desktop Chrome string), `Referer`.
    -   **Session**: Extract `sid` and `formhash` from every HTML response. Persist `cdb_sid` and `cdb_auth` cookies.
-   **Parsing Regex Variables**:
    -   **Categories**: `href="forumdisplay\\.php\\?fid=(\\d+)[^\"]*\"[^>]*>([^<]+)</a>`
    -   **Thread List Row**: `<tbody[^>]*id=\"(?:normalthread_|thread_)(\\d+)\"[^>]*>(.*?)</tbody>`
    -   **Post Content**: `id=\"postmessage_(\\d+)\"[^>]*>(.*?)</td>`
    -   **Images**: `<img[^>]+src=\"([^\">]+)\` -> Replace with `[IMAGE:$1]`.

#### **1.2.2 Linux.do** (`DiscourseService`)
-   **Base URL**: `https://linux.do` (Discourse Instance).
-   **API Endpoints**:
    -   **Categories**: GET `/categories.json` -> `category_list.categories`.
    -   **Topic List**: GET `/c/{id}.json?page={p}` -> `topic_list.topics`.
    -   **Topic Detail**: GET `/t/{id}.json?page={p}` -> `post_stream.posts`.
-   **Data Mapping**:
    -   `topic.bumped_at` -> Time Ago.
    -   `post.cooked` -> HTML Content (Clean `<img>` classes like `avatar`, `emoji`).

#### **1.2.3 Hacker News** (`HackerNewsService`)
-   **Base URL**: `https://hacker-news.firebaseio.com/v0`
-   **Logic**:
    -   fetch `/{categoryId}.json` (e.g. `topstories`) -> `[Int]`.
    -   fetch `/item/{id}.json` -> `HNItem` (title, text, url, kids).
-   **Categories**: `topstories`, `newstories`, `beststories`, `showstories`, `askstories`, `jobstories`.

#### **1.2.4 V2EX** (`V2EXService`)
-   **Base URL**: `https://v2ex.com`
-   **Tabs**: `tech`, `creative`, `play`, `apple`, `jobs`, `deals`, `city`, `qna`, `hot`, `all`, `r2`, `xna`, `planet`.
-   **Parsing Logic**:
    -   **Thread List**: Split HTML by `class="cell item"`.
    -   **ID/Title**: `<a href=\"/t/(\\d+)[^\"]*\" class=\"topic-link\"[^>]*>(.*?)</a>`
    -   **Author**: `href=\"/member/([^\"]+)\"`
    -   **Replies**: `class=\"count_livid\">(\\d+)</a>`
    -   **Thread Detail**:
        -   **Title**: `<h1[^>]*>([^<]+)</h1>`
        -   **Content**: `<div class=\"topic_content\"[^>]*>(.*?)</div>`
        -   **Post (Comment)**: `<div id=\"r_(\d+)\" class=\"cell\">`

#### **1.2.5 RSS Integration** (`RSSService`)
-   **FR1.1**: Upon selecting "RSS" site, display pre-configured feeds:
    -   Hacker Podcast (`https://hacker-podcast.agi.li/rss.xml`)
    -   Ruanyifeng Blog (`https://www.ruanyifeng.com/blog/atom.xml`)
    -   O'Reilly Radar (`https://www.oreilly.com/radar/feed/`)
-   **FR1.2**: Tapping a feed fetches latest XML.
-   **FR1.3**: Parse standard RSS 2.0 / Atom.
-   **FR1.4**: List shows Title + Relative Time.
-   **FR1.5**: Detail shows cleaned content (no scripts/iframes) with images.
-   **UI States**: Loading (Spinner), Error (Toast/Text), Empty ("No articles").

## 2. Functional Requirements (Features)

### 2.1 Login & Authentication
-   **FR_Auth.1**: `LoginView` supports Username/Password fields.
-   **FR_Auth.2**: For 4D4Y/V2EX, extract `Set-Cookie` headers from response.
-   **FR_Auth.3**: AES-256 Encrypt credentials and cookies. Store in RDB/Preferences.
-   **FR_Auth.4**: Inject cookies into all subsequent HTTP requests for that service.

### 2.2 Bookmarks
-   **FR_BK.1**: User can bookmark any thread via Toolbar Icon or Swipe Action.
-   **FR_BK.2**: Persist Thread object JSON to local RDB `bookmarks` table immediately.
-   **FR_BK.3**: `BookmarksView` lists all saved items, sorted by `timestamp DESC`.
-   **FR_BK.4**: Tapping a bookmark opens `ThreadDetailView` in **Offline Mode** (using stored JSON).

### 2.3 AI Summary (Gemini)
-   **FR_AI.1**: Settings page admits `gemini_api_key`.
-   **FR_AI.2**: `AISummaryView` is triggered from `ThreadDetailView` toolbar (Sparkles icon).
-   **FR_AI.3**: State flow: "Summarize" Button -> Spinner -> Typed Text Block.
-   **FR_AI.4**: Result is cached in RDB `ai_summaries` table to prevent re-billing/latency.

### 2.4 Settings & Localization
-   **FR3.1**: Settings screen accessible from Main Toolbar.
-   **FR3.2**: Toggle Language (English <-> Chinese).
-   **FR3.3**: Preference persists across app restarts (RDB `settings` table).

## 3. View UI/UX Specifications (ArkUI Parity)

### 3.1 EntryAbility / Index (Main Container)
-   **UI Layout**: `NavigationStack` root.
-   **Feature Spec**:
    -   Act as the navigation host for the entire app.
    -   Host `SiteListView` as the default home destination.
    -   Ensure swipe-back gestures work globally.

### 3.2 SiteListView (Home)
-   **UI Layout**:
    -   **Toolbar**: [Left: Login, Settings, Bookmarks] [Right: Theme, Language].
    -   **Body**: `Grid` layout with adaptive columns (min 150dp).
    -   **Card**: `VStack { Avatar(40dp), Text(Headline) }` inside a rounded bordered card.
-   **Feature Spec**:
    -   Tapping a card pushes `CommunitiesView` (or `ThreadListView` for single-feed sites like RSS).
    -   Icons must match SF Symbols: `person.fill`, `key.fill`, `bookmark.fill`, `sun.max/moon`.

### 3.3 CommunitiesView (Categories)
-   **UI Layout**:
    -   `List` or `Scroll+VStack`.
    -   **Row**: `CommunityRow` -> Bold Name, smaller gray description below. Bottom separator line.
-   **Feature Spec**:
    -   Tapping a row pushes `ThreadListView` with that category ID.
    -   Toolbar **Refresh Button** force-reloads the category list.

### 3.4 ThreadListView (Topic List)
-   **UI Layout**:
    -   `List` with Pull-to-Refresh.
    -   **Row (`ThreadRow`)**:
        -   Top Line: Avatar(16dp) | Username | TimeAgo (Gray).
        -   Middle: Title (Max 2 lines, Primary Color).
        -   Bottom Right: Bubble Icon + Reply Count.
-   **Feature Spec**:
    -   **Pagination**: Scroll to bottom triggers next page fetch (if supported).
    -   **State**: Center Spinner on init. Bottom Spinner on paging.
    -   **FAB**: "Plus" button floating bottom-right (Forums only) -> Opens `NewThreadView`.

### 3.5 ThreadDetailView (Reading)
-   **UI Layout**:
    -   **Header**: `HStack { Avatar (40dp), VStack { Username, RolePill } }`.
    -   **Body**: `RichText` / `Web` component rendering HTML content.
        -   **Images**: Must be tappable.
    -   **Tags**: Scrollable row of pills (if applicable).
    -   **Comments**: Lazy loaded list of `CommentRow`.
    -   **Bottom Bar** (Sticky): `HStack { PhotoBtn, TextField, SendBtn }`.
-   **Feature Spec**:
    -   **Rich Text Interactions**:
        -   **Image Tap**: Detected via Web/RichText event -> Triggers `FullScreenImageView(url)`.
        -   **Link Tap**: Internal -> Push Nav; External -> Open Browser.
    -   **Cache Strategy**: `onAppear` load RDB cache immediately -> standard Background fetch -> Update UI when ready.
    -   **RSS Logic**: If `service.id == "rss"`, **HIDE** the sticky Bottom input bar.
    -   **Indicators**: Cloud (Green) = Online; Disk (Orange) = Offline.

### 3.6 LoginView
-   **UI Layout**: Form style.
-   **Components**:
    -   Picker("Site", selection: $site).
    -   TextField("Username"), SecureField("Password").
    -   Button("Save Credentials").
-   **Feature Spec**:
    -   Saving triggers AES encryption and storage.
    -   For 4D4Y, immediately attempts a test login to sync cookies.

### 3.7 SettingsView
-   **UI Layout**: Form style.
-   **Components**:
    -   SecureField("Gemini API Key").
-   **Feature Spec**: saves key to `settings` table.

## 4. Theme & Resources
### 4.1 Colors (Exact Hex)
-   **Light**: Bg `#F2F2F7`, Card `#FFFFFF`, Accent `#007AFF`.
-   **Dark**: Bg `#0B101B`, Card `#151C2C`, Accent `#2D62ED`.

### 4.2 Icons
-   Uses standard HarmonyOS `sys.symbol` closest matches to SF Symbols:
    -   `person.fill` -> `sys.symbol.person_crop_circle_fill`
    -   `gear` -> `sys.symbol.gear`
    -   `bookmark` -> `sys.symbol.bookmark`
