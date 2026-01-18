import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var localizationManager = LocalizationManager.shared
    
    @State private var selectedSite: ForumSite = .fourD4Y
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSaving: Bool = false
    @State private var showSavedMessage: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("select_site".localized())) {
                    Picker("site".localized(), selection: $selectedSite) {
                        ForEach(ForumSite.allCases) { site in
                            Text(site.makeService().name).tag(site)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedSite) { _ in
                        loadCredentials()
                    }
                }
                
                Section(header: Text("credentials".localized())) {
                    TextField("username".localized(), text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    SecureField("password".localized(), text: $password)
                        .textContentType(.password)
                }
                
                Section {
                    Button(action: saveCredentials) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("save_credentials".localized())
                            }
                            Spacer()
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                }
                
                if showSavedMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("credentials_saved".localized())
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(header: Text("note".localized())) {
                    Text("credentials_note".localized())
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("login".localized())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized()) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCredentials()
            }
        }
    }
    
    private func loadCredentials() {
        let siteId = selectedSite.rawValue
        
        // Load and decrypt username
        if let encryptedUsername = DatabaseManager.shared.getSetting(key: "login_\(siteId)_username"),
           let decryptedUsername = EncryptionHelper.shared.decrypt(encryptedUsername) {
            username = decryptedUsername
        } else {
            username = ""
        }
        
        // Don't load password for security - user needs to re-enter
        password = ""
    }
    
    private func saveCredentials() {
        isSaving = true
        let siteId = selectedSite.rawValue
        
        // Encrypt and store username/password
        if let encryptedUsername = EncryptionHelper.shared.encrypt(username),
           let encryptedPassword = EncryptionHelper.shared.encrypt(password) {
            DatabaseManager.shared.saveSetting(key: "login_\(siteId)_username", value: encryptedUsername)
            DatabaseManager.shared.saveSetting(key: "login_\(siteId)_password", value: encryptedPassword)
        }
        
        // Perform site-specific login and store cookies (e.g., 4d4y)
        if selectedSite == .fourD4Y {
            Task {
                do {
                    let service = FourD4YService()
                    let cookies = try await service.login(username: username, password: password)
                    DatabaseManager.shared.saveCookies(siteId: siteId, cookies: cookies)
                } catch {
                    print("Login error for site \(siteId): \(error)")
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            showSavedMessage = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSavedMessage = false
            }
        }
    }
}
