import SwiftUI

struct HomeAISummaryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = HomeAISummaryViewModel()
    @ObservedObject var localizationManager = LocalizationManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color.forumBackground.ignoresSafeArea()

                if viewModel.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.forumAccent)

                        Text("fetching_posts".localized())
                            .foregroundColor(.forumTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding()

                        if viewModel.articlesFound > 0 {
                            Text(LocalizationManager.shared.localizedString("found_posts", viewModel.articlesFound))
                                .font(.caption)
                                .foregroundColor(.forumTextSecondary)
                        }
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("error".localized())
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.forumTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding()

                        Button("try_again".localized()) {
                            Task { await viewModel.generateSummary(forceRefresh: true) }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if !viewModel.hnThreads.isEmpty || !viewModel.v2exThreads.isEmpty || !viewModel.fourD4YThreads.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // AI Summary Section - Show loading or content
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("main_themes".localized())
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.forumAccent)
                                    Spacer()
                                    if viewModel.isCached {
                                        Text("cached".localized())
                                            .font(.caption)
                                            .foregroundColor(.forumTextSecondary)
                                            .padding(6)
                                            .background(Color.forumCard)
                                            .cornerRadius(6)
                                    }
                                }

                                if viewModel.isGeneratingSummary {
                                    // Show loading indicator for AI summary
                                    HStack(spacing: 12) {
                                        ProgressView()
                                            .tint(.forumAccent)
                                        Text("generating_summary".localized())
                                            .font(.body)
                                            .foregroundColor(.forumTextSecondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                                    .background(Color.forumCard)
                                    .cornerRadius(12)
                                } else if !viewModel.summary.isEmpty {
                                    // Show AI summary
                                    Text(LocalizedStringKey(viewModel.summary))
                                        .font(.body)
                                        .foregroundColor(.forumTextPrimary)
                                        .lineSpacing(6)
                                        .textSelection(.enabled)
                                        .padding()
                                        .background(Color.forumCard)
                                        .cornerRadius(12)
                                }
                            }

                            Divider()
                                .padding(.vertical, 8)

                            // Collapsible Thread Sections
                            CollapsibleThreadSection(
                                title: "hacker_news_best".localized(),
                                icon: "flame.fill",
                                threads: viewModel.hnThreads,
                                serviceId: "hackernews"
                            )

                            CollapsibleThreadSection(
                                title: "v2ex_hot".localized(),
                                icon: "bolt.fill",
                                threads: viewModel.v2exThreads,
                                serviceId: "v2ex"
                            )

                            CollapsibleThreadSection(
                                title: "4d4y_active".localized(),
                                icon: "clock.fill",
                                threads: viewModel.fourD4YThreads,
                                serviceId: "4d4y"
                            )
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("no_summary".localized())
                            .foregroundColor(.forumTextSecondary)

                        Button("generate_daily_summary".localized()) {
                            Task { await viewModel.generateSummary() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.forumAccent)
                    }
                }
            }
            .navigationTitle("home_ai_summary".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.forumTextSecondary)
                            .font(.system(size: 20))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await viewModel.generateSummary(forceRefresh: true) }
                    }) {
                        Label("force_refresh".localized(), systemImage: "arrow.clockwise")
                            .foregroundColor(.forumAccent)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                if viewModel.summary.isEmpty && !viewModel.isLoading {
                    await viewModel.generateSummary()
                }
            }
        }
    }
}

// MARK: - Thread Row Component

struct ThreadRowView: View {
    let thread: Thread
    let index: Int
    let serviceId: String

    private func makeService() -> ForumService {
        switch serviceId {
        case "hackernews": return HackerNewsService()
        case "v2ex": return V2EXService()
        case "4d4y": return FourD4YService()
        default: return HackerNewsService()
        }
    }

    var body: some View {
        NavigationLink(destination: ThreadDetailView(thread: thread, service: makeService())) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(index + 1).")
                    .font(.caption)
                    .foregroundColor(.forumTextSecondary)
                    .frame(width: 20, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(thread.title)
                        .font(.subheadline)
                        .foregroundColor(.forumTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 12) {
                        if !thread.author.username.isEmpty {
                            Label(thread.author.username, systemImage: "person.fill")
                                .font(.caption2)
                                .foregroundColor(.forumTextSecondary)
                        }

                        Label("\(thread.commentCount)", systemImage: "bubble.left.fill")
                            .font(.caption2)
                            .foregroundColor(.forumTextSecondary)

                        if thread.likeCount > 0 {
                            Label("\(thread.likeCount)", systemImage: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.forumTextSecondary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Collapsible Thread Section Component

struct CollapsibleThreadSection: View {
    let title: String
    let icon: String
    let threads: [Thread]
    let serviceId: String

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header button to toggle expansion
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.forumAccent)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.forumTextPrimary)
                    Text("(\(threads.count))")
                        .font(.subheadline)
                        .foregroundColor(.forumTextSecondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.forumTextSecondary)
                }
                .padding(.vertical, 8)
            }

            // Expandable list of top 10 threads
            if isExpanded {
                let topThreads = Array(threads.prefix(10))
                ForEach(Array(topThreads.enumerated()), id: \.element.id) { index, thread in
                    ThreadRowView(
                        thread: thread,
                        index: index,
                        serviceId: serviceId
                    )

                    if index < topThreads.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color.forumCard)
        .cornerRadius(12)
    }
}
