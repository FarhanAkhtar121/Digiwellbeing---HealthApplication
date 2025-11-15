import SwiftUI

struct SignUpView: View {
    @ObservedObject private var auth = AuthManager.shared

    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var insuranceId: String = ""

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
                HStack(spacing: 12) {
                    IconTextField(icon: "person", placeholder: "First name", text: $firstName)
                    IconTextField(icon: "person", placeholder: "Last name (optional)", text: $lastName)
                }
                IconTextField(icon: "envelope", placeholder: "Email", text: $email)
                IconTextField(icon: "lock", placeholder: "Password (min 6)", text: $password, isSecure: !showPassword)
                    .overlay(alignment: .trailing) {
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 14)
                        }
                    }
                IconTextField(icon: "lock", placeholder: "Confirm password", text: $confirmPassword, isSecure: !showConfirm)
                    .overlay(alignment: .trailing) {
                        Button(action: { showConfirm.toggle() }) {
                            Image(systemName: showConfirm ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 14)
                        }
                    }
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    .datePickerStyle(.compact)
                IconTextField(icon: "phone", placeholder: "Phone (optional)", text: $phone)
                IconTextField(icon: "house", placeholder: "Address (optional)", text: $address)
                IconTextField(icon: "idbadge", placeholder: "Insurance ID (optional)", text: $insuranceId)

                Toggle(isOn: $rememberMe) { Text("Remember me").font(.subheadline) }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding(.horizontal)

            // Sign up button
            Button(action: {
                Task {
                    await auth.signUpWithEmail(
                        firstName: firstName,
                        lastName: lastName.isEmpty ? nil : lastName,
                        email: email,
                        password: password,
                        dateOfBirth: dateOfBirth,
                        phone: phone.isEmpty ? nil : phone,
                        address: address.isEmpty ? nil : address,
                        insuranceId: insuranceId.isEmpty ? nil : insuranceId,
                        remember: rememberMe
                    )
                }
            }) {
                HStack {
                    if auth.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(auth.isLoading ? "Creating account..." : "Sign up")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .disabled(!isFormValid || auth.isLoading)
            .background((isFormValid && !auth.isLoading) ? Color.blue : Color.blue.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(14)
            .padding(.horizontal)
            
            // Error message
            if let error = auth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

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
        !firstName.isEmpty && !email.isEmpty && password.count >= 6 && password == confirmPassword
    }
}

#Preview { SignUpView() }
