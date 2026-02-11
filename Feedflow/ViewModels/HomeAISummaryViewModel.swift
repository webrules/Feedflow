import Foundation
import SwiftUI
import Combine

class HomeAISummaryViewModel: ObservableObject {
    private let geminiService = GeminiService()
    private let cacheKey = "home_ai_summary"
    private let cacheMaxAge: TimeInterval = 8 * 60 * 60 // 8 hours

    @Published var summary: String = ""
    @Published var isLoading: Bool = false
    @Published var isGeneratingSummary: Bool = false
    @Published var isCached: Bool = false
    @Published var errorMessage: String? = nil
    @Published var articlesFound: Int = 0

    @Published var hnThreads: [Thread] = []
    @Published var v2exThreads: [Thread] = []
    @Published var fourD4YThreads: [Thread] = []

    @MainActor
    func generateSummary(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        summary = ""
        isCached = false
        isGeneratingSummary = false
        articlesFound = 0

        // Check cache first (unless forcing refresh)
        if !forceRefresh,
           let cached = DatabaseManager.shared.getSummaryIfFresh(threadId: cacheKey, maxAgeSeconds: cacheMaxAge) {
            self.summary = cached
            self.isCached = true
            self.isLoading = false

            // Still fetch threads for display, but don't wait
            Task { await fetchThreadsOnly() }
            return
        }

        // Fetch from all 3 sources in parallel
        await fetchAllSources()

        // Show threads immediately - don't wait for AI
        isLoading = false

        if hnThreads.isEmpty && v2exThreads.isEmpty && fourD4YThreads.isEmpty {
            summary = "no_updates_24h".localized()
            return
        }

        // Generate AI summary in background
        isGeneratingSummary = true
        Task {
            let prompt = buildGeminiPrompt()

            do {
                let result = try await geminiService.generateSummary(for: prompt)
                await MainActor.run {
                    self.summary = result
                    self.isGeneratingSummary = false

                    // Save to cache
                    DatabaseManager.shared.saveSummary(threadId: cacheKey, summary: result)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to generate summary: \(error.localizedDescription)"
                    self.isGeneratingSummary = false
                }
            }
        }
    }

    /// Fetches threads from all sources in parallel
    private func fetchAllSources() async {
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Hacker News Best
            group.addTask {
                do {
                    let service = HackerNewsService()
                    let threads = try await service.fetchCategoryThreads(categoryId: "beststories", communities: [], page: 1)
                    await MainActor.run {
                        self.hnThreads = Array(threads.prefix(10))
                        self.articlesFound += self.hnThreads.count
                        print("[HomeAISummary] Hacker News: \(self.hnThreads.count) threads")
                    }
                } catch {
                    print("[HomeAISummary] HN fetch failed: \(error)")
                }
            }

            // Task 2: V2EX Hot
            group.addTask {
                do {
                    let service = V2EXService()
                    let threads = try await service.fetchCategoryThreads(categoryId: "hot", communities: [], page: 1)
                    await MainActor.run {
                        self.v2exThreads = Array(threads.prefix(10))
                        self.articlesFound += self.v2exThreads.count
                        print("[HomeAISummary] V2EX: \(self.v2exThreads.count) threads")
                    }
                } catch {
                    print("[HomeAISummary] V2EX fetch failed: \(error)")
                }
            }

            // Task 3: 4D4Y Active (24h) - fetch all and sort by reply count
            group.addTask {
                do {
                    let service = FourD4YService()
                    let threads = try await service.fetchLastPostThreads(maxPages: 10)
                    // Sort by reply count (most popular first) and take top 10
                    let sortedThreads = threads.sorted { $0.commentCount > $1.commentCount }
                    await MainActor.run {
                        self.fourD4YThreads = Array(sortedThreads.prefix(10))
                        self.articlesFound += self.fourD4YThreads.count
                        print("[HomeAISummary] 4D4Y: \(self.fourD4YThreads.count) threads (sorted by replies)")
                    }
                } catch {
                    print("[HomeAISummary] 4D4Y fetch failed: \(error)")
                }
            }

            await group.waitForAll()
        }
    }

    /// Fetches threads only (for cached summary display)
    private func fetchThreadsOnly() async {
        await fetchAllSources()
    }

    /// Builds language-aware Gemini prompt based on current language setting
    private func buildGeminiPrompt() -> String {
        let language = LocalizationManager.shared.currentLanguage
        let isEnglish = language == "en"

        var prompt = ""

        if isEnglish {
            prompt = """
            You are a tech news summarizer. Below are top posts from three communities:
            1. Hacker News /best - Curated best stories
            2. V2EX /hot - Hot Chinese tech discussions
            3. 4D4Y - Active forum threads (24h)

            Please provide Top 5 most interesting items with explanations, add nothing before or after it, keep this section only

            Format the output clearly with Markdown headers.

            """
        } else {
            prompt = """
            你是科技新闻总结助手。以下是三个社区的热门帖子:
            1. Hacker News /best - 精选最佳故事
            2. V2EX /hot - 热门技术讨论
            3. 4D4Y - 活跃论坛讨论（24小时）

            请提供最有趣的5个项目及说明，之前之后不要添加额外的内容

            使用 Markdown 标题清晰格式化输出。

            """
        }

        // Add Hacker News threads
        if !hnThreads.isEmpty {
            prompt += isEnglish ? "\n## Hacker News Best\n\n" : "\n## Hacker News 精选\n\n"
            for (index, thread) in hnThreads.prefix(10).enumerated() {
                let snippet = thread.content.prefix(200).replacingOccurrences(of: "\n", with: " ")
                prompt += "\(index + 1). **\(thread.title)**\n"
                if !snippet.isEmpty {
                    prompt += "   Snippet: \(snippet)...\n"
                }
                prompt += "   Comments: \(thread.commentCount)\n\n"
            }
        }

        // Add V2EX threads
        if !v2exThreads.isEmpty {
            prompt += isEnglish ? "\n## V2EX Hot\n\n" : "\n## V2EX 热门\n\n"
            for (index, thread) in v2exThreads.prefix(10).enumerated() {
                let snippet = thread.content.prefix(200).replacingOccurrences(of: "\n", with: " ")
                prompt += "\(index + 1). **\(thread.title)**\n"
                if !snippet.isEmpty {
                    prompt += "   Snippet: \(snippet)...\n"
                }
                prompt += "   Replies: \(thread.commentCount)\n\n"
            }
        }

        // Add 4D4Y threads
        if !fourD4YThreads.isEmpty {
            prompt += isEnglish ? "\n## 4D4Y Active (24h)\n\n" : "\n## 4D4Y 活跃（24小时）\n\n"
            for (index, thread) in fourD4YThreads.prefix(10).enumerated() {
                let snippet = thread.content.prefix(200).replacingOccurrences(of: "\n", with: " ")
                prompt += "\(index + 1). **\(thread.title)**\n"
                prompt += "   Author: \(thread.author.username)\n"
                if !snippet.isEmpty && snippet.count > 10 {
                    prompt += "   Snippet: \(snippet)...\n"
                }
                prompt += "   Replies: \(thread.commentCount)\n\n"
            }
        }

        return prompt
    }
}
