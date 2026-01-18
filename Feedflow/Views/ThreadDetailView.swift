import SwiftUI

struct ThreadDetailView: View {
    @StateObject private var viewModel: ThreadDetailViewModel
    @ObservedObject var localizationManager = LocalizationManager.shared
    @State private var replyText: String = ""
    @State private var showAISummary: Bool = false
    @State private var scrollRequest: UUID? = nil
    let service: ForumService
    
    init(thread: Thread, service: ForumService) {
        self.service = service
        _viewModel = StateObject(wrappedValue: ThreadDetailViewModel(thread: thread, service: service))
    }
    
    var body: some View {
        ZStack {
            Color.forumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // Header
                            HStack {
                                AvatarView(urlOrName: viewModel.thread.author.avatar, size: 40)
                                
                                VStack(alignment: .leading) {
                                    Text(viewModel.thread.author.username)
                                        .font(.headline)
                                        .foregroundColor(.forumTextPrimary)
                                    if let role = viewModel.thread.author.role {
                                        TagView(text: role)
                                    }
                                }
                                
                                Spacer()
                            }
                            .id("thread_top")
                            
                            // Content
                            Text(viewModel.thread.title)
                                .font(.title2)
                                .bold()
                                .foregroundColor(.forumTextPrimary)
                            
                            // Parsed Content (Text + Images)
                            ParsedContentView(text: viewModel.thread.content)
                            
                            // Tags
                            if let tags = viewModel.thread.tags, !tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(tags, id: \.self) { tag in
                                            TagView(text: tag)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                                .background(Color.forumTextSecondary.opacity(0.1))
                                .padding(.vertical, 8)
                            
                            if viewModel.isLoading && viewModel.comments.isEmpty {
                                ProgressView()
                                    .tint(.forumAccent)
                                    .scaleEffect(1.5)
                                    .padding()
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(viewModel.comments) { comment in
                                        CommentRow(comment: comment) {
                                            viewModel.selectCommentForReply(comment)
                                        }
                                            .onAppear {
                                                if comment.id == viewModel.comments.last?.id {
                                                    Task { await viewModel.loadMoreComments() }
                                                }
                                            }
                                        Divider()
                                            .background(Color.forumTextSecondary.opacity(0.1))
                                    }
                                    
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .id("loading_indicator")
                                            .padding()
                                    }
                                    
                                    Color.clear
                                        .frame(height: 1)
                                        .id("bottom_anchor")
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.comments) { _ in
                        if viewModel.shouldScrollAfterReply {
                            Task {
                                // Give SwiftUI a moment to render the new comment
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                                await MainActor.run {
                                    scrollToBottom(proxy: proxy)
                                    viewModel.shouldScrollAfterReply = false
                                }
                            }
                        }
                    }
                }
                
                if let replyingTo = viewModel.replyingTo {
                    HStack {
                        Text("\(LocalizationManager.shared.localizedString("replying_to")) \(replyingTo.author.username)")
                            .font(.caption)
                            .foregroundColor(.forumTextSecondary)
                        Spacer()
                        Button(action: {
                            viewModel.cancelReply()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .background(Color.forumBackground)
                }
                
                // Bottom Input
                VStack(spacing: 0) {
                    Divider().background(Color.forumTextSecondary.opacity(0.1))
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "photo")
                                .foregroundColor(.forumTextSecondary)
                        }
                        
                        TextField("thread_reply".localized(), text: $replyText)
                            .padding(10)
                            .background(Color.forumCard)
                            .cornerRadius(20)
                            .foregroundColor(.forumTextPrimary)
                        
                        Button(action: {
                            guard !replyText.isEmpty else { return }
                            let content = replyText
                            let feedback = UINotificationFeedbackGenerator()
                            feedback.prepare()
                            
                            Task {
                                do {
                                    try await viewModel.sendReply(content: content)
                                    
                                    // Reset UI 
                                    await MainActor.run {
                                        replyText = ""
                                        feedback.notificationOccurred(.success)
                                    }
                                } catch {
                                    print("Error posting reply: \(error)")
                                    await MainActor.run {
                                        feedback.notificationOccurred(.error)
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "paperplane.fill")
                            .foregroundColor(.forumAccent)
                        }
                    }
                    .padding()
                    .background(Color.forumBackground)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Content Source Indicator
                    Image(systemName: viewModel.isLatest ? "cloud.check.fill" : "internaldrive.fill")
                        .foregroundColor(viewModel.isLatest ? .green : .orange)
                        .font(.caption)
                        .help(viewModel.isLatest ? "Latest Content" : "Local Content")
                    
                    Button(action: {
                        viewModel.toggleBookmark()
                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                        feedback.impactOccurred()
                    }) {
                        Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.forumAccent)
                    }
                    
                    Button(action: {
                        showAISummary = true
                    }) {
                        Image(systemName: "sparkles") // AI Icon
                            .foregroundColor(.forumAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $showAISummary) {
            AISummaryView(threadId: viewModel.thread.id, content: aiSummaryContent)
        }
        .task {
            await viewModel.loadDetails()
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("bottom_anchor", anchor: .bottom)
        }
    }
    
    private var aiSummaryContent: String {
        // Collect full text content for all sites
        let commentsText = viewModel.comments.prefix(25).map { "\($0.author.username): \($0.content)" }.joined(separator: "\n")
        
        let targetLanguage = LocalizationManager.shared.currentLanguage == "zh" ? "Chinese (Simplified)" : "English"
        
        return """
        Context: The user is viewing a forum topic.
        Title: \(viewModel.thread.title)
        
        Original Thread Content:
        \(viewModel.thread.content)
        
        Comments/Replies (First 25):
        \(commentsText)
        
        Please provide a concise summary of the discussion based on the content above. The summary MUST be written in \(targetLanguage).
        """
    }
}

struct ParsedContentView: View {
    let text: String
    @State private var selectedImageURL: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseBlocks(from: text), id: \.self) { block in
                switch block {
                case .text(let content):
                    if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(content)
                            .font(.body)
                            .foregroundColor(.forumTextPrimary.opacity(0.9))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .image(let url):
                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 200)
                        case .success(let image):
                            image.resizable()
                                 .aspectRatio(contentMode: .fit)
                                 .cornerRadius(8)
                                 .onTapGesture(count: 2) {
                                     selectedImageURL = url
                                 }
                        case .failure:
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .fullScreenCover(item: Binding<ImageItem?>(
            get: { selectedImageURL.map { ImageItem(url: $0) } },
            set: { selectedImageURL = $0?.url }
        )) { item in
            FullScreenImageView(imageURL: item.url, isPresented: Binding(
                get: { selectedImageURL != nil },
                set: { if !$0 { selectedImageURL = nil } }
            ))
        }
    }
    
    struct ImageItem: Identifiable {
        let id = UUID()
        let url: String
    }
    
    enum ContentBlock: Hashable {
        case text(String)
        case image(String)
    }
    
    private func parseBlocks(from text: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let components = text.components(separatedBy: "[IMAGE:") // Primitive split
        
        for (index, component) in components.enumerated() {
            if index == 0 {
                // First part is always text (before the first image)
                let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    blocks.append(.text(trimmed))
                }
            } else {
                // Subsequent parts start with "url]" followed by text
                // Example: "http://.../img.jpg]\nSome text..."
                if let range = component.range(of: "]") {
                    let url = String(component[..<range.lowerBound])
                    let remainingText = String(component[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    blocks.append(.image(url))
                    if !remainingText.isEmpty {
                        blocks.append(.text(remainingText))
                    }
                } else {
                    // Fallback
                    let trimmed = ("[IMAGE:" + component).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        blocks.append(.text(trimmed))
                    }
                }
            }
        }
        return blocks
    }
}

struct TagView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.forumTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.forumCard)
            .cornerRadius(8)
    }
}

struct CommentRow: View {
    let comment: Comment
    let onReply: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(urlOrName: comment.author.avatar, size: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(comment.author.username)
                        .font(.footnote)
                        .bold()
                        .foregroundColor(.forumTextPrimary)
                    
                    if let role = comment.author.role {
                        TagView(text: role)
                    }
                    
                    Button(action: onReply) {
                        Text("reply".localized())
                            .font(.caption)
                            .foregroundColor(.forumAccent) // Accent color for link style
                    }
                    
                    Spacer()
                    
                    Text(comment.timeAgo)
                        .font(.caption)
                        .foregroundColor(.forumTextSecondary)
                }
                
                // Use ParsedContentView for comments too
                ParsedContentView(text: comment.content)
                
            }
        }
        .padding(.vertical, 12)
    }
}
