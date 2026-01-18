import Foundation
import SwiftUI
import Combine

class NewThreadViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var isPosting: Bool = false
    @Published var error: Error?
    
    let category: Community
    let service: ForumService
    
    init(category: Community, service: ForumService) {
        self.category = category
        self.service = service
    }
    
    func postThread() async throws {
        guard !title.isEmpty && !content.isEmpty else { return }
        
        await MainActor.run { isPosting = true; error = nil }
        
        do {
            try await service.createThread(categoryId: category.id, title: title, content: content)
            await MainActor.run { isPosting = false }
        } catch {
            await MainActor.run { 
                self.isPosting = false
                self.error = error
            }
            throw error
        }
    }
}
