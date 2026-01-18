import Foundation

protocol ForumService {
    var name: String { get }
    var id: String { get } // Unique identifier for the service
    var logo: String { get } // SF Symbol name
    
    func fetchCategories() async throws -> [Community]
    func fetchCategoryThreads(categoryId: String, communities: [Community], page: Int) async throws -> [Thread]
    func fetchThreadDetail(threadId: String, page: Int) async throws -> (Thread, [Comment], Int?)
    func postComment(topicId: String, categoryId: String, content: String) async throws
    func createThread(categoryId: String, title: String, content: String) async throws
    func getWebURL(for thread: Thread) -> String
}

extension ForumService {
    // Default implementation optional or helper
    func getWebURL(for thread: Thread) -> String { return "" }
    
    // Maintain backward compatibility for existing callers (default page 1)
    func fetchCategoryThreads(categoryId: String, communities: [Community]) async throws -> [Thread] {
        return try await fetchCategoryThreads(categoryId: categoryId, communities: communities, page: 1)
    }
    
    func fetchThreadDetail(threadId: String) async throws -> (Thread, [Comment]) {
        let (thread, comments, _) = try await fetchThreadDetail(threadId: threadId, page: 1)
        return (thread, comments)
    }
}

extension ForumService {
    func calculateTimeAgo(from date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 {
            return "just now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h"
        } else {
            return "\(Int(diff / 86400))d"
        }
    }
    
    func calculateTimeAgo(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return calculateTimeAgo(from: date)
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return calculateTimeAgo(from: date)
        }
        
        return "now"
    }
}
