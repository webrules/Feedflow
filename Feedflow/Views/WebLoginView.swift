import SwiftUI
import WebKit

// MARK: - Login Configuration per Site

struct SiteLoginConfig {
    let site: ForumSite
    let loginURL: String
    let successURLPatterns: [String]  // URL patterns that indicate successful login
    let oauthOptions: [OAuthOption]
    
    struct OAuthOption: Identifiable {
        let id = UUID()
        let name: String
        let icon: String      // SF Symbol name
        let loginPath: String  // Path appended to base URL
    }
    
    // Optional check: success only if this cookie is present
    let requiredCookieName: String?
    
    init(site: ForumSite, loginURL: String, successURLPatterns: [String], oauthOptions: [OAuthOption], requiredCookieName: String? = nil) {
        self.site = site
        self.loginURL = loginURL
        self.successURLPatterns = successURLPatterns
        self.oauthOptions = oauthOptions
        self.requiredCookieName = requiredCookieName
    }
}

extension SiteLoginConfig {
    static func config(for site: ForumSite) -> SiteLoginConfig? {
        switch site {
        case .rss:
            return nil  // RSS doesn't need login
            
        case .fourD4Y:
            return SiteLoginConfig(
                site: .fourD4Y,
                loginURL: "https://www.4d4y.com/forum/logging.php?action=login",
                successURLPatterns: ["4d4y.com/forum/index.php", "4d4y.com/forum/forumdisplay"],
                oauthOptions: []
            )
            
        case .hackerNews:
            return SiteLoginConfig(
                site: .hackerNews,
                loginURL: "https://news.ycombinator.com/login",
                successURLPatterns: ["news.ycombinator.com/news", "news.ycombinator.com/newest"],
                oauthOptions: []
            )
            
        case .v2ex:
            return SiteLoginConfig(
                site: .v2ex,
                loginURL: "https://v2ex.com/signin",
                successURLPatterns: ["v2ex.com/?tab", "v2ex.com/#", "v2ex.com/member/"],
                oauthOptions: [
                    .init(name: "Google", icon: "g.circle.fill", loginPath: "https://v2ex.com/auth/google"),
                    .init(name: "Solana", icon: "wallet.pass.fill", loginPath: "https://v2ex.com/auth/solana"),
                ]
            )
            
        case .linuxDo:
            return SiteLoginConfig(
                site: .linuxDo,
                loginURL: "https://linux.do/login",
                successURLPatterns: ["linux.do/latest", "linux.do/top", "linux.do/categories"],
                oauthOptions: [
                    .init(name: "Google", icon: "g.circle.fill", loginPath: "https://linux.do/auth/google_oauth2"),
                    .init(name: "GitHub", icon: "chevron.left.forwardslash.chevron.right", loginPath: "https://linux.do/auth/github"),
                    .init(name: "X", icon: "xmark", loginPath: "https://linux.do/auth/twitter"),
                    .init(name: "Discord", icon: "bubble.left.and.bubble.right.fill", loginPath: "https://linux.do/auth/discord"),
                    .init(name: "Apple", icon: "apple.logo", loginPath: "https://linux.do/auth/apple"),
                    .init(name: "Passkey", icon: "person.badge.key.fill", loginPath: "https://linux.do/session/passkey/challenge"),
                ]
            )
            
        case .zhihu:
            return SiteLoginConfig(
                site: .zhihu,
                loginURL: "https://www.zhihu.com/signin",
                // Re-adding generic patterns but relying on requiredCookieName for safety
                successURLPatterns: ["zhihu.com/hot", "zhihu.com/follow", "zhihu.com/people", "zhihu.com/?tab", "zhihu.com/question", "www.zhihu.com", "zhihu.com"],
                oauthOptions: [],
                requiredCookieName: "z_c0"  // Critical for Zhihu auth
            )
        }
    }
}

// MARK: - WebView Login (handles Captcha, OAuth, etc.)

struct WebLoginView: UIViewRepresentable {
    let config: SiteLoginConfig
    let onLoginSuccess: ([HTTPCookie]) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(config: config, onLoginSuccess: onLoginSuccess)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Use default data store so OAuth redirects through third-party domains work
        configuration.websiteDataStore = .default()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        
        // Use a Safari-like user agent to avoid Google's "disallowed_useragent" block
        // Google blocks OAuth from embedded WKWebViews with the default UA
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        if let url = URL(string: config.loginURL) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let config: SiteLoginConfig
        let onLoginSuccess: ([HTTPCookie]) -> Void
        
        init(config: SiteLoginConfig, onLoginSuccess: @escaping ([HTTPCookie]) -> Void) {
            self.config = config
            self.onLoginSuccess = onLoginSuccess
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let currentURL = webView.url?.absoluteString else { return }
            
            // Check if we've reached a success URL
            let isSuccess = config.successURLPatterns.contains { pattern in
                currentURL.contains(pattern)
            }
            
            if isSuccess {
                checkCookiesWithRetry(webView: webView, retries: 5)
            }
        }
        
        func checkCookiesWithRetry(webView: WKWebView, retries: Int) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                // If a required cookie is specified, verify it exists
                if let requiredName = self.config.requiredCookieName {
                    guard cookies.contains(where: { $0.name == requiredName }) else {
                        print("[WebLogin] Matched success URL but '\(requiredName)' missing. Retries left: \(retries)")
                        if retries > 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.checkCookiesWithRetry(webView: webView, retries: retries - 1)
                            }
                        }
                        return
                    }
                }
                
                DispatchQueue.main.async {
                    self.onLoginSuccess(cookies)
                }
            }
        }
    }
}

// MARK: - Web Login Sheet View

struct WebLoginSheetView: View {
    let config: SiteLoginConfig
    let onSuccess: ([HTTPCookie]) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var isLoggedIn = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.forumBackground.ignoresSafeArea()
                
                if isLoggedIn {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("login_success".localized())
                            .font(.headline)
                            .foregroundColor(.forumTextPrimary)
                    }
                } else {
                    WebLoginView(config: config) { cookies in
                        isLoggedIn = true
                        onSuccess(cookies)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(config.site.makeService().name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized()) { dismiss() }
                        .foregroundColor(.forumAccent)
                }
            }
        }
    }
}
