import Foundation
internal import Combine
import GoogleSignIn
import UIKit
internal import Auth

enum AuthProvider {
    case google, microsoft, apple, email
}

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var userName: String? = nil
    @Published var provider: AuthProvider? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false
    @Published var isCaretaker: Bool = false
    
    private let pendingProfileKey = "PendingProfileCache"
    
    private struct PendingProfile: Codable {
        let email: String
        let firstName: String
        let lastName: String?
        let dateOfBirthISO: String?
        let phone: String?
        let address: String?
        let insuranceId: String?
    }
    
    private func savePendingProfile(_ p: PendingProfile) {
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: pendingProfileKey)
        }
    }
    
    private func loadPendingProfile(for email: String) -> PendingProfile? {
        guard let data = UserDefaults.standard.data(forKey: pendingProfileKey) else { return nil }
        guard let p = try? JSONDecoder().decode(PendingProfile.self, from: data) else { return nil }
        return p.email.caseInsensitiveCompare(email) == .orderedSame ? p : nil
    }
    
    private func clearPendingProfile() {
        UserDefaults.standard.removeObject(forKey: pendingProfileKey)
    }
    
    private init() {}
    
    // Real sign up with Supabase (full profile)
    func signUpWithEmail(firstName: String,
                         lastName: String?,
                         email: String,
                         password: String,
                         dateOfBirth: Date?,
                         phone: String?,
                         address: String?,
                         insuranceId: String?,
                         remember: Bool = false) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty, !password.isEmpty, !fn.isEmpty else {
            await MainActor.run { self.errorMessage = "Please fill required fields" }
            return
        }
        
        await MainActor.run { self.isLoading = true; self.errorMessage = nil }
        
        do {
            let user = try await SupabaseService.shared.signUp(
                email: trimmedEmail,
                password: password,
                firstName: fn,
                lastName: ln,
                dateOfBirth: dateOfBirth,
                phone: phone,
                address: address,
                insuranceId: insuranceId
            )
            
            // If session exists immediately (email confirmation disabled), proceed
            if let current = SupabaseService.shared.currentUser, current.id == user.id {
                await SupabaseService.shared.ensureProfileExists(for: current, displayName: fn)
                await MainActor.run {
                    self.isAuthenticated = true
                    self.userName = fn
                    self.provider = .email
                    self.isLoading = false
                    self.errorMessage = nil
                }
            } else {
                // Cache full profile locally to upsert after first sign-in
                let isoDOB = dateOfBirth.map { ISO8601DateFormatter().string(from: $0) }
                savePendingProfile(PendingProfile(email: trimmedEmail, firstName: fn, lastName: ln, dateOfBirthISO: isoDOB, phone: phone, address: address, insuranceId: insuranceId))
                await MainActor.run {
                    self.isAuthenticated = false
                    self.userName = nil
                    self.provider = nil
                    self.isLoading = false
                    self.errorMessage = "Sign up successful. Please verify your email, then sign in to continue."
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Sign up failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // Email/Password sign in with Supabase
    func signInWithEmail(email: String, password: String, remember: Bool = false) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !password.isEmpty else {
            await MainActor.run { self.errorMessage = "Please enter email and password" }
            return
        }
        
        await MainActor.run { self.isLoading = true; self.errorMessage = nil }
        
        do {
            let session = try await SupabaseService.shared.signIn(email: trimmed, password: password)
            // If we have a cached pending profile, upsert full fields, then clear
            if let pending = loadPendingProfile(for: session.user.email ?? trimmed) {
                let dob = pending.dateOfBirthISO.flatMap { ISO8601DateFormatter().date(from: $0) }
                try? await SupabaseService.shared.upsertProfile(
                    userId: session.user.id,
                    email: session.user.email,
                    firstName: pending.firstName,
                    lastName: pending.lastName,
                    dateOfBirth: dob,
                    phone: pending.phone,
                    address: pending.address,
                    insuranceId: pending.insuranceId,
                    isActive: true
                )
                clearPendingProfile()
            } else {
                await SupabaseService.shared.ensureProfileExists(for: session.user, displayName: self.userName ?? session.user.email?.components(separatedBy: "@").first)
            }
            
            await MainActor.run {
                self.isAuthenticated = true
                self.userName = session.user.email?.components(separatedBy: "@").first ?? "User"
                self.provider = .email
                self.isLoading = false
                self.errorMessage = nil
            }
            
            await checkUserRole()
        } catch {
            await MainActor.run {
                self.errorMessage = "Sign in failed: \(error.localizedDescription)"
                self.isLoading = false
            }
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
        guard let rootViewController = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else {
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
        // Attempt backend sign out (fire-and-forget)
        Task { try? await SupabaseService.shared.signOut() }
        self.isAuthenticated = false
        self.userName = nil
        self.provider = nil
        self.errorMessage = nil
    }
    
    func checkUserRole() async {
        do {
            let recipients = try await SupabaseService.shared.fetchMyCareRecipients()
            await MainActor.run {
                self.isCaretaker = !recipients.isEmpty
            }
        } catch {
            await MainActor.run {
                // Don't block the user for this, but log the error
                print("Failed to check user role: \(error.localizedDescription)")
                self.isCaretaker = false
            }
        }
    }
    nonisolated func handleOpenURL(_ url: URL) -> Bool {
        // Dispatch to main thread to avoid crashes
        DispatchQueue.main.async {
            let handled = GIDSignIn.sharedInstance.handle(url)
            if handled {
                print("✅ Google Sign-In URL handled successfully")
            }
        }
        return true
    }
}
