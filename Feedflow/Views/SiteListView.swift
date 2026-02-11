import SwiftUI
import Combine

// Define ForumSite enum — ordered: RSS, Hacker News, 4D4Y, V2EX, Linux.do, Zhihu
enum ForumSite: String, CaseIterable, Identifiable {
    case rss
    case hackerNews
    case fourD4Y
    case v2ex
    case linuxDo
    case zhihu
    
    var id: String { rawValue }
    
    func makeService() -> ForumService {
        switch self {
        case .fourD4Y: return FourD4YService()
        case .linuxDo: return DiscourseService()
        case .hackerNews: return HackerNewsService()
        case .v2ex: return V2EXService()
        case .rss: return RSSService()
        case .zhihu: return ZhihuService()
        }
    }
}

// MARK: - Community Visibility Settings

class CommunitySettingsManager: ObservableObject {
    static let shared = CommunitySettingsManager()
    
    private let key = "enabledCommunities"
    
    @Published var enabledSites: Set<String> {
        didSet {
            // Ensure RSS is always enabled
            if !enabledSites.contains(ForumSite.rss.rawValue) {
                enabledSites.insert(ForumSite.rss.rawValue)
            }
            let array = Array(enabledSites)
            UserDefaults.standard.set(array, forKey: key)
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: key) {
            self.enabledSites = Set(saved)
            // Ensure RSS is always present
            if !self.enabledSites.contains(ForumSite.rss.rawValue) {
                self.enabledSites.insert(ForumSite.rss.rawValue)
            }
        } else {
            // Default: all communities enabled
            self.enabledSites = Set(ForumSite.allCases.map { $0.rawValue })
        }
    }
    
    func isEnabled(_ site: ForumSite) -> Bool {
        enabledSites.contains(site.rawValue)
    }
    
    func toggle(_ site: ForumSite) {
        // RSS cannot be toggled off
        guard site != .rss else { return }
        if enabledSites.contains(site.rawValue) {
            enabledSites.remove(site.rawValue)
        } else {
            enabledSites.insert(site.rawValue)
        }
    }
    
    var visibleSites: [ForumSite] {
        ForumSite.allCases.filter { isEnabled($0) }
    }
}

// MARK: - Community Configuration View

struct CommunityConfigView: View {
    @ObservedObject var settingsManager = CommunitySettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.forumBackground.ignoresSafeArea()
                
                List {
                    ForEach(ForumSite.allCases) { site in
                        let service = site.makeService()
                        let isOn = settingsManager.isEnabled(site)
                        let isRSS = site == .rss
                        
                        HStack(spacing: 14) {
                            AvatarView(urlOrName: service.logo, size: 32)
                                .foregroundColor(.forumAccent)
                            
                            Text(service.name)
                                .font(.body)
                                .foregroundColor(.forumTextPrimary)
                            
                            Spacer()
                            
                            if isRSS {
                                // RSS is always on — show a locked checkmark
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.forumAccent)
                                    .font(.title3)
                            } else {
                                Toggle("", isOn: Binding(
                                    get: { isOn },
                                    set: { _ in settingsManager.toggle(site) }
                                ))
                                .tint(.forumAccent)
                                .labelsHidden()
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.forumCard)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("communities".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized()) {
                        dismiss()
                    }
                    .foregroundColor(.forumAccent)
                }
            }
        }
    }
}

// MARK: - Site List (Home Page)

struct SiteListView: View {
    // No callback needed, NavigationLink handles it
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var communitySettings = CommunitySettingsManager.shared
    @State private var showSettings: Bool = false
    @State private var showLogin: Bool = false
    @State private var showBookmarks: Bool = false
    @State private var showAISummary: Bool = false
    
    var body: some View {
        ZStack {
            Color.forumBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
//                Text("select_community".localized())
//                    .font(.title2)
//                    .bold()
//                    .foregroundColor(.forumTextPrimary)
//                    .padding(.top, 40)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    ForEach(communitySettings.visibleSites) { site in
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
//            .navigationTitle("Feedflow")
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 0) {
                    // AI Summary
                    Button(action: {
                        showAISummary = true
                    }) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.forumTextPrimary)
                            .frame(maxWidth: .infinity)
                    }

                    // Bookmarks
                    Button(action: {
                        showBookmarks = true
                    }) {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(.forumTextPrimary)
                            .frame(maxWidth: .infinity)
                    }

                    // EN/CN Toggle
                    Button(action: {
                        LocalizationManager.shared.currentLanguage =
                            LocalizationManager.shared.currentLanguage == "en" ? "zh" : "en"
                    }) {
                        Text(LocalizationManager.shared.currentLanguage == "en" ? "🇺🇸" : "🇨🇳")
                            .font(.system(size: 20))
                            .frame(maxWidth: .infinity)
                    }

                    // Light/Dark Toggle
                    Button(action: {
                        themeManager.isDarkMode.toggle()
                    }) {
                        Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                            .foregroundColor(.forumTextPrimary)
                            .frame(maxWidth: .infinity)
                    }

                    // Login
                    Button(action: {
                        showLogin = true
                    }) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.forumTextPrimary)
                            .frame(maxWidth: .infinity)
                    }

                    // Settings
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.forumTextPrimary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 44)
                .background(Color.forumCard)
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
            .sheet(isPresented: $showAISummary) {
                HomeAISummaryView()
            }
        }
    }
}
