//
//  CaretakerDashboardView.swift
//  Digiwellbeing
//
//  Created by GitHub Copilot on 2025-11-09.
//

import SwiftUI

struct CaretakerDashboardView: View {
    @State private var careRecipients = [SupabaseService.CaretakerRelationshipResponse]()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var profiles: [UUID: SupabaseService.ProfileRow] = [:]

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading...")
                } else if let errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if careRecipients.isEmpty {
                    Text("You are not a caretaker for any users yet.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(careRecipients) { recipient in
                        NavigationLink(destination: RecipientDetailView(userId: recipient.user_id,
                                                                         accessibleMetrics: recipient.accessible_metrics ?? [],
                                                                         relationshipId: recipient.relationship_id,
                                                                         initialConsentStatus: recipient.consent_status)) {
                            VStack(alignment: .leading, spacing: 4) {
                                let p = profiles[recipient.user_id]
                                Text(displayName(for: p) ?? "Care Recipient")
                                    .font(.headline)
                                if let email = p?.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("Status: \(recipient.consent_status)")
                                        .font(.subheadline)
                                        .foregroundColor(recipient.consent_status == "APPROVED" ? .green : .orange)
                                    if recipient.consent_status == "PENDING" {
                                        Button("Approve") {
                                            Task {
                                                do {
                                                    try await SupabaseService.shared.approveRelationship(relationshipId: recipient.relationship_id)
                                                    await loadRecipients()
                                                } catch { errorMessage = error.localizedDescription }
                                            }
                                        }
                                        .font(.caption)
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Care Recipients")
            .task { await loadRecipients() }
        }
    }

    private func displayName(for p: SupabaseService.ProfileRow?) -> String? {
        guard let p else { return nil }
        if let f = p.first_name, let l = p.last_name, !f.isEmpty, !l.isEmpty { return "\(f) \(l)" }
        return p.first_name ?? p.last_name
    }

    private func loadRecipients() async {
        isLoading = true
        errorMessage = nil
        do {
            let recipients = try await SupabaseService.shared.fetchMyCareRecipients()
            self.careRecipients = recipients
            var profs: [UUID: SupabaseService.ProfileRow] = [:]
            for r in recipients {
                if let pr = try await SupabaseService.shared.fetchProfile(userId: r.user_id) {
                    profs[r.user_id] = pr
                }
            }
            self.profiles = profs
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct RecipientDetailView: View {
    let userId: UUID
    let accessibleMetrics: [String]
    let relationshipId: UUID
    @State private var consentStatus: String
    
    init(userId: UUID, accessibleMetrics: [String], relationshipId: UUID, initialConsentStatus: String) {
        self.userId = userId
        self.accessibleMetrics = accessibleMetrics
        self.relationshipId = relationshipId
        _consentStatus = State(initialValue: initialConsentStatus)
    }
    
    @State private var profile: SupabaseService.ProfileRow?
    @State private var isLoading = false
    @State private var errorMessage: String?
    // Latest single values
    @State private var heartRate: Double?
    @State private var steps: Double?
    @State private var vo2Max: Double?
    @State private var sleepScore: Double?
    @State private var spo2Avg: Double?
    // Series for charts
    @State private var spo2Samples: [Double] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let profile {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTitle(profile))
                            .font(.largeTitle)
                            .bold()
                        if let email = profile.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                if consentStatus != "APPROVED" {
                    VStack(spacing: 8) {
                        Text("Access is pending approval by the care recipient.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button(action: { Task { await refreshRelationshipStatus() } }) {
                            Text("Refresh Status")
                        }
                    }
                    .padding(.horizontal)
                }

                if isLoading {
                    ProgressView("Loading health data...")
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    RecipientVO2MaxCard(value: vo2Max)
                    RecipientSleepQualityCard(score: sleepScore)
                    RecipientSpO2ChartCard(samples: spo2Samples)
                    RecipientSpO2ValueCard(value: spo2Avg)
                }
                .padding(.horizontal)
                .opacity(consentStatus == "APPROVED" ? 1.0 : 0.4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    RecipientHeartRateCard(value: heartRate)
                    RecipientStepsCard(value: steps)
                }
                .padding(.horizontal)
                .opacity(consentStatus == "APPROVED" ? 1.0 : 0.4)
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(.systemGray6), Color(.systemTeal).opacity(0.08)]), startPoint: .top, endPoint: .bottom)
        )
        .navigationTitle("Recipient Health Data")
        .task { if consentStatus == "APPROVED" { await loadRichData() } else { await loadProfileOnly() } }
        .refreshable { if consentStatus == "APPROVED" { await loadRichData(force: true) } else { await refreshRelationshipStatus() } }
    }

    private func displayTitle(_ p: SupabaseService.ProfileRow) -> String {
        displayName(for: p) ?? "Care Recipient"
    }

    private func displayName(for p: SupabaseService.ProfileRow) -> String? {
        if let f = p.first_name, let l = p.last_name, !f.isEmpty, !l.isEmpty { return "\(f) \(l)" }
        return p.first_name ?? p.last_name
    }

    private func loadRichData(force: Bool = false) async {
        guard !isLoading || force else { return }
        isLoading = true
        errorMessage = nil
        do {
            if profile == nil { profile = try await SupabaseService.shared.fetchProfile(userId: userId) }
            let defaults = ["VO2_MAX","SLEEP_QUALITY","BLOOD_OXYGEN","HEART_RATE","STEPS"]
            let allowed = Set((accessibleMetrics.isEmpty ? defaults : accessibleMetrics).map { $0.uppercased() })
            async let hrRecOpt = allowed.contains("HEART_RATE") ? SupabaseService.shared.fetchCareRecipientLatestRecord(userId: userId, metricType: "HEART_RATE") : .none
            async let stRecOpt = allowed.contains("STEPS") ? SupabaseService.shared.fetchCareRecipientLatestRecord(userId: userId, metricType: "STEPS") : .none
            async let vo2RecOpt = allowed.contains("VO2_MAX") ? SupabaseService.shared.fetchCareRecipientLatestRecord(userId: userId, metricType: "VO2_MAX") : .none
            async let slRecOpt = allowed.contains("SLEEP_QUALITY") ? SupabaseService.shared.fetchCareRecipientLatestRecord(userId: userId, metricType: "SLEEP_QUALITY") : .none
            async let spoRecOpt = allowed.contains("BLOOD_OXYGEN") ? SupabaseService.shared.fetchCareRecipientLatestRecord(userId: userId, metricType: "BLOOD_OXYGEN") : .none
            async let spoSeriesOpt = allowed.contains("BLOOD_OXYGEN") ? SupabaseService.shared.fetchCareRecipientRecentRecords(userId: userId, metricType: "BLOOD_OXYGEN", limit: 20) : []
            let (hrRec, stRec, vo2Rec, slRec, spoRec, series) = try await (hrRecOpt, stRecOpt, vo2RecOpt, slRecOpt, spoRecOpt, spoSeriesOpt)
            heartRate = hrRec?.metric_value
            steps = stRec?.metric_value
            vo2Max = vo2Rec?.metric_value
            sleepScore = slRec?.metric_value
            spo2Avg = spoRec?.metric_value
            spo2Samples = series.reversed().map { $0.metric_value }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func loadProfileOnly() async {
        do { profile = try await SupabaseService.shared.fetchProfile(userId: userId) } catch { errorMessage = error.localizedDescription }
    }
    
    private func refreshRelationshipStatus() async {
        do {
            if let updated = try await SupabaseService.shared.fetchRelationshipById(relationshipId) {
                consentStatus = updated.consent_status
                if consentStatus == "APPROVED" { await loadRichData(force: true) }
            }
        } catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - Recipient Cards
struct RecipientVO2MaxCard: View {
    let value: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VO2 Max").font(.headline).foregroundColor(.white)
            Spacer()
            Text(value.map { String(format: "%.1f mL/kg/min", $0) } ?? "—")
                .font(.title2).bold().foregroundColor(.white)
            LineChartView(data: [40,42,43,45,44,46,45], lineColor: .white).frame(height: 32)
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: .purple.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}
struct RecipientSleepQualityCard: View {
    let score: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Quality").font(.headline).foregroundColor(.white)
            Spacer()
            Text(score.map { String(format: "%.0f%%", $0) } ?? "—")
                .font(.title2).bold().foregroundColor(.white)
            LineChartView(data: [70,75,80,85,90,85,88], lineColor: .white).frame(height: 32)
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [.teal, .green]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: .teal.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}
struct RecipientSpO2ChartCard: View {
    let samples: [Double]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Blood Oxygen Trend").font(.headline).foregroundColor(.white)
            Spacer()
            LineChartView(data: samples.isEmpty ? [97,98,97,99,98,97,98] : samples, lineColor: .white).frame(height: 32)
            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [.blue, .cyan]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: .blue.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}
struct RecipientSpO2ValueCard: View {
    let value: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Blood Oxygen").font(.headline).foregroundColor(.white)
            Spacer()
            Text(value.map { String(format: "%.0f%%", $0) } ?? "—")
                .font(.title2).bold().foregroundColor(.white)
            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [.indigo, .mint]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: .indigo.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}
struct RecipientHeartRateCard: View {
    let value: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate").font(.headline).foregroundColor(.white)
            Spacer()
            Text(value.map { String(format: "%.0f BPM", $0) } ?? "—")
                .font(.title2).bold().foregroundColor(.white)
            LineChartView(data: [68,70,72,75,74,73,72], lineColor: .white).frame(height: 32)
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [Color.red.opacity(0.8), Color.pink.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Color.red.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}
struct RecipientStepsCard: View {
    let value: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Steps Today").font(.headline).foregroundColor(.white)
            Spacer()
            Text(value.map { String(format: "%.0f", $0) } ?? "—")
                .font(.title2).bold().foregroundColor(.white)
            ColorfulBarChartView(data: [200,500,800,1200,1500,2000,1800,1600,1200,800]).frame(height: 32)
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Color.blue.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}

struct CaretakerDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        CaretakerDashboardView()
    }
}
