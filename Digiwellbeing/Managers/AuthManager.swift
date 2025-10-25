import Foundation
internal import Combine
// Add these imports after adding the SDKs via Swift Package Manager
import GoogleSignIn
// import MSAL
import UIKit

// Placeholder imports for SSO SDKs
enum AuthProvider {
    case google, microsoft
}

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var userName: String? = nil
    @Published var provider: AuthProvider? = nil
    
    private init() {}
    
//    func signInWithGoogle() {
//        // Example: Simulate Google sign-in success
//        // Replace this with actual GoogleSignIn SDK logic
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            self.isAuthenticated = true
//            self.userName = "Google User"
//            self.provider = .google
//        }
//    }
    
    func signInWithGoogle() {
            guard let clientID = Bundle.main.object(forInfoDictionaryKey:"GIDClientID") as? String else {
                print("Missing GIDClientID in Info.plist")
                return
            }
            
            guard let rootViewController = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        else {
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
        // Example: Simulate Microsoft sign-in success
        // Replace this with actual MSAL SDK logic
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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
    
    // Handle SSO callback URLs
    func handleOpenURL(_ url: URL) -> Bool {
        // TODO: Pass URL to Google/MSAL SDKs
        return false
    }
}
