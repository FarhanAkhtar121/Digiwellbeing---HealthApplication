import Foundation
internal import Combine
import GoogleSignIn
import UIKit

enum AuthProvider {
    case google, microsoft, apple, email
}

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var userName: String? = nil
    @Published var provider: AuthProvider? = nil
    
    private init() {}
    
    // Email/Password (mock) login
    func signInWithEmail(email: String, password: String, remember: Bool = false) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !password.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isAuthenticated = true
            self.userName = trimmed.components(separatedBy: "@").first ?? trimmed
            self.provider = .email
        }
    }
    
    func signInWithApple() {
        // TODO: Replace with real Sign in with Apple using AuthenticationServices
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isAuthenticated = true
            self.userName = "Apple User"
            self.provider = .apple
        }
    }
    
    func signInWithGoogle() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey:"GIDClientID") as? String else {
            print("Missing GIDClientID in Info.plist")
            return
        }
        guard let rootViewController = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController else {
            print("Unable to get root view controller")
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            if let error = error {
                print("Google Sign-In error: \(error.localizedDescription)")
                return
            }
            guard let profile = result?.user.profile else {
                print("No Google user profile")
                return
            }
            DispatchQueue.main.async {
                self?.isAuthenticated = true
                self?.userName = profile.name
                self?.provider = .google
            }
        }
    }
    
    func signInWithMicrosoft() {
        // TODO: Replace with MSAL SDK flow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isAuthenticated = true
            self.userName = "Microsoft User"
            self.provider = .microsoft
        }
    }
    
    func signOut() {
        self.isAuthenticated = false
        self.userName = nil
        self.provider = nil
    }
    
    func handleOpenURL(_ url: URL) -> Bool {
        // Pass to Google if possible; extend with MSAL handler later
        if GIDSignIn.sharedInstance.handle(url) { return true }
        return false
    }
}
