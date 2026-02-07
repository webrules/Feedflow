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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.forumBackground)
    }
}
