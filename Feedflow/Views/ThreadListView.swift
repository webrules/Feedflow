import SwiftUI

struct ThreadListView: View {
    @StateObject private var viewModel: ThreadListViewModel
    @EnvironmentObject var navigationManager: NavigationManager
    let community: Community
    let service: ForumService
    @State private var isInitialLoad = true
    @State private var showNewThread = false
    
    init(community: Community, service: ForumService) {
        self.community = community
        self.service = service
        _viewModel = StateObject(wrappedValue: ThreadListViewModel(service: service))
    }
    
    var body: some View {
        ZStack {
            Color.forumBackground.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.threads.isEmpty {
                ProgressView()
                    .tint(.forumAccent)
                    .scaleEffect(1.5)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                        }
                        .frame(height: 0)
                        
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.threads) { thread in
                                NavigationLink(destination: ThreadDetailView(thread: thread, service: service, contextThreads: viewModel.threads)) {
                                    ThreadRow(thread: thread)
                                        .onAppear {
                                            viewModel.prefetchThread(thread: thread)
                                            if thread == viewModel.threads.last {
                                                Task { await viewModel.loadMoreTopics(for: community) }
                                            }
                                        }
                                        .onDisappear {
                                            viewModel.cancelPrefetch(threadId: thread.id)
                                        }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .if(service is ZhihuService) { view in
                                    view.contextMenu {
                                        Button(role: .destructive) {
                                            Task {
                                                // Remove from UI immediately
                                                await MainActor.run {
                                                    withAnimation {
                                                        viewModel.removeThread(thread)
                                                    }
                                                }
                                                // Also send downvote API call if possible
                                                if let zhihuService = service as? ZhihuService,
                                                   let feedItem = zhihuService.getFeedItem(for: thread.id) {
                                                    await zhihuService.downvoteItem(feedItem: feedItem)
                                                }
                                            }
                                        } label: {
                                            Label("不感兴趣", systemImage: "hand.thumbsdown.fill")
                                        }
                                    }
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                        
                        if viewModel.isLoading && !viewModel.threads.isEmpty {
                            ProgressView()
                                .padding()
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        // User is at top if offset is close to 0 (within 50 points)
                        viewModel.updateScrollPosition(isAtTop: offset > -50)
                    }
                }
            }
        }
        .navigationTitle(community.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                 HStack(spacing: 16) {
                     Button(action: {
                        Task { await viewModel.loadTopics(for: community, isReturning: false) }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.forumAccent)
                    }
                    
                    Button(action: {
                        navigationManager.popToRoot()
                    }) {
                        Image(systemName: "house")
                            .foregroundColor(.forumAccent)
                    }
                 }
            }
        }
        .overlay(
            Button(action: {
                showNewThread = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.forumAccent)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding()
            , alignment: .bottomTrailing
        )
        .sheet(isPresented: $showNewThread) {
            NewThreadView(category: community, service: service)
        }
        .task {
            let isReturning = !isInitialLoad
            await viewModel.loadTopics(for: community, isReturning: isReturning)
            isInitialLoad = false
        }
    }
}

// Preference key for tracking scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ThreadRow: View {
    let thread: Thread
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if thread.community.category != "RSS" {
                HStack(spacing: 6) {
                    AvatarView(urlOrName: thread.author.avatar, size: 16)
                    
                    Text("@\(thread.author.username)")
                        .foregroundColor(.forumTextSecondary)
                    
                    Text("• \(thread.timeAgo)")
                        .foregroundColor(.forumTextSecondary)
                    Spacer()
                    
                    // Show Zhihu content type tags
                    if thread.community.category == "zhihu", let tags = thread.tags, !tags.isEmpty {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(zhihuTagColor(tag).opacity(0.15))
                                .foregroundColor(zhihuTagColor(tag))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Show vote count for Zhihu
                    if thread.community.category == "zhihu" && thread.likeCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "hand.thumbsup.fill")
                            Text("\(thread.likeCount)")
                        }
                        .font(.caption2)
                        .foregroundColor(.forumTextSecondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        Text("\(thread.commentCount)")
                    }
                }
                .font(.caption)
                .foregroundColor(.forumTextSecondary)
            }
            
            Text(thread.title)
                .font(.headline)
                .foregroundColor(.forumTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Show excerpt for Zhihu content
            if thread.community.category == "zhihu" && !thread.content.isEmpty {
                Text(thread.content)
                    .font(.subheadline)
                    .foregroundColor(.forumTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.forumBackground)
    }
    
    private func zhihuTagColor(_ tag: String) -> Color {
        switch tag {
        case "回答": return .blue
        case "文章": return .green
        case "问题": return .orange
        case "视频": return .purple
        case "想法": return .pink
        default: return .gray
        }
    }
}
