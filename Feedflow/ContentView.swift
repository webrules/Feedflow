import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    var body: some View {
        NavigationStack {
            SiteListView()
                .navigationDestination(for: ForumSite.self) { site in
                    CommunitiesView(service: site.makeService())
                }
        }
    }
}
