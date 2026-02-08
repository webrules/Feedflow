import Foundation
import CoreFoundation

class FourD4YService: ForumService {
    var name: String { "4D4Y" }
    var id: String { "4d4y" }
    var logo: String { "4.square.fill" } // System icon
    
    private let baseURL = "https://www.4d4y.com/forum"
    private var currentSID: String?
    private var currentFormHash: String?
    
    // GBK Encoding
    private var gbkEncoding: String.Encoding {
        let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        return String.Encoding(rawValue: encoding)
    }
    
    func getWebURL(for thread: Thread) -> String {
        return "\(baseURL)/viewthread.php?tid=\(thread.id)"
    }
    
    func login(username: String, password: String) async throws -> [HTTPCookie] {
        // Login page to get initial cookies and possible hidden fields (e.g., formhash)
        let loginPageURL = URL(string: "\(baseURL)/logging.php?action=login")!
        var initialRequest = URLRequest(url: loginPageURL)
        initialRequest.httpMethod = "GET"
        initialRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        // Perform GET to obtain any required cookies (e.g., cf_clearance)
        let (_, _) = try await URLSession.shared.data(for: initialRequest)
        // Grab cookies set by the GET request
        let cookieStorage = HTTPCookieStorage.shared
        guard let loginPageCookies = cookieStorage.cookies(for: loginPageURL) else { return [] }
        
        // Build POST body – typical Discuz login fields
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "loginsubmit", value: "yes"),
            URLQueryItem(name: "inajax", value: "1"),
            URLQueryItem(name: "cookietime", value: "2592000") // 30 days persistent cookie
        ]
        let postBody = components.percentEncodedQuery?.data(using: .utf8) ?? Data()
        
        let loginURL = URL(string: "\(baseURL)/logging.php?action=login&loginsubmit=yes&inajax=1")!
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.httpBody = postBody
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        // Include cookies from the GET request
        let cookieHeader = HTTPCookie.requestHeaderFields(with: loginPageCookies)
        request.allHTTPHeaderFields?.merge(cookieHeader) { (_, new) in new }
        
        // Perform POST login
        let (_, response) = try await URLSession.shared.data(for: request)
        // Capture cookies after login from headers as well
        guard let httpResponse = response as? HTTPURLResponse,
              let headerFields = httpResponse.allHeaderFields as? [String: String],
              let url = httpResponse.url else { return [] }
        
        let newCookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        return newCookies
    }
    
    private func syncCookiesToSystem() {
        let saved = DatabaseManager.shared.getCookies(siteId: id) ?? []
        // Only sync cookies that actually belong to 4d4y domain
        let relevant = saved.filter { $0.domain.contains("4d4y.com") }
        if relevant.isEmpty {
            print("[4D4Y] WARNING: No 4d4y cookies found in DB for site '\(id)'. User may not be logged in.")
        } else {
            let names = relevant.map { "\($0.name)(\($0.domain))" }.joined(separator: ", ")
            print("[4D4Y] Syncing \(relevant.count) cookies to system: \(names)")
        }
        for cookie in relevant {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    
    private func loadSavedCookies() -> [HTTPCookie] {
        return DatabaseManager.shared.getCookies(siteId: id) ?? []
    }
    
    private func fetchContent(url: URL) async throws -> String {
        // Load saved cookies directly from DB
        let savedCookies = DatabaseManager.shared.getCookies(siteId: id) ?? []
        let relevant = savedCookies.filter { $0.domain.contains("4d4y.com") }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        // Manually set cookies in the request header to guarantee they're sent
        // (HTTPCookieStorage automatic handling can silently drop cookies)
        if !relevant.isEmpty {
            let cookieHeader = relevant.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            request.httpShouldHandleCookies = false  // Don't let URLSession override our manual cookies
            print("[4D4Y] Sending \(relevant.count) cookies manually: \(relevant.map { $0.name }.joined(separator: ", "))")
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        

        // Try GBK decode first
        var html = ""
        if let decoded = String(data: data, encoding: gbkEncoding) {
            html = decoded
        } else {
            html = String(decoding: data, as: UTF8.self)
        }
        
        // Always try to extract SID/FormHash from every response to keep them "latest"
        extractSID(from: html)
        
        return html
    }
    
    private func extractSID(from html: String) {
        // 1. Extract SID
        if let regex = try? NSRegularExpression(pattern: "sid=([a-zA-Z0-9]+)", options: []) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range) {
                if let r = Range(match.range(at: 1), in: html) {
                    self.currentSID = String(html[r])
                    print("[4D4Y] Extracted SID: \(self.currentSID!)")
                    
                    // Set SID cookie on in-memory session only (don't persist to DB to avoid overwriting login cookies)
                    if let sidCookie = HTTPCookie(properties: [
                        .name: "cdb_sid",
                        .value: self.currentSID!,
                        .domain: "www.4d4y.com",
                        .path: "/forum",
                        .expires: Date().addingTimeInterval(86400)
                    ]) {
                        HTTPCookieStorage.shared.setCookie(sidCookie)
                    }
                }
            }
        }
        
        // 2. Extract FormHash
        if let regex = try? NSRegularExpression(pattern: "formhash=([a-zA-Z0-9]+)", options: []) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range) {
                if let r = Range(match.range(at: 1), in: html) {
                    self.currentFormHash = String(html[r])
                    print("[4D4Y] Extracted FormHash: \(self.currentFormHash!)")
                }
            }
        }
    }
    
    func fetchCategories() async throws -> [Community] {
        return try await fetchCategoriesInternal(retryCount: 0)
    }
    
    private func fetchCategoriesInternal(retryCount: Int) async throws -> [Community] {
        let url = URL(string: "\(baseURL)/index.php")!
        print("[4D4Y] Fetching index: \(url)")
        let html = try await fetchContent(url: url)
        print("[4D4Y] Index fetched. Length: \(html.count)")
        
        extractSID(from: html)
        
        var communities: [Community] = []
        
        // Broad pattern to capture fid and name.
        // Handles: <a href="forumdisplay.php?fid=7" style="">Name</a>
        // Key fix: Allow any attributes after href value before closing >
        let pattern = "href=\"forumdisplay\\.php\\?fid=(\\d+)[^\"]*\"[^>]*>([^<]+)</a>"
        // print("[4D4Y] Using Regex: \(pattern)")
        
        let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        
        print("[4D4Y] Found \(matches.count) forum matches")
        
        for match in matches {
            if let fidRange = Range(match.range(at: 1), in: html),
               let nameRange = Range(match.range(at: 2), in: html) {
                
                let fid = String(html[fidRange])
                let name = String(html[nameRange])
                
                if !communities.contains(where: { $0.id == fid }) {
                    communities.append(Community(
                        id: fid,
                        name: name,
                        description: "",
                        category: "Forum",
                        activeToday: 0, 
                        onlineNow: 0
                    ))
                }
            }
        }
        
        // If results are empty, try auto-login if possible
        if communities.isEmpty && retryCount == 0 {
            print("[4D4Y] No categories found. Attempting auto-login and retry...")
            if try await performAutoLogin() {
                return try await fetchCategoriesInternal(retryCount: 1)
            }
        }
        
        return communities
    }
    
    func fetchCategoryThreads(categoryId: String, communities: [Community], page: Int) async throws -> [Thread] {
        return try await fetchCategoryThreadsInternal(categoryId: categoryId, communities: communities, page: page, retryCount: 0)
    }
    
    private func fetchCategoryThreadsInternal(categoryId: String, communities: [Community], page: Int, retryCount: Int) async throws -> [Thread] {
        // Ensure we have a SID. If not, try to fetch index first.
        if currentSID == nil {
             _ = try await fetchCategories()
        }
        
        let sidParam = currentSID.map { "&sid=\($0)" } ?? ""
        // Add page param
        let pageParam = page > 1 ? "&page=\(page)" : ""
        
        let url = URL(string: "\(baseURL)/forumdisplay.php?fid=\(categoryId)\(sidParam)\(pageParam)")!
        let html = try await fetchContent(url: url)
        
        var threads: [Thread] = []
        let community = communities.first(where: { $0.id == categoryId }) ?? Community(id: categoryId, name: "Unknown", description: "", category: "", activeToday: 0, onlineNow: 0)
        
        // Extract thread rows - each row has id="normalthread_*" or id="thread_*"
        // Pattern: Find each thread row, then extract tid, title, author, and reply count from within that row
        let threadRowPattern = "<tbody[^>]*id=\"(?:normalthread_|thread_)(\\d+)\"[^>]*>(.*?)</tbody>"
        let threadRowRegex = try NSRegularExpression(pattern: threadRowPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let threadMatches = threadRowRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        
        print("[4D4Y] Fetching threads from: \(url)")
        print("[4D4Y] Found \(threadMatches.count) thread rows")
        
        for (index, threadMatch) in threadMatches.enumerated() {
            guard let tidRange = Range(threadMatch.range(at: 1), in: html),
                  let rowContentRange = Range(threadMatch.range(at: 2), in: html) else {
                continue
            }
            
            let tid = String(html[tidRange])
            let rowContent = String(html[rowContentRange])
            
            // Extract title from viewthread.php link within this row
            var title = "Unknown Title"
            if let titleRegex = try? NSRegularExpression(pattern: "href=\"viewthread\\.php\\?tid=\\d+[^\"]*\"[^>]*>([^<]+)</a>", options: .caseInsensitive),
               let titleMatch = titleRegex.firstMatch(in: rowContent, options: [], range: NSRange(rowContent.startIndex..., in: rowContent)),
               let titleTextRange = Range(titleMatch.range(at: 1), in: rowContent) {
                title = String(rowContent[titleTextRange])
            }
            
            // Extract author from <td class="author"><a>authorname</a> within this row
            var authorName = "Unknown"
            if let authorRegex = try? NSRegularExpression(pattern: "<td\\s+class=\"author\"[^>]*>.*?<a[^>]*>([^<]+)</a>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let authorMatch = authorRegex.firstMatch(in: rowContent, options: [], range: NSRange(rowContent.startIndex..., in: rowContent)),
               let authorTextRange = Range(authorMatch.range(at: 1), in: rowContent) {
                authorName = String(rowContent[authorTextRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Extract reply count from <td class="nums"><strong>count</strong> within this row
            var replyCount = 0
            if let numsRegex = try? NSRegularExpression(pattern: "<td\\s+class=\"nums\"[^>]*>.*?<strong>(\\d+)</strong>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let numsMatch = numsRegex.firstMatch(in: rowContent, options: [], range: NSRange(rowContent.startIndex..., in: rowContent)),
               let countTextRange = Range(numsMatch.range(at: 1), in: rowContent),
               let count = Int(String(rowContent[countTextRange])) {
                replyCount = count
            }
            
            // Debug first few
            if index < 3 {
                print("[4D4Y] Thread \(index): tid=\(tid), title=\(title), author=\(authorName), replies=\(replyCount)")
            }
            
            // Add thread
            if !threads.contains(where: { $0.id == tid }) {
                threads.append(Thread(
                    id: tid,
                    title: title,
                    content: "",
                    author: User(id: "0", username: authorName, avatar: "person.circle", role: nil),
                    community: community,
                    timeAgo: "",
                    likeCount: 0,
                    commentCount: replyCount,
                    isLiked: false,
                    tags: nil
                ))
            }
        }
        print("[4D4Y] Returning \(threads.count) unique threads")
        
        // If results are empty and it's the first page, try auto-login if possible
        if threads.isEmpty && page == 1 && retryCount == 0 {
            print("[4D4Y] No threads found. Attempting auto-login and retry...")
            if try await performAutoLogin() {
                // Clear SID to force refresh after login
                self.currentSID = nil
                return try await fetchCategoryThreadsInternal(categoryId: categoryId, communities: communities, page: page, retryCount: 1)
            }
        }
        
        return threads
    }
    
    private func performAutoLogin() async throws -> Bool {
        print("[4D4Y] Attempting auto-login...")
        guard let encryptedUsername = DatabaseManager.shared.getSetting(key: "login_\(id)_username"),
              let encryptedPassword = DatabaseManager.shared.getSetting(key: "login_\(id)_password"),
              let username = EncryptionHelper.shared.decrypt(encryptedUsername),
              let password = EncryptionHelper.shared.decrypt(encryptedPassword) else {
            print("[4D4Y] No saved credentials found for auto-login.")
            return false
        }
        
        do {
            let cookies = try await login(username: username, password: password)
            if !cookies.isEmpty {
                DatabaseManager.shared.saveCookies(siteId: id, cookies: cookies)
                print("[4D4Y] Auto-login successful.")
                return true
            }
        } catch {
            print("[4D4Y] Auto-login failed: \(error)")
        }
        return false
    }
    
    func fetchThreadDetail(threadId: String, page: Int) async throws -> (Thread, [Comment], Int?) {
        return try await fetchThreadDetailInternal(threadId: threadId, page: page, retryCount: 0)
    }
    
    private func fetchThreadDetailInternal(threadId: String, page: Int, retryCount: Int) async throws -> (Thread, [Comment], Int?) {
         let sidParam = currentSID.map { "&sid=\($0)" } ?? ""
         // Need to handle both standard page param and 'extra' param if relevant, but typically &page=2 works for viewthread.php
         let pageParam = page > 1 ? "&page=\(page)&extra=page%3D1" : ""
         
         let url = URL(string: "\(baseURL)/viewthread.php?tid=\(threadId)\(sidParam)\(pageParam)")!
         print("[4D4Y] Fetching thread detail: \(url)")
         let html = try await fetchContent(url: url)
         
         // 0. Extract Max Pages
         // Discuz 7.2: <div class="pages">... <a ...>1</a> <strong>2</strong> <a ...>3</a> ... </div>
         // Or <div class="pages">1</div> (sometimes implied)
         var totalPages: Int = 1
         if let pagesRegex = try? NSRegularExpression(pattern: "<div class=\"pages\">(.*?)</div>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
            let match = pagesRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
            let range = Range(match.range(at: 1), in: html) {
             let pagesContent = String(html[range])
             
             // Find all numbers inside >...< or just naked numbers (if any)
             // simplified: look for any number > 0. The max is likely the total pages
             if let numRegex = try? NSRegularExpression(pattern: "(?:>|\\s)(\\d+)(?:<|\\s)", options: []) {
                  let numMatches = numRegex.matches(in: pagesContent, range: NSRange(pagesContent.startIndex..., in: pagesContent))
                  let nums = numMatches.compactMap { m -> Int? in
                      if let r = Range(m.range(at: 1), in: pagesContent) {
                          return Int(String(pagesContent[r]))
                      }
                      return nil
                  }
                  if let max = nums.max() {
                      totalPages = max
                  }
             }
         }
         
         // Extract FID from breadcrumbs: forumdisplay.php?fid=7
         var currentFid = "0"
         if let fidRegex = try? NSRegularExpression(pattern: "forumdisplay\\.php\\?fid=(\\d+)", options: []),
            let match = fidRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
            let range = Range(match.range(at: 1), in: html) {
             currentFid = String(html[range])
             print("[4D4Y] Extracted Topic FID: \(currentFid)")
         }
         
         // 1. Extract Title
         // <title>Title - ...</title> or <h1>
         var title = "Unknown Topic"
         if let titleRegex = try? NSRegularExpression(pattern: "<title>(.*?)(?: - |<)", options: .caseInsensitive),
            let match = titleRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
            let r = Range(match.range(at: 1), in: html) {
             title = String(html[r])
         }
         
         // 2. Extract Threads/Comments
         // Standard Discuz: <div class="postmessage"> ... </div> or id="postmessage_..."
         // We can look for <td class="t_msgfont" id="postmessage_...">Content</td>
         
         // First, let's extract all post blocks with their content AND usernames
         // Pattern to find post blocks: Look for postauthor section followed by content
         // We'll extract username from: <td class="postauthor">...<div class="postinfo">...<a>USERNAME</a>
         
         // Extract usernames from postauthor sections
         let authorPattern = "class=\"postauthor\"[^>]*>.*?class=\"postinfo\"[^>]*>.*?<a[^>]*>([^<]+)</a>"
         let authorRegex = try NSRegularExpression(pattern: authorPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
         let authorMatches = authorRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
         
         var usernames: [String] = []
         for match in authorMatches {
             if let usernameRange = Range(match.range(at: 1), in: html) {
                 let username = String(html[usernameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                 usernames.append(username)
             }
         }
         
         // Let's assume class "t_msgfont" is used for content
         let contentPattern = "id=\"postmessage_(\\d+)\"[^>]*>(.*?)</td>" // Simplified
         // Note: Regex parsing HTML is fragile. using SwiftSoup would be better but we don't have it.
         // We will try a flexible regex.
         
         // Capture PID in group 1, content in group 2
         let contentRegex = try NSRegularExpression(pattern: "class=\"t_msgfont\"[^>]*id=\"postmessage_(\\d+)\"[^>]*>(.*?)</td>", options: [.caseInsensitive, .dotMatchesLineSeparators])
         let matches = contentRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
         
         var mainThread: Thread?
         var comments: [Comment] = []
         
         for (index, match) in matches.enumerated() {
             guard let pidRange = Range(match.range(at: 1), in: html),
                   let contentRange = Range(match.range(at: 2), in: html) else {
                 continue
             }
             
             let pid = String(html[pidRange])
             let rawContent = String(html[contentRange])
             let cleanContent = self.cleanContent(rawContent)
             
             // Get username from extracted array, fallback to "User" if index out of bounds
             let username = index < usernames.count ? usernames[index] : "User"
             let user = User(id: "0", username: username, avatar: "person.circle", role: nil)
             
             // 4D4Y/Discuz specific: The first post on Page 1 is the Topic content.
             // ...
             
             let isMainThread = (page == 1 && index == 0)
             
             if isMainThread {
                 mainThread = Thread(
                     id: threadId,
                     title: title,
                     content: cleanContent,
                     author: user,
                     community: Community(id: currentFid, name: "", description: "", category: "", activeToday: 0, onlineNow: 0),
                     timeAgo: "Just now",
                     likeCount: 0,
                     commentCount: matches.count - 1,   // Approximate
                     isLiked: false,
                     tags: nil
                 )
             } else {
                 comments.append(Comment(
                     id: pid, // Use extracted PID
                     author: user,
                     content: cleanContent,
                     timeAgo: "",
                     likeCount: 0,
                     replies: nil
                 ))
             }
         }
         
         if let main = mainThread {
             return (main, comments, totalPages)
         } else if !comments.isEmpty {
             // Page > 1 case: No main thread, just comments.
             // Return a placeholder main thread (it will be ignored by the ViewModel update logic anyway)
             let placeholder = Thread(id: threadId, title: title, content: "", author: User(id: "0", username: "", avatar: "", role: nil), community: Community(id: currentFid, name: "", description: "", category: "", activeToday: 0, onlineNow: 0), timeAgo: "", likeCount: 0, commentCount: 0, isLiked: false, tags: nil)
             return (placeholder, comments, totalPages)
         } else {
             // Fallback if regex failed completely or page is empty
             
             if page == 1 && retryCount == 0 {
                 print("[4D4Y] No content found in thread detail. Attempting auto-login and retry...")
                 if try await performAutoLogin() {
                     self.currentSID = nil
                     return try await fetchThreadDetailInternal(threadId: threadId, page: page, retryCount: 1)
                 }
             }
             
             let empty = Thread(id: threadId, title: title, content: "Could not parse content.", author: User(id: "0", username: "System", avatar: "exclamationmark.triangle", role: nil), community: Community(id: currentFid, name: "Error", description: "", category: "", activeToday: 0, onlineNow: 0), timeAgo: "", likeCount: 0, commentCount: 0, isLiked: false, tags: nil)
             return (empty, [], totalPages)
         }
    }
    
    func postComment(topicId: String, categoryId: String, content: String) async throws {
        do {
            try await postCommentInternal(topicId: topicId, categoryId: categoryId, content: content)
        } catch {
            let errorString = error.localizedDescription
            if errorString.contains("未登录") || errorString.contains("登录") || errorString.contains("login") || errorString.contains("无权访问") {
                print("[4D4Y] Auth error detected during reply. Attempting auto-login...")
                if try await performAutoLogin() {
                    // Reset session identifiers to force fresh ones during retry
                    self.currentSID = nil 
                    self.currentFormHash = nil
                    
                    print("[4D4Y] Retrying reply after auto-login...")
                    try await postCommentInternal(topicId: topicId, categoryId: categoryId, content: content)
                    return
                }
            }
            throw error
        }
    }
    
    private func postCommentInternal(topicId: String, categoryId: String, content: String) async throws {
        // Ensure system storage has our saved cookies
        syncCookiesToSystem()
        
        // 1. Ensure we have a formhash
        if currentFormHash == nil {
            _ = try await fetchThreadDetail(threadId: topicId, page: 1)
        }
        
        guard let formhash = currentFormHash else {
            throw NSError(domain: "4D4Y", code: 401, userInfo: [NSLocalizedDescriptionKey: "No formhash found. Are you logged in?"])
        }
        
        // 2. Prepare POST URL - Include SID and inajax=1
        let sidParam = currentSID.map { "&sid=\($0)" } ?? ""
        let url = URL(string: "\(baseURL)/post.php?action=reply&fid=\(categoryId)&tid=\(topicId)&extra=&replysubmit=yes&inajax=1\(sidParam)")!
        
        // 3. Construct Body
        let postData: [String: String] = [
            "formhash": formhash,
            "posttime": "\(Int(Date().timeIntervalSince1970))",
            "wysiwyg": "1",
            "noticeauthor": "",
            "noticetrimstr": "",
            "noticeauthormsg": "",
            "subject": "",
            "message": content,
            "replysubmit": "yes",
            "inajax": "1"
        ]
        
        // Manual body building with GBK encoding
        var parts: [String] = []
        for (key, value) in postData {
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = gbkEncode(value)
            parts.append("\(encodedKey)=\(encodedValue)")
        }
        let bodyString = parts.joined(separator: "&")
        guard let bodyData = bodyString.data(using: .utf8) else {
            throw NSError(domain: "4D4Y", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to encode post body."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        
        // Comprehensive headers to mimic a browser AJAX request
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/xml, */*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("\(baseURL)/viewthread.php?tid=\(topicId)", forHTTPHeaderField: "Referer")
        request.setValue("https://www.4d4y.com", forHTTPHeaderField: "Origin")
        
        // Note: URLSession.shared.data(for:) automatically handles HTTPCookieStorage.shared
        // but we can manually inject if needed. Given we just called syncCookiesToSystem(),
        // the storage should be current.
        
        print("[4D4Y] Sending AJAX reply (tid=\(topicId))...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("[4D4Y] Reply response: \(httpResponse.statusCode)")
            
            let responseString = String(data: data, encoding: gbkEncoding) ?? String(decoding: data, as: UTF8.self)
            
            if responseString.contains("succeed") || responseString.contains("成功") || responseString.contains("发布") {
                print("[4D4Y] Reply successful.")
            } else {
                print("[4D4Y] Reply response content: \(responseString)")
                var errorMessage = "Unknown error"
                if let regex = try? NSRegularExpression(pattern: "<!\\[CDATA\\[(.*?)\\]\\]>", options: [.dotMatchesLineSeparators]),
                   let match = regex.firstMatch(in: responseString, options: [], range: NSRange(responseString.startIndex..., in: responseString)),
                   let range = Range(match.range(at: 1), in: responseString) {
                    errorMessage = String(responseString[range])
                } else if responseString.contains("ajaxerror") {
                    errorMessage = "Not logged in or access denied (AJAX error)."
                }
                
                print("[4D4Y] Reply FAILED: \(errorMessage)")
                throw NSError(domain: "4D4Y", code: 403, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        }
    }
    
    func createThread(categoryId: String, title: String, content: String) async throws {
        // Ensure system storage has our saved cookies
        syncCookiesToSystem()
        
        // 1. Ensure we have a formhash
        if currentFormHash == nil {
            _ = try await fetchCategories() // Usually index has a formhash too
        }
        
        guard let formhash = currentFormHash else {
            throw NSError(domain: "4D4Y", code: 401, userInfo: [NSLocalizedDescriptionKey: "No formhash found. Are you logged in?"])
        }
        
        // 2. Prepare POST URL
        let sidParam = currentSID.map { "&sid=\($0)" } ?? ""
        let url = URL(string: "\(baseURL)/post.php?action=newthread&fid=\(categoryId)&extra=&topicsubmit=yes&inajax=1\(sidParam)")!
        
        // 3. Construct Body
        let postData: [String: String] = [
            "formhash": formhash,
            "posttime": "\(Int(Date().timeIntervalSince1970))",
            "wysiwyg": "1",
            "subject": title,
            "message": content,
            "topicsubmit": "yes",
            "inajax": "1"
        ]
        
        var parts: [String] = []
        for (key, value) in postData {
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = gbkEncode(value)
            parts.append("\(encodedKey)=\(encodedValue)")
        }
        let bodyString = parts.joined(separator: "&")
        guard let bodyData = bodyString.data(using: .utf8) else {
            throw NSError(domain: "4D4Y", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to encode post body."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/xml, */*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        
        print("[4D4Y] Creating new thread (fid=\(categoryId))...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            let responseString = String(data: data, encoding: gbkEncoding) ?? String(decoding: data, as: UTF8.self)
            
            if responseString.contains("succeed") || responseString.contains("成功") {
                print("[4D4Y] Thread creation successful.")
            } else {
                print("[4D4Y] Thread creation FAILED: \(responseString)")
                throw NSError(domain: "4D4Y", code: 403, userInfo: [NSLocalizedDescriptionKey: "Failed to create thread."])
            }
        }
    }
    
    private func gbkEncode(_ string: String) -> String {
        guard let data = string.data(using: gbkEncoding) else {
            return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        }
        
        return data.map { byte in
            // Keep alphanumeric and safe chars as is, percent encode others
            if (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) || 
               byte == 45 || byte == 95 || byte == 46 || byte == 42 {
                return String(UnicodeScalar(byte))
            } else {
                return String(format: "%%%02X", byte)
            }
        }.joined()
    }
    
    private func cleanContent(_ html: String) -> String {
        var processed = html
        
        // 0. Remove attachment info (class="t_attach")
        // Pattern: <div class="t_attach">...</div> or <ignore_js_op>...</ignore_js_op>
        do {
            let attachRegex = try NSRegularExpression(pattern: "<div\\s+class=\"t_attach\"[^>]*>.*?</div>", options: [.caseInsensitive, .dotMatchesLineSeparators])
            processed = attachRegex.stringByReplacingMatches(in: processed, range: NSRange(processed.startIndex..., in: processed), withTemplate: "")
            
            // Also remove ignore_js_op tags often used for attachments
            let ignoreRegex = try NSRegularExpression(pattern: "<ignore_js_op>.*?</ignore_js_op>", options: [.caseInsensitive, .dotMatchesLineSeparators])
            processed = ignoreRegex.stringByReplacingMatches(in: processed, range: NSRange(processed.startIndex..., in: processed), withTemplate: "")
        } catch {
            print("Regex error (attachments): \(error)")
        }
        
        // 1. Handle Images
        // Replace <img src="..."> with [IMAGE:url] marker
        // Pattern: <img[^>]+src="([^">]+)"[^>]*>
        // Note: Discuz sometimes uses 'file="url"' or 'onload' attributes, but standard is src.
        // We will try to capture the src.
        do {
            let imgRegex = try NSRegularExpression(pattern: "<img[^>]+src=\"([^\">]+)\"[^>]*>", options: .caseInsensitive)
            let matches = imgRegex.matches(in: processed, range: NSRange(processed.startIndex..., in: processed))
            
            for match in matches.reversed() {
                if let srcRange = Range(match.range(at: 1), in: processed),
                   let fullMatchRange = Range(match.range, in: processed) {
                    let src = String(processed[srcRange])
                    
                    // Exclude smilies/emojis and UI images from being turned into big block images
                    if src.contains("smilies") || src.contains("images/default") || src.contains("images/common") || src.contains("common/back.gif") {
                         // Attempt to replace with a generic emoji if possible, or just remove to avoid giant block
                         // Ideally we map these, but for now removing avoids the UI bug.
                         processed.replaceSubrange(fullMatchRange, with: "")
                    } else {
                        let fullSrc = src.starts(with: "http") ? src : "\(baseURL)/\(src)"
                        processed.replaceSubrange(fullMatchRange, with: "\n[IMAGE:\(fullSrc)]\n")
                    }
                }
            }
        } catch {
            print("Regex error (images): \(error)")
        }
        
        // 2. Handle line breaks
        processed = processed.replacingOccurrences(of: "<br />", with: "\n")
        processed = processed.replacingOccurrences(of: "<br>", with: "\n")
        processed = processed.replacingOccurrences(of: "</p>", with: "\n\n")
        
        // 2.5. Extract links (<a href="...">) before stripping tags
        // Preserve as [LINK:url|title] so LinkedTextView can render titled links
        do {
            let linkRegex = try NSRegularExpression(
                pattern: "<a[^>]+href=\"([^\"]+)\"[^>]*>(.*?)</a>",
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
            let linkMatches = linkRegex.matches(in: processed, range: NSRange(processed.startIndex..., in: processed))
            
            for match in linkMatches.reversed() {
                if let hrefRange = Range(match.range(at: 1), in: processed),
                   let textRange = Range(match.range(at: 2), in: processed),
                   let fullRange = Range(match.range, in: processed) {
                    let href = String(processed[hrefRange])
                    let linkText = String(processed[textRange])
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if href.hasPrefix("#") || href.hasPrefix("javascript:") || href.contains("images/common") { continue }
                    
                    let title = linkText.isEmpty ? href : linkText
                    processed.replaceSubrange(fullRange, with: "[LINK:\(href)|\(title)]")
                }
            }
        } catch {
            print("Regex error (links): \(error)")
        }
        
        // 3. Strip remaining HTML tags
        processed = processed.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        
        // 4. Decode HTML Entities
        // Discuz/GBK often leaves entities like &#8203; (zero width space) or &amp;
        processed = processed
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#128515;", with: "😃") // Example emoji
            // Basic numeric entity decoder
        
        // specific entity fix for common ones
        processed = processed.replacingOccurrences(of: "&#8203;", with: "") // Zero width space
        
        // Generic Numeric Entity Decoder (Simple approach)
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);", options: []) {
            let matches = regex.matches(in: processed, range: NSRange(processed.startIndex..., in: processed))
            for match in matches.reversed() {
                if let r = Range(match.range(at: 1), in: processed),
                   let val = Int(String(processed[r])),
                   let scalar = UnicodeScalar(val),
                   let fullR = Range(match.range, in: processed) {
                    processed.replaceSubrange(fullR, with: String(scalar))
                }
            }
        }
        
        // 5. Collapse excessive whitespace/newlines
        // Replace 3+ consecutive newlines (or 2+ blank lines) with exactly 2 newlines (one blank line)
        // Also handle cases where spaces are between newlines
        if let newlineRegex = try? NSRegularExpression(pattern: "(\\s*\\n\\s*){3,}", options: []) {
            processed = newlineRegex.stringByReplacingMatches(in: processed, range: NSRange(processed.startIndex..., in: processed), withTemplate: "\n\n")
        }
        
        // Ensure 2 newlines don't have extra spaces between them
        if let blankLineRegex = try? NSRegularExpression(pattern: "\\n\\s+\\n", options: []) {
            processed = blankLineRegex.stringByReplacingMatches(in: processed, range: NSRange(processed.startIndex..., in: processed), withTemplate: "\n\n")
        }
        
        return processed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
