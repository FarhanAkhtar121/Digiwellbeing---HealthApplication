import SwiftUI

struct Caretaker: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var contact: String // email or phone
}

struct SharingView: View {
    @ObservedObject private var authManager = AuthManager.shared

    // Local UI state
    @State private var caretakerEmail: String = ""
    @State private var relationshipType: String = "Family"
    @State private var permissionLevel: String = "READ_ONLY"
    @State private var accessibleMetrics: Set<String> = ["STEPS", "HEART_RATE"]
    @State private var accessStartDateEnabled: Bool = false
    @State private var accessEndDateEnabled: Bool = false
    @State private var accessStartDate: Date = Date()
    @State private var accessEndDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    @State private var saving: Bool = false
    @State private var errorText: String?

    // Loaded relationships
    @State private var relationships: [SupabaseService.CaretakerRelationshipResponse] = []

    private let maxCaretakers = 3

    private let relationshipOptions = ["Family", "Healthcare Provider", "Emergency Contact"]
    private let permissionOptions = ["READ_ONLY", "READ_WRITE", "ADMIN"]
    private let metricOptions = [
        "VO2_MAX", "SLEEP_QUALITY", "BLOOD_OXYGEN", "HEART_RATE", "STEPS", "WORKOUT"
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    AppTopBar(title: "DigitalWellbeing - Health App", showLogout: true) { authManager.signOut() }

                    if let username = authManager.userName {
                        Text("Welcome, \(username)!")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    // Title
                    HStack {
                        Image(systemName: "person.2.fill").foregroundColor(.blue)
                        Text("Sharing").font(.largeTitle).bold()
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Add caretaker form
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundColor(.blue)
                            Text("Add a caretaker (max \(maxCaretakers))")
                                .font(.headline)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caretaker Email")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("email@example.com", text: $caretakerEmail)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("Relationship Type").font(.caption).foregroundColor(.secondary)
                                Picker("Relationship", selection: $relationshipType) {
                                    ForEach(relationshipOptions, id: \.self) { Text($0) }
                                }
                                .pickerStyle(.menu)
                            }
                            VStack(alignment: .leading) {
                                Text("Permission").font(.caption).foregroundColor(.secondary)
                                Picker("Permission", selection: $permissionLevel) {
                                    ForEach(permissionOptions, id: \.self) { Text($0) }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Accessible Metrics").font(.caption).foregroundColor(.secondary)
                            // Simple multi-select list of toggles
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                ForEach(metricOptions, id: \.self) { m in
                                    HStack {
                                        Toggle(isOn: Binding(
                                            get: { accessibleMetrics.contains(m) },
                                            set: { newVal in
                                                if newVal { accessibleMetrics.insert(m) } else { accessibleMetrics.remove(m) }
                                            }
                                        )) {
                                            Text(m.replacingOccurrences(of: "_", with: " "))
                                                .font(.caption)
                                        }
                                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Limit access dates", isOn: $accessStartDateEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                            if accessStartDateEnabled {
                                DatePicker("Start", selection: $accessStartDate, displayedComponents: .date)
                                Toggle("Set end date", isOn: $accessEndDateEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                if accessEndDateEnabled {
                                    DatePicker("End", selection: $accessEndDate, displayedComponents: .date)
                                }
                            }
                        }

                        if let e = errorText {
                            Text(e).font(.caption).foregroundColor(.red)
                        }

                        Button(action: { addCaretaker() }) {
                            HStack {
                                if saving { ProgressView().scaleEffect(0.8) }
                                Text(saving ? "Saving..." : "Add caretaker")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSave ? Color.blue : Color.blue.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canSave || saving)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                    .padding(.horizontal)

                    // Relationships list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Caretaker Relationships").font(.headline)
                        if relationships.isEmpty {
                            HStack {
                                Image(systemName: "info.circle").foregroundColor(.secondary)
                                Text("No caretakers added yet.").foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(relationships) { rel in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "person.crop.circle.fill").foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(rel.relationship_type)
                                            .font(.subheadline).bold()
                                        Text("Permission: \(rel.permission_level)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let metrics = rel.accessible_metrics, !metrics.isEmpty {
                                            Text("Metrics: \(metrics.joined(separator: ", "))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Text("Status: \(rel.consent_status)")
                                            .font(.caption)
                                            .foregroundColor(rel.consent_status == "APPROVED" ? .green : .secondary)
                                        HStack(spacing: 12) {
                                            if rel.consent_status == "PENDING" {
                                                Button("Approve") {
                                                    Task {
                                                        do {
                                                            try await SupabaseService.shared.approveRelationship(relationshipId: rel.relationship_id)
                                                            await reloadRelationships()
                                                        } catch { errorText = error.localizedDescription }
                                                    }
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .tint(.green)
                                            }
                                            if rel.consent_status == "APPROVED" {
                                                Button("Revoke") {
                                                    Task {
                                                        do {
                                                            try await SupabaseService.shared.revokeRelationship(relationshipId: rel.relationship_id)
                                                            await reloadRelationships()
                                                        } catch { errorText = error.localizedDescription }
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                                .tint(.red)
                                            }
                                        }
                                        .font(.caption)
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .background(
                LinearGradient(gradient: Gradient(colors: [Color(.systemGray6), Color(.systemBlue).opacity(0.06)]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationBarHidden(true)
            .task { await reloadRelationships() }
        }
    }

    private var canSave: Bool {
        // enforce max caretakers client side by counting current loaded relationships
        let underLimit = relationships.count < maxCaretakers
        let hasEmail = !caretakerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMetrics = !accessibleMetrics.isEmpty
        return underLimit && hasEmail && hasMetrics
    }

    private func reloadRelationships() async {
        do {
            relationships = try await SupabaseService.shared.fetchMyCaretakerRelationships()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func addCaretaker() {
        guard canSave else { return }
        saving = true
        errorText = nil
        let start = accessStartDateEnabled ? accessStartDate : nil
        let end = (accessStartDateEnabled && accessEndDateEnabled) ? accessEndDate : nil
        Task {
            do {
                try await SupabaseService.shared.createCaretakerByEmail(
                    caretakerEmail: caretakerEmail,
                    permissionLevel: permissionLevel,
                    accessibleMetrics: Array(accessibleMetrics),
                    relationshipType: relationshipType,
                    accessStart: start,
                    accessEnd: end
                )
                caretakerEmail = ""
                accessibleMetrics = ["STEPS", "HEART_RATE"]
                accessStartDateEnabled = false
                accessEndDateEnabled = false
                await reloadRelationships()
            } catch {
                errorText = error.localizedDescription
            }
            saving = false
        }
    }
}

struct SharingView_Previews: PreviewProvider {
    static var previews: some View {
        SharingView()
    }
}
