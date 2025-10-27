import SwiftUI

struct LoginView: View {
    @ObservedObject private var auth = AuthManager.shared

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var rememberMe: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            AppTopBar(title: "DigitalWellbeing - Health App", showLogout: false)

            Spacer(minLength: 12)

            // Welcome title
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back!")
                    .font(.title).bold()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Fields
            VStack(spacing: 14) {
                IconTextField(icon: "envelope", placeholder: "Enter your email", text: $email, isSecure: false)
                IconTextField(icon: "lock", placeholder: "Enter your password", text: $password, isSecure: !showPassword)
                    .overlay(alignment: .trailing) {
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 14)
                        }
                    }
                HStack {
                    Toggle(isOn: $rememberMe) { Text("Remember me").font(.subheadline) }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    Spacer()
                    Button("Forgot password") {}
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            // Login button
            Button(action: { auth.signInWithEmail(email: email, password: password, remember: rememberMe) }) {
                Text("Login").font(.headline).frame(maxWidth: .infinity).padding()
            }
            .disabled(email.isEmpty || password.isEmpty)
            .background((email.isEmpty || password.isEmpty) ? Color.blue.opacity(0.4) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(14)

            // Separator
            HStack { Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3)); Text("or").foregroundColor(.secondary); Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3)) }
            .padding(.vertical, 4)

            // Social buttons
            VStack(spacing: 10) {
                SocialButton(title: "Continue with Google", systemImage: "globe", color: .red) {
                    auth.signInWithGoogle()
                }
                SocialButton(title: "Continue with Microsoft", systemImage: "person.crop.circle", color: .blue) {
                    auth.signInWithMicrosoft()
                }
                SocialButton(title: "Continue with Apple", systemImage: "apple.logo", color: .black) {
                    auth.signInWithApple()
                }
            }

            Spacer(minLength: 12)

            // Create account
            HStack(spacing: 4) {
                Text("Don’t have an account?")
                    .foregroundColor(.secondary)
                NavigationLink("Create an account") { SignUpView() }
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
}

// MARK: - Reusable UI pieces

struct IconTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

struct SocialButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                    .font(.headline)
                    .padding(.vertical, 12)
                Spacer()
            }
            .foregroundColor(color == .black ? .white : color)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .background(color.opacity(color == .black ? 1.0 : 0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

#Preview {
    NavigationStack { LoginView() }
}
