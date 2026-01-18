import SwiftUI

struct NewThreadView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: NewThreadViewModel
    @ObservedObject var localizationManager = LocalizationManager.shared
    
    init(category: Community, service: ForumService) {
        _viewModel = StateObject(wrappedValue: NewThreadViewModel(category: category, service: service))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.forumBackground.ignoresSafeArea()
                
                VStack(alignment: .leading) {
                    if viewModel.isPosting {
                        LinearProgressView()
                    }
                    
                    // Inputs
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("thread_title".localized(), text: $viewModel.title)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.vertical)
                            .submitLabel(.next)
                        
                        ZStack(alignment: .topLeading) {
                            if viewModel.content.isEmpty {
                                Text("share_thoughts".localized())
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                            }
                            TextEditor(text: $viewModel.content)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .foregroundColor(.white)
                                .font(.body)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Attachments (Placeholder)
                    VStack(alignment: .leading) {
                        HStack {
                            Text("attachments_header".localized())
                                .font(.caption)
                                .bold()
                                .foregroundColor(.forumTextSecondary)
                            Spacer()
                            Button(action: {}) {
                                Label("add_images".localized(), systemImage: "camera.fill")
                                    .font(.caption)
                                    .foregroundColor(.forumAccent)
                            }
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<3) { index in
                                    ZStack(alignment: .topTrailing) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.forumCard)
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                            )
                                        
                                        Button(action: {}) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                                .background(Circle().fill(Color.black))
                                        }
                                        .offset(x: 5, y: -5)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                    
                    // Toolbar at bottom
                    HStack(spacing: 24) {
                        Button(action: {}) { Image(systemName: "bold") }
                        Button(action: {}) { Image(systemName: "italic") }
                        Button(action: {}) { Image(systemName: "link") }
                        Button(action: {}) { Image(systemName: "list.bullet") }
                        
                        Spacer()
                        
                        Text(LocalizationManager.shared.localizedString("word_count", viewModel.content.count))
                            .font(.caption)
                            .foregroundColor(.forumTextSecondary)
                    }
                    .foregroundColor(.forumTextSecondary)
                    .padding()
                    .background(Color.forumCard)
                }
            }
            .navigationTitle("new_thread".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized()) { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            do {
                                try await viewModel.postThread()
                                dismiss()
                            } catch {
                                // Error handled by VM state or just printed
                                print("Post error: \(error)")
                            }
                        }
                    }) {
                        Text("thread_button".localized())
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewModel.title.isEmpty || viewModel.content.isEmpty ? Color.gray : Color.forumAccent)
                            .cornerRadius(20)
                    }
                    .disabled(viewModel.title.isEmpty || viewModel.content.isEmpty || viewModel.isPosting)
                }
            }
            .toolbarBackground(Color.forumBackground, for: .navigationBar)
        }
    }
}

struct LinearProgressView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(LinearProgressViewStyle(tint: .forumAccent))
            .frame(height: 2)
    }
}
