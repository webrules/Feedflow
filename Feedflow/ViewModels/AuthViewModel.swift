import Foundation
import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var email: String = ""
    @Published var password: String = ""
    
    func signIn() {
        // Mock authentication
        isAuthenticated = true
    }
    
    func signOut() {
        isAuthenticated = false
        email = ""
        password = ""
    }
}
