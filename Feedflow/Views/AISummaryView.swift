import SwiftUI

struct AISummaryView: View {
    let threadId: String
    let content: String
    @Environment(\.dismiss) var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared
    @StateObject private var speechService = SpeechService.shared
    @State private var summary: String = ""
    @State private var isLoading: Bool = true
    @State private var hasError: Bool = false
    @State private var isCached: Bool = false
    
    // In a real app, inject this or manage lifecycle better
    private let geminiService = GeminiService()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.forumBackground.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.forumAccent)
                            Text("gemini_analyzing".localized())
                                .foregroundColor(.forumTextSecondary)
                        }
                    } else if hasError {
                         VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("failed_summary".localized())
                                .foregroundColor(.forumTextSecondary)
                            Text("check_api_key".localized())
                                .font(.caption)
                                .foregroundColor(.forumTextSecondary)
                             
                            Button("try_again".localized()) {
                                Task { await generateSummary(forceRefresh: true) }
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("gemini_summary".localized())
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.forumAccent)
                                    
                                    Spacer()
                                    
                                    if isCached {
                                        Text("cached".localized())
                                            .font(.caption)
                                            .foregroundColor(.forumTextSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.forumCard)
                                            .cornerRadius(6)
                                    }
                                }
                                
                                Text(summary)
                                    .font(.body)
                                    .foregroundColor(.forumTextPrimary)
                                    .lineSpacing(6)
                                    .textSelection(.enabled)
                                
                                Divider()
                                    .background(Color.forumTextSecondary.opacity(0.3))
                                    .padding(.vertical)
                                
                                HStack {
                                    Text("generated_by".localized())
                                        .font(.caption)
                                        .foregroundColor(.forumTextSecondary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        Task { await generateSummary(forceRefresh: true) }
                                    }) {
                                        Label("regenerate".localized(), systemImage: "arrow.clockwise")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("ai_assistant".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        speechService.speak(summary, language: localizationManager.currentLanguage)
                    }) {
                        Image(systemName: speechService.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .foregroundColor(.forumAccent)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        speechService.stop()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.forumTextSecondary)
                            .font(.system(size: 20))
                    }
                }
            }
            .task {
                await generateSummary(forceRefresh: false)
            }
        }
    }
    
    private func generateSummary(forceRefresh: Bool) async {
        isLoading = true
        hasError = false
        isCached = false
        
        // Check cache first if not forcing refresh
        if !forceRefresh, let cached = DatabaseManager.shared.getSummary(threadId: threadId) {
            await MainActor.run {
                self.summary = cached
                self.isCached = true
                self.isLoading = false
            }
            return
        }
        
        do {
            let result = try await geminiService.generateSummary(for: content)
            
            // Save to database
            DatabaseManager.shared.saveSummary(threadId: threadId, summary: result)
            
            await MainActor.run {
                self.summary = result
                self.isCached = false
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.hasError = true
                self.isLoading = false
            }
        }
    }
}
