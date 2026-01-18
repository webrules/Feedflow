import SwiftUI

// Define ForumSite enum
enum ForumSite: String, CaseIterable, Identifiable {
    case fourD4Y
    case linuxDo
    case hackerNews
    case v2ex
    case rss
    
    var id: String { rawValue }
    
    func makeService() -> ForumService {
        switch self {
        case .fourD4Y: return FourD4YService()
        case .linuxDo: return DiscourseService()
        case .hackerNews: return HackerNewsService()
        case .v2ex: return V2EXService()
        case .rss: return RSSService()
        }
    }
}

struct SiteListView: View {
    // No callback needed, NavigationLink handles it
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var localizationManager = LocalizationManager.shared
    @State private var showSettings: Bool = false
    @State private var showLogin: Bool = false
    @State private var showBookmarks: Bool = false
    
    var body: some View {
        ZStack {
            Color.forumBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("select_community".localized())
                    .font(.title2)
                    .bold()
                    .foregroundColor(.forumTextPrimary)
                    .padding(.top, 40)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    ForEach(ForumSite.allCases) { site in
                        let service = site.makeService()
                        
                        NavigationLink(value: site) {
                            VStack(spacing: 16) {
                                AvatarView(urlOrName: service.logo, size: 40)
                                    .foregroundColor(.forumAccent)
                                
                                Text(service.name)
                                    .font(.headline)
                                    .foregroundColor(.forumTextPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(Color.forumCard)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            themeManager.isDarkMode.toggle()
                        }) {
                            Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                                .foregroundColor(.forumTextPrimary)
                        }
                        
                        Button(action: {
                            LocalizationManager.shared.currentLanguage = 
                                LocalizationManager.shared.currentLanguage == "en" ? "zh" : "en"
                        }) {
                            Text(LocalizationManager.shared.currentLanguage == "en" ? "中" : "EN")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.forumTextPrimary)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showLogin = true
                        }) {
                            Image(systemName: "person.fill")
                                .foregroundColor(.forumTextPrimary)
                        }
                        
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.forumTextPrimary)
                        }
                        
                        Button(action: {
                            showBookmarks = true
                        }) {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.forumTextPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .sheet(isPresented: $showBookmarks) {
                BookmarksView()
            }
        }
    }
}
