import SwiftUI
import Combine

class NavigationManager: ObservableObject {
    @Published var path = NavigationPath()
    
    func popToRoot() {
        path = NavigationPath()
    }
}
