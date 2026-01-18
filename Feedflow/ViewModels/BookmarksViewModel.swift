import Foundation
import SwiftUI
import Combine

@MainActor
class BookmarksViewModel: ObservableObject {
    @Published var bookmarkedThreads: [(Thread, String)] = []
    
    func loadBookmarks() {
        bookmarkedThreads = DatabaseManager.shared.getBookmarkedThreads()
    }
    
    func getService(for id: String) -> ForumService {
        switch id {
        case "4d4y": return FourD4YService()
        case "linux_do": return DiscourseService()
        case "hackernews": return HackerNewsService()
        default: return FourD4YService() // Fallback
        }
    }
}
