import SwiftUI

struct SignUpView: View {
    @ObservedObject private var auth = AuthManager.shared

    @Environment(\.dismiss) private var dismiss

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var rememberMe: Bool = true
    @State private var showPassword: Bool = false
    @State private var showConfirm: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            AppTopBar(title: "DigitalWellbeing - Health App", showLogout: false)

            // Back row under the consistent top bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .font(.headline)
                        .accessibilityLabel("Back")
                }
                Spacer()
            }
            .padding(.horizontal)

            // Title
            VStack(alignment: .leading, spacing: 6) {
                Text("Sign up and Improve Your Health Today")
                    .font(.title2).bold()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            // Fields
            VStack(spacing: 14) {
                IconTextField(icon: "person", placeholder: "Enter your name", text: $fullName)
                IconTextField(icon: "envelope", placeholder: "Enter your email", text: $email)
                IconTextField(icon: "lock", placeholder: "Enter your password", text: $password, isSecure: !showPassword)
                    .overlay(alignment: .trailing) {
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 14)
                        }
                    }
                IconTextField(icon: "lock", placeholder: "Enter your confirm password", text: $confirmPassword, isSecure: !showConfirm)
                    .overlay(alignment: .trailing) {
                        Button(action: { showConfirm.toggle() }) {
                            Image(systemName: showConfirm ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 14)
                        }
                    }
                Toggle(isOn: $rememberMe) { Text("Remember me").font(.subheadline) }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding(.horizontal)

            // Sign up button (mock: use email flow)
            Button(action: { auth.signInWithEmail(email: email, password: password, remember: rememberMe) }) {
                Text("Sign up").font(.headline).frame(maxWidth: .infinity).padding()
            }
            .disabled(!isFormValid)
            .background(isFormValid ? Color.blue : Color.blue.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(14)
            .padding(.horizontal)

            // Or
            VStack(spacing: 10) {
                Text("Or").foregroundColor(.secondary)
                SocialButton(title: "Continue with Google", systemImage: "globe", color: .red) { auth.signInWithGoogle() }
                SocialButton(title: "Continue with Microsoft", systemImage: "person.crop.circle", color: .blue) { auth.signInWithMicrosoft() }
                SocialButton(title: "Continue with Apple", systemImage: "apple.logo", color: .black) { auth.signInWithApple() }
            }
            .padding(.horizontal)

            Spacer(minLength: 12)

            HStack(spacing: 4) {
                Text("Already have an account?").foregroundColor(.secondary)
                Button("Login") { dismiss() }
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var isFormValid: Bool {
        !fullName.isEmpty && !email.isEmpty && password.count >= 6 && password == confirmPassword
    }
}

#Preview { SignUpView() }
