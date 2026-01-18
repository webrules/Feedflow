import Foundation

class V2EXService: ForumService {
    var name: String { "V2EX" }
    var id: String { "v2ex" }
    var logo: String { "v.circle.fill" } // System icon
    
    private let baseURL = "https://v2ex.com"
    
    func getWebURL(for thread: Thread) -> String {
        return "\(baseURL)/t/\(thread.id)"
    }
    
    // Read-Only service for now
    func postComment(topicId: String, categoryId: String, content: String) async throws {
        throw NSError(domain: "V2EX", code: 403, userInfo: [NSLocalizedDescriptionKey: "Posting not supported yet."])
    }
    
    func createThread(categoryId: String, title: String, content: String) async throws {
        throw NSError(domain: "V2EX", code: 403, userInfo: [NSLocalizedDescriptionKey: "Posting not supported yet."])
    }
    
    func fetchCategories() async throws -> [Community] {
        // V2EX Tabs mapped to Communities
        let tabs = [
            ("tech", "Tech"),
            ("creative", "Creative"),
            ("play", "Play"),
            ("apple", "Apple"),
            ("jobs", "Jobs"),
            ("deals", "Deals"),
            ("city", "City"),
            ("qna", "QnA"),
            ("hot", "Hot"),
            ("all", "All"),
            ("r2", "R2"),
            ("xna", "XNA"),
            ("planet", "Planet")
        ]
        
        return tabs.map { (id, name) in
            Community(
                id: id,
                name: name,
                description: "",
                category: "Tab",
                activeToday: 0,
                onlineNow: 0
            )
        }
    }
    
    func fetchCategoryThreads(categoryId: String, communities: [Community], page: Int) async throws -> [Thread] {
        // V2EX generally doesn't support pagination on tab pages easily via URL param (tabs show latest).
        // For specific "Nodes" (go/xxx) pagination works, but for Tabs (?tab=xxx), it's usually one page.
        // We'll ignore page > 1 for tabs for now to avoid errors, or duplicate content.
        if page > 1 { return [] }
        
        let url = URL(string: "\(baseURL)/?tab=\(categoryId)")!
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            print("[V2EX] Fetching \(url) - Status: \(httpResponse.statusCode)")
        }
        let html = String(decoding: data, as: UTF8.self)
        print("[V2EX] Fetched HTML length: \(html.count)")
        if html.isEmpty { print("[V2EX] HTML is empty!") }
        
        return parseThreads(from: html, categoryId: categoryId, communities: communities)
    }
    
    private func parseThreads(from html: String, categoryId: String, communities: [Community]) -> [Thread] {
        var threads: [Thread] = []
        let community = communities.first(where: { $0.id == categoryId }) ?? Community(id: categoryId, name: categoryId, description: "", category: "", activeToday: 0, onlineNow: 0)
        
        // Pattern: <div class="cell item" ...> ... <span class="item_title"><a href="/t/(\d+)(?:#reply\d+)?" class="topic-link">(.+?)</a></span> ... <strong><a href="/member/..." ...>(.+?)</a></strong>
        // We'll use a broader regex to capture the cell item block first, then extract details.
        
        // 1. Split into cell items
        // <div class="cell item" ...>
        let cellPattern = "<div class=\"cell item\"[^>]*>(.*?)</div>\\s*</div>" // Rough containment, might fail if nested divs are complex.
        // Better: Find "cell item" and iterate.
        
        let itemRegex = try! NSRegularExpression(pattern: "<div class=\"cell item\"[^>]*>(.*?)<table", options: [.dotMatchesLineSeparators])
         // Retrying logic: The structure is <div class="cell item"><table>...</table></div>.
         // Let's target the inner structure directly.
         // <a href="/t/123456#reply12" class="topic-link">Title</a>
        
        // Strategy: Find all topic-link matches, then find surrounding context? No, difficult.
        // Strategy: Regex for the whole block.
        // content: <span class="item_title"><a href="/t/1110006#reply8" class="topic-link">My Title</a></span>
        
        // Updated Pattern: <a href="/t/1186593#reply0" class="topic-link" id="topic-link-1186593">Title</a>
        // Note: The curl output confirms: href="/t/...", class="topic-link", id="topic-link-..."
        // We need to capture the ID from the href, and the title from the content.
        // href="/t/(\d+)..."
        // class="topic-link"
        // content >(.*?)</a>
        
        let blockPattern = "<a href=\"/t/(\\d+)[^\"]*\" class=\"topic-link\"[^>]*>(.*?)</a>"
        let blockRegex = try! NSRegularExpression(pattern: blockPattern, options: [])
        let matches = blockRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        print("[V2EX] Parsing threads... Found \(matches.count) initial matches.")
        
        for match in matches {
            guard let idRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else { continue }
            
            let id = String(html[idRange])
            let titleRaw = String(html[titleRange])
            
            // Clean title (sometimes has entities)
            let title = titleRaw.replacingOccurrences(of: "&amp;", with: "&")
                                .replacingOccurrences(of: "&lt;", with: "<")
                                .replacingOccurrences(of: "&gt;", with: ">")
                                .replacingOccurrences(of: "&quot;", with: "\"")
            
            // For now, simple placeholder for author/replies as extracting them reliably requires matching the exact surrounding table cell which is tricky with simple regex on full HTML.
            // We can try to approximate: look ahead for count_livid.
            
            // To make this robust:
            // Let's assume the user wants the title and link primarily.
            // We can fetch details in `fetchThreadDetail`.
            
            threads.append(Thread(
                id: id,
                title: title,
                content: "",
                author: User(id: "unknown", username: "User", avatar: "person.circle", role: nil),
                community: community,
                timeAgo: "",
                likeCount: 0,
                commentCount: 0, // Fill if possible
                isLiked: false,
                tags: nil
            ))
        }
        
        // Improve Parsing: Try to extract author and reply count if possible by finding specific segments.
        // Actually, let's try a split approach. Split by className="cell item".
        let cells = html.components(separatedBy: "class=\"cell item\"")
        if cells.count > 1 {
            var improvedThreads: [Thread] = []
            for cell in cells.dropFirst() {
                // Extract ID and Title
                guard let titleMatch = blockRegex.firstMatch(in: cell, options: [], range: NSRange(cell.startIndex..., in: cell)),
                      let idRange = Range(titleMatch.range(at: 1), in: cell),
                      let titleRange = Range(titleMatch.range(at: 2), in: cell) else { continue }
                
                let id = String(cell[idRange])
                let title = String(cell[titleRange]).replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
                
                // Extract Author: <strong><a href="/member/username" ...>username</a></strong>
                var authorName = "Unknown"
                if let authorRegex = try? NSRegularExpression(pattern: "href=\"/member/([^\"]+)\""),
                   let match = authorRegex.firstMatch(in: cell, options: [], range: NSRange(cell.startIndex..., in: cell)),
                   let r = Range(match.range(at: 1), in: cell) {
                    authorName = String(cell[r])
                }
                
                // Extract Reply Count: class="count_livid">12</a>
                var replyCount = 0
                if let countRegex = try? NSRegularExpression(pattern: "class=\"count_livid\">(\\d+)</a>"),
                   let match = countRegex.firstMatch(in: cell, options: [], range: NSRange(cell.startIndex..., in: cell)),
                   let r = Range(match.range(at: 1), in: cell) {
                    replyCount = Int(String(cell[r])) ?? 0
                }
                
                improvedThreads.append(Thread(
                    id: id,
                    title: title,
                    content: "",
                    author: User(id: authorName, username: authorName, avatar: "person.circle", role: nil),
                    community: community,
                    timeAgo: "",
                    likeCount: 0,
                    commentCount: replyCount,
                    isLiked: false,
                    tags: nil
                ))
            }
            
            print("[V2EX] Improved parsing found \(improvedThreads.count) threads.")
            if !improvedThreads.isEmpty {
                return improvedThreads
            } else {
                 print("[V2EX] Improved parsing failed despite finding cells. Falling back to basic parsing.")
            }
        }
        
        print("[V2EX] Returning \(threads.count) threads from basic parsing.")
        return threads
    }
    
    func fetchThreadDetail(threadId: String, page: Int) async throws -> (Thread, [Comment], Int?) {
        if page > 1 {
             let dummy = Thread(id: threadId, title: "", content: "", author: User(id: "", username: "", avatar: "", role: nil), community: Community(id: "", name: "", description: "", category: "", activeToday: 0, onlineNow: 0), timeAgo: "", likeCount: 0, commentCount: 0, isLiked: false, tags: nil)
             return (dummy, [], nil)
        }
        
        let url = URL(string: "\(baseURL)/t/\(threadId)?p=\(page)")!
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(decoding: data, as: UTF8.self)
        
        // 1. Extract Title: <h1>Title</h1>
        var title = "Unknown Title"
        if let titleRegex = try? NSRegularExpression(pattern: "<h1[^>]*>([^<]+)</h1>"),
           let match = titleRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
           let r = Range(match.range(at: 1), in: html) {
             title = String(html[r])
        }
        
        // 2. Extract Content: <div class="topic_content">...</div>
        var content = ""
        if let contentRegex = try? NSRegularExpression(pattern: "<div class=\"topic_content\"[^>]*>(.*?)</div>", options: [.dotMatchesLineSeparators]),
           let match = contentRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
           let r = Range(match.range(at: 1), in: html) {
            content = cleanContent(String(html[r]))
        }
        
        // 3. Extract Author: <div class="header"> ... <a href="/member/...">Author</a>
        var authorName = "Unknown"
         if let headerRegex = try? NSRegularExpression(pattern: "<div class=\"header\">(?:.|\\n)*?href=\"/member/([^\"]+)\""),
           let match = headerRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
           let r = Range(match.range(at: 1), in: html) {
             authorName = String(html[r])
        }
        
        let thread = Thread(
            id: threadId,
            title: title,
            content: content,
            author: User(id: authorName, username: authorName, avatar: "person.circle", role: nil),
            community: Community(id: "v2ex", name: "V2EX", description: "", category: "General", activeToday: 0, onlineNow: 0),
            timeAgo: "",
            likeCount: 0,
            commentCount: 0, // Calculate from comments
            isLiked: false,
            tags: nil
        )
        
        // 4. Extract Comments
        // Each comment is in a div with id starting with r_
        // <div id="r_123456" class="cell"> ... </div>
        var comments: [Comment] = []
        let commentCells = html.components(separatedBy: "id=\"r_")
        
        for cell in commentCells.dropFirst() {
            // Re-prepend id="r_" isn't strictly necessary if we just look for content
            // Structure:
            // ... class="dark">Author</a>
            // ... class="reply_content">Content</div>
            // ... class="ago">Time</span>
            
            var cAuthor = "Unknown"
            if let aRegex = try? NSRegularExpression(pattern: "class=\"dark\">([^<]+)</a>"),
               let match = aRegex.firstMatch(in: cell, options: [], range: NSRange(cell.startIndex..., in: cell)),
               let r = Range(match.range(at: 1), in: cell) {
                cAuthor = String(cell[r])
            }
            
            var cContent = ""
            if let cRegex = try? NSRegularExpression(pattern: "class=\"reply_content\">((?:.|\\n)*?)</div>"),
               let match = cRegex.firstMatch(in: cell, options: [], range: NSRange(cell.startIndex..., in: cell)),
               let r = Range(match.range(at: 1), in: cell) {
                cContent = cleanContent(String(cell[r]))
            }
            
            var cTime = ""
            if let tRegex = try? NSRegularExpression(pattern: "class=\"ago\"[^>]*>([^<]+)</span>"),
               let match = tRegex.firstMatch(in: cell, options: [], range: NSRange(cell.startIndex..., in: cell)),
               let r = Range(match.range(at: 1), in: cell) {
                cTime = String(cell[r])
            }
            
            // ID is at start of cell string before first quote?
            // "123456" class="cell" ...
            let cId = String(cell.prefix(while: { $0.isNumber }))
            
            if !cContent.isEmpty {
                comments.append(Comment(
                    id: cId,
                    author: User(id: cAuthor, username: cAuthor, avatar: "person.circle", role: nil),
                    content: cContent,
                    timeAgo: cTime,
                    likeCount: 0,
                    replies: nil
                ))
            }
        }
        
        return (thread, comments, 1)
    }
    
    private func cleanContent(_ html: String) -> String {
        var processed = html
        
        // Handle images: <img src="...">
        if let imgRegex = try? NSRegularExpression(pattern: "<img[^>]+src=\"([^\">]+)\"[^>]*>", options: .caseInsensitive) {
            let matches = imgRegex.matches(in: processed, range: NSRange(processed.startIndex..., in: processed))
            for match in matches.reversed() {
                if let r = Range(match.range(at: 1), in: processed),
                   let fullR = Range(match.range, in: processed) {
                    let src = String(processed[r])
                    processed.replaceSubrange(fullR, with: "\n[IMAGE:\(src)]\n")
                }
            }
        }
        
        processed = processed.replacingOccurrences(of: "<br>", with: "\n")
                             .replacingOccurrences(of: "<br />", with: "\n")
                             .replacingOccurrences(of: "<p>", with: "\n\n")
                             .replacingOccurrences(of: "</p>", with: "")
        
        processed = processed.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        
        processed = processed.replacingOccurrences(of: "&nbsp;", with: " ")
                             .replacingOccurrences(of: "&amp;", with: "&")
                             .replacingOccurrences(of: "&lt;", with: "<")
                             .replacingOccurrences(of: "&gt;", with: ">")
                             .replacingOccurrences(of: "&quot;", with: "\"")
        
        return processed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
