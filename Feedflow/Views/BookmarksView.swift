import SwiftUI

struct BookmarksView: View {
    @StateObject private var viewModel = BookmarksViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.forumBackground.ignoresSafeArea()
                
                if viewModel.bookmarkedThreads.isEmpty {
                    VStack {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 64))
                            .foregroundColor(.forumTextSecondary.opacity(0.5))
                        Text("No bookmarks yet")
                            .font(.headline)
                            .foregroundColor(.forumTextSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.bookmarkedThreads, id: \.0.id) { thread, serviceId in
                                NavigationLink(destination: ThreadDetailView(thread: thread, service: viewModel.getService(for: serviceId))) {
                                    BookmarkRow(thread: thread, serviceName: viewModel.getService(for: serviceId).name)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.forumAccent)
                }
            }
            .onAppear {
                viewModel.loadBookmarks()
            }
        }
    }
}

struct BookmarkRow: View {
    let thread: Thread
    let serviceName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(serviceName)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.forumAccent.opacity(0.1))
                    .foregroundColor(.forumAccent)
                    .cornerRadius(4)
                
                Spacer()
                
                Text(thread.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.forumTextSecondary)
            }
            
            Text(thread.title)
                .font(.headline)
                .foregroundColor(.forumTextPrimary)
                .lineLimit(2)
            
            HStack {
                AvatarView(urlOrName: thread.author.avatar, size: 20)
                Text(thread.author.username)
                    .font(.caption)
                    .foregroundColor(.forumTextSecondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Label("\(thread.likeCount)", systemImage: "hand.thumbsup.fill")
                    Label("\(thread.commentCount)", systemImage: "bubble.right.fill")
                }
                .font(.caption2)
                .foregroundColor(.forumTextSecondary)
            }
        }
        .padding()
        .background(Color.forumCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}
