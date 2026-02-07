import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    
    private init() {
        openDatabase()
        createTables()
        createSettingsTable()
        createSummariesTable()
        createCacheTables()
        createBookmarksTable()
    }
    
    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("Feedflow.sqlite")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }
    
    private func createTables() {
        let createTableString = """
        CREATE TABLE IF NOT EXISTS communities(
            id TEXT,
            name TEXT,
            description TEXT,
            category TEXT,
            activeToday INTEGER,
            onlineNow INTEGER,
            serviceId TEXT,
            PRIMARY KEY (id, serviceId)
        );
        """
        
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                // print("Communities table created.")
            } else {
                print("Communities table could not be created.")
            }
        } else {
            print("CREATE TABLE statement could not be prepared.")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    func saveCommunities(_ communities: [Community], forService serviceId: String) {
        // Use a transaction for performance
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        
        let insertStatementString = "INSERT OR REPLACE INTO communities (id, name, description, category, activeToday, onlineNow, serviceId) VALUES (?, ?, ?, ?, ?, ?, ?);"
        var insertStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            for community in communities {
                sqlite3_bind_text(insertStatement, 1, (community.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 2, (community.name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 3, (community.description as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 4, (community.category as NSString).utf8String, -1, nil)
                sqlite3_bind_int(insertStatement, 5, Int32(community.activeToday))
                sqlite3_bind_int(insertStatement, 6, Int32(community.onlineNow))
                sqlite3_bind_text(insertStatement, 7, (serviceId as NSString).utf8String, -1, nil)
                
                if sqlite3_step(insertStatement) != SQLITE_DONE {
                    print("Could not insert row.")
                }
                sqlite3_reset(insertStatement)
            }
        } else {
            print("INSERT statement could not be prepared.")
        }
        sqlite3_finalize(insertStatement)
        sqlite3_exec(db, "COMMIT TRANSACTION", nil, nil, nil)
    }
    
    func getCommunities(forService serviceId: String) -> [Community] {
        let queryStatementString = "SELECT id, name, description, category, activeToday, onlineNow FROM communities WHERE serviceId = ?;"
        var queryStatement: OpaquePointer?
        var communities: [Community] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (serviceId as NSString).utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(queryStatement, 0))
                let name = String(cString: sqlite3_column_text(queryStatement, 1))
                let description = String(cString: sqlite3_column_text(queryStatement, 2))
                let category = String(cString: sqlite3_column_text(queryStatement, 3))
                let activeToday = Int(sqlite3_column_int(queryStatement, 4))
                let onlineNow = Int(sqlite3_column_int(queryStatement, 5))
                
                communities.append(Community(
                    id: id,
                    name: name,
                    description: description,
                    category: category,
                    activeToday: activeToday,
                    onlineNow: onlineNow
                ))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        return communities
    }
    
    // MARK: - Settings
    
    private func createSettingsTable() {
        let createTableString = """
        CREATE TABLE IF NOT EXISTS settings(
            key TEXT PRIMARY KEY,
            value TEXT
        );
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                // print("Settings table created.")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func saveSetting(key: String, value: String) {
        let sql = "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (value as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error saving setting: \(key)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func getSetting(key: String) -> String? {
        let sql = "SELECT value FROM settings WHERE key = ?;"
        var statement: OpaquePointer?
        var result: String?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                if let val = sqlite3_column_text(statement, 0) {
                    result = String(cString: val)
                }
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    // MARK: - Cookie Storage (encrypted)
    func saveCookies(siteId: String, cookies: [HTTPCookie]) {
        // Load existing cookies first to merge
        var currentCookies = getCookies(siteId: siteId) ?? []
        
        for newCookie in cookies {
            // Replace existing cookie with same name/domain/path
            if let index = currentCookies.firstIndex(where: { 
                $0.name == newCookie.name && $0.domain == newCookie.domain && $0.path == newCookie.path 
            }) {
                currentCookies[index] = newCookie
            } else {
                currentCookies.append(newCookie)
            }
        }
        
        // Encode cookies to a simple dictionary array
        let cookieDicts = currentCookies.map { cookie -> [String: Any] in
            var dict: [String: Any] = [
                "name": cookie.name,
                "value": cookie.value,
                "domain": cookie.domain,
                "path": cookie.path,
                "secure": cookie.isSecure,
                "httpOnly": cookie.isHTTPOnly
            ]
            if let expires = cookie.expiresDate {
                dict["expires"] = expires.timeIntervalSince1970
            }
            return dict
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: cookieDicts, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let encrypted = EncryptionHelper.shared.encrypt(jsonString) {
            saveSetting(key: "login_\(siteId)_cookies", value: encrypted)
        }
    }
    
    func getCookies(siteId: String) -> [HTTPCookie]? {
        guard let encrypted = getSetting(key: "login_\(siteId)_cookies"),
              let jsonString = EncryptionHelper.shared.decrypt(encrypted),
              let jsonData = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] else {
            return nil
        }
        var cookies: [HTTPCookie] = []
        for dict in array {
            var properties: [HTTPCookiePropertyKey: Any] = [:]
            if let name = dict["name"] as? String { properties[.name] = name }
            if let value = dict["value"] as? String { properties[.value] = value }
            if let domain = dict["domain"] as? String { properties[.domain] = domain }
            if let path = dict["path"] as? String { properties[.path] = path }
            if let secure = dict["secure"] as? Bool { properties[.secure] = secure }
            if let httpOnly = dict["httpOnly"] as? Bool { properties[.init("HttpOnly")] = httpOnly }
            if let expires = dict["expires"] as? TimeInterval {
                properties[.expires] = Date(timeIntervalSince1970: expires)
            }
            if let cookie = HTTPCookie(properties: properties) {
                // Only return cookies that haven't expired
                if let expires = cookie.expiresDate, expires < Date() {
                    continue
                }
                cookies.append(cookie)
            }
        }
        return cookies
    }
    
    // MARK: - AI Summaries
    
    private func createSummariesTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS ai_summaries(
            thread_id TEXT PRIMARY KEY,
            summary TEXT,
            created_at INTEGER
        );
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func saveSummary(threadId: String, summary: String) {
        let sql = "INSERT OR REPLACE INTO ai_summaries (thread_id, summary, created_at) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (threadId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (summary as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(statement, 3, Int64(Date().timeIntervalSince1970))
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error saving summary for thread: \(threadId)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func getSummary(threadId: String) -> String? {
        let sql = "SELECT summary FROM ai_summaries WHERE thread_id = ?;"
        var statement: OpaquePointer?
        var result: String?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (threadId as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                if let val = sqlite3_column_text(statement, 0) {
                    result = String(cString: val)
                }
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    /// Returns cached summary only if it was created within `maxAgeSeconds` ago.
    func getSummaryIfFresh(threadId: String, maxAgeSeconds: TimeInterval) -> String? {
        let sql = "SELECT summary, created_at FROM ai_summaries WHERE thread_id = ?;"
        var statement: OpaquePointer?
        var result: String?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (threadId as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                if let val = sqlite3_column_text(statement, 0) {
                    let createdAt = TimeInterval(sqlite3_column_int64(statement, 1))
                    let age = Date().timeIntervalSince1970 - createdAt
                    if age < maxAgeSeconds {
                        result = String(cString: val)
                    }
                }
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    // MARK: - Content Caching
    
    private func createCacheTables() {
        // Table for cached topics (thread lists per community)
        let topicsTable = """
        CREATE TABLE IF NOT EXISTS cached_topics(
            cache_key TEXT PRIMARY KEY,
            data TEXT,
            timestamp INTEGER
        );
        """
        
        // Table for cached thread details
        let threadsTable = """
        CREATE TABLE IF NOT EXISTS cached_threads(
            thread_id TEXT PRIMARY KEY,
            data TEXT,
            timestamp INTEGER
        );
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, topicsTable, -1, &statement, nil) == SQLITE_OK {
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        
        if sqlite3_prepare_v2(db, threadsTable, -1, &statement, nil) == SQLITE_OK {
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func saveCachedTopics(cacheKey: String, topics: [Thread]) {
        guard let jsonData = try? JSONEncoder().encode(topics),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let sql = "INSERT OR REPLACE INTO cached_topics (cache_key, data, timestamp) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (cacheKey as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (jsonString as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(statement, 3, Int64(Date().timeIntervalSince1970))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func getCachedTopics(cacheKey: String) -> [Thread]? {
        let sql = "SELECT data FROM cached_topics WHERE cache_key = ?;"
        var statement: OpaquePointer?
        var result: [Thread]?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (cacheKey as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                if let jsonStringPtr = sqlite3_column_text(statement, 0) {
                    let jsonString = String(cString: jsonStringPtr)
                    if let jsonData = jsonString.data(using: .utf8) {
                        do {
                            result = try JSONDecoder().decode([Thread].self, from: jsonData)
                            // print("[DatabaseManager] Successfully loaded \(result?.count ?? 0) cached topics for \(cacheKey)")
                        } catch {
                            print("[DatabaseManager] Failed to decode cached topics for \(cacheKey): \(error)")
                        }
                    }
                }
            }
        } else {
            print("[DatabaseManager] SELECT statement could not be prepared for cached_topics")
        }
        sqlite3_finalize(statement)
        return result
    }
    
    func saveCachedThread(threadId: String, thread: Thread, comments: [Comment]) {
        let cacheData = ThreadDetailCache(thread: thread, comments: comments)
        guard let jsonData = try? JSONEncoder().encode(cacheData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let sql = "INSERT OR REPLACE INTO cached_threads (thread_id, data, timestamp) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (threadId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (jsonString as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(statement, 3, Int64(Date().timeIntervalSince1970))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func getCachedThread(threadId: String) -> (Thread, [Comment])? {
        let sql = "SELECT data FROM cached_threads WHERE thread_id = ?;"
        var statement: OpaquePointer?
        var result: (Thread, [Comment])?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (threadId as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW,
               let jsonString = sqlite3_column_text(statement, 0),
               let jsonData = String(cString: jsonString).data(using: .utf8),
               let cache = try? JSONDecoder().decode(ThreadDetailCache.self, from: jsonData) {
                result = (cache.thread, cache.comments)
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    private func createBookmarksTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS bookmarks(
            thread_id TEXT,
            service_id TEXT,
            data TEXT,
            timestamp INTEGER,
            PRIMARY KEY (thread_id, service_id)
        );
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func toggleBookmark(thread: Thread, serviceId: String) {
        if isBookmarked(threadId: thread.id, serviceId: serviceId) {
            let sql = "DELETE FROM bookmarks WHERE thread_id = ? AND service_id = ?;"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (thread.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (serviceId as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        } else {
            guard let jsonData = try? JSONEncoder().encode(thread),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            
            let sql = "INSERT INTO bookmarks (thread_id, service_id, data, timestamp) VALUES (?, ?, ?, ?);"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (thread.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (serviceId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (jsonString as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(statement, 4, Int64(Date().timeIntervalSince1970))
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }
    
    func isBookmarked(threadId: String, serviceId: String) -> Bool {
        let sql = "SELECT 1 FROM bookmarks WHERE thread_id = ? AND service_id = ?;"
        var statement: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (threadId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (serviceId as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                exists = true
            }
        }
        sqlite3_finalize(statement)
        return exists
    }
    
    func getBookmarkedThreads() -> [(Thread, String)] {
        let sql = "SELECT data, service_id FROM bookmarks ORDER BY timestamp DESC;"
        var statement: OpaquePointer?
        var results: [(Thread, String)] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let jsonString = sqlite3_column_text(statement, 0),
                   let serviceIdPtr = sqlite3_column_text(statement, 1) {
                    let jsonData = String(cString: jsonString).data(using: .utf8)!
                    let serviceId = String(cString: serviceIdPtr)
                    if let thread = try? JSONDecoder().decode(Thread.self, from: jsonData) {
                        results.append((thread, serviceId))
                    }
                }
            }
        }
        sqlite3_finalize(statement)
        return results
    }
}

// Helper struct for caching thread details
struct ThreadDetailCache: Codable {
    let thread: Thread
    let comments: [Comment]
}
