import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var navigationManager = NavigationManager()
    
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            SiteListView()
                .navigationDestination(for: ForumSite.self) { site in
                    CommunitiesView(service: site.makeService())
                }
        }
        .environmentObject(navigationManager)
    }
}
