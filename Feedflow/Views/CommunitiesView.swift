import SwiftUI

struct CommunitiesView: View {
    @StateObject private var viewModel: ForumViewModel
    let service: ForumService
    
    init(service: ForumService) {
        self.service = service
        _viewModel = StateObject(wrappedValue: ForumViewModel(service: service))
    }
    
    var body: some View {
        ZStack {
            Color.forumBackground.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.communities.isEmpty {
                ProgressView()
                    .tint(.forumAccent)
                    .scaleEffect(1.5)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // All Categories
                        VStack(alignment: .leading, spacing: 16) {
                            
                            ForEach(viewModel.communities) { community in
                                NavigationLink(value: community) {
                                    CommunityRow(community: community)
                                }
                            }
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .navigationTitle(service.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.forumBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.refresh()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.forumTextPrimary)
                }
            }
        }
        .navigationDestination(for: Community.self) { community in
            ThreadListView(community: community, service: service)
        }
    }
}

struct CommunityRow: View {
    let community: Community
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text(community.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.forumTextPrimary)
                
                Spacer()
            }
            
            if !community.description.isEmpty {
                Text(community.description)
                    .font(.system(size: 14))
                    .foregroundColor(.forumTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(Color.forumBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.forumTextSecondary.opacity(0.1)),
            alignment: .bottom
        )
    }
}
