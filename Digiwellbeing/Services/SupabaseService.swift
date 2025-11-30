import Foundation
import Supabase

// Encodable payload for RPC - defined outside class to avoid MainActor isolation
nonisolated struct CreateCaretakerByEmailParams: Encodable, Sendable {
    let p_user: String
    let p_caretaker_email: String
    let p_permission: String
    let p_accessible_metrics: [String]
    let p_relationship: String
    let p_access_start: String?
    let p_access_end: String?
}

final class SupabaseService {
    static let shared = SupabaseService()
    let client: SupabaseClient

    private init() {
        guard
            let urlStr = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: urlStr),
            !key.isEmpty
        else {
            fatalError("Missing SUPABASE_URL or SUPABASE_ANON_KEY in `Info.plist`")
        }
        
        // Configure Auth (removed unsupported persistSession argument). If emitLocalSessionAsInitialSession is not available in your SDK version, remove that line.
        let options = SupabaseClientOptions(
            auth: .init(
                autoRefreshToken: true,
                emitLocalSessionAsInitialSession: true
            )
        )
        client = SupabaseClient(supabaseURL: url, supabaseKey: key, options: options)
    }

    // Current user (nil if not signed in)
    var currentUser: Supabase.User? {
        client.auth.currentUser
    }

    // MARK: - Authentication

    @discardableResult
    func signUp(email: String,
                password: String,
                firstName: String?,
                lastName: String?,
                dateOfBirth: Date?,
                phone: String?,
                address: String?,
                insuranceId: String?) async throws -> Supabase.User {
        let resp = try await client.auth.signUp(email: email, password: password)
        let user = resp.user
        
        // Only attempt profile upsert if a valid session exists (avoids RLS when email confirmation is required)
        if let authedId = client.auth.currentUser?.id, authedId == user.id {
            try await upsertProfile(
                userId: user.id,
                email: email,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: dateOfBirth,
                phone: phone,
                address: address,
                insuranceId: insuranceId,
                isActive: true
            )
        }
        
        return user
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> Supabase.Session {
        let session = try await client.auth.signIn(email: email, password: password)
        return session
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Profiles

    func upsertProfile(userId: UUID,
                       email: String?,
                       firstName: String?,
                       lastName: String?,
                       dateOfBirth: Date?,
                       phone: String?,
                       address: String?,
                       insuranceId: String?,
                       isActive: Bool = true) async throws {
        let isoDOB = dateOfBirth.map { ISO8601DateFormatter().string(from: $0) }
        
        struct ProfileInsert: Encodable {
            let user_id: String
            let email: String?
            let first_name: String?
            let last_name: String?
            let date_of_birth: String?
            let phone_number: String?
            let address: String?
            let insurance_id: String?
            let is_active: Bool
        }
        
        let profile = ProfileInsert(
            user_id: userId.uuidString,
            email: email,
            first_name: firstName,
            last_name: lastName,
            date_of_birth: isoDOB,
            phone_number: phone,
            address: address,
            insurance_id: insuranceId,
            is_active: isActive
        )
        
        _ = try await client.from("profiles").upsert(profile).execute()
    }

    // Quick smoke test: fetch 1 row
    @discardableResult
    func ping() async -> Bool {
        do {
            _ = try await client
                .from("health_data")
                .select()
                .limit(1)
                .execute()
            print("Supabase OK")
            return true
        } catch {
            print("Supabase error: \(error)")
            return false
        }
    }

    // MARK: - Health data

    struct HealthRecordInput: Encodable {
        let user_id: UUID
        let metric_type: String        // e.g. "STEPS"
        let metric_value: Double
        let unit_of_measurement: String
        let recorded_date: String      // ISO8601
        let data_source: String        // "HealthKit" | "Manual" | "Device"
    }

    func addHealthRecord(_ rec: HealthRecordInput) async throws {
        _ = try await client.from("health_data").insert(rec).execute()
    }

    // Upsert variant used by continuous sync; requires a unique index server-side for true de-dup.
    func upsertHealthRecord(_ rec: HealthRecordInput) async throws {
        _ = try await client.from("health_data").upsert(rec).execute()
    }

    struct HealthRecordResponse: Decodable {
        let health_data_id: UUID
        let user_id: UUID
        let metric_type: String
        let metric_value: Double
        let unit_of_measurement: String
        let recorded_date: String
        let data_source: String
        let created_at: String
    }

    func fetchMyHealthData(metricType: String? = nil, limit: Int = 200) async throws -> [HealthRecordResponse] {
        guard let uid = client.auth.currentUser?.id else { return [] }
        
        let response: [HealthRecordResponse] = try await client
            .from("health_data")
            .select()
            .execute()
            .value
        
        // Filter in-memory since Postgrest query builder doesn't have eq method in this SDK version
        var filtered = response.filter { $0.user_id == uid }
        if let metricType {
            filtered = filtered.filter { $0.metric_type == metricType }
        }
        
        // Sort by recorded_date descending
        let sorted = filtered.sorted { $0.recorded_date > $1.recorded_date }
        
        // Apply limit
        return Array(sorted.prefix(limit))
    }

    // Caretaker can call this if policies allow them to see the care recipient's data
    func fetchCareRecipientHealthData(userId: UUID, metricType: String? = nil, limit: Int = 200) async throws -> [HealthRecordResponse] {
        let response: [HealthRecordResponse] = try await client
            .from("health_data")
            .select()
            .execute()
            .value
        
        // Filter in-memory
        var filtered = response.filter { $0.user_id == userId }
        if let metricType {
            filtered = filtered.filter { $0.metric_type == metricType }
        }
        
        // Sort by recorded_date descending
        let sorted = filtered.sorted { $0.recorded_date > $1.recorded_date }
        
        // Apply limit
        return Array(sorted.prefix(limit))
    }

    // MARK: - Caretaker relationships

    struct CaretakerRelationshipInput: Encodable {
        let user_id: String
        let caretaker_id: String
        let permission_level: String
        let accessible_metrics: [String]
        let relationship_type: String
        let access_start_date: String?
        let access_end_date: String?
        let consent_status: String
    }

    func createCaretakerRelationship(for userId: UUID,
                                     caretakerId: UUID,
                                     permissionLevel: String,
                                     accessibleMetrics: [String],
                                     relationshipType: String,
                                     accessStart: Date?,
                                     accessEnd: Date?) async throws {
        let iso = ISO8601DateFormatter()
        let payload = CaretakerRelationshipInput(
            user_id: userId.uuidString,
            caretaker_id: caretakerId.uuidString,
            permission_level: permissionLevel,
            accessible_metrics: accessibleMetrics,
            relationship_type: relationshipType,
            access_start_date: accessStart.map { iso.string(from: $0) },
            access_end_date: accessEnd.map { iso.string(from: $0) },
            consent_status: "PENDING"
        )
        _ = try await client.from("caretaker_relationships").insert(payload).execute()
    }

    struct CaretakerApproveUpdate: Encodable { let consent_status: String; let consent_timestamp: String }
    struct CaretakerRevokeUpdate: Encodable { let consent_status: String; let access_end_date: String; let consent_timestamp: String }

    func approveRelationship(relationshipId: UUID) async throws {
        let iso = ISO8601DateFormatter().string(from: Date())
        let update = CaretakerApproveUpdate(consent_status: "APPROVED", consent_timestamp: iso)
        _ = try await client
            .from("caretaker_relationships")
            .update(update)
            .filter("relationship_id", operator: "eq", value: relationshipId.uuidString)
            .execute()
    }

    func revokeRelationship(relationshipId: UUID) async throws {
        let iso = ISO8601DateFormatter().string(from: Date())
        let update = CaretakerRevokeUpdate(consent_status: "REVOKED", access_end_date: iso, consent_timestamp: iso)
        _ = try await client
            .from("caretaker_relationships")
            .update(update)
            .filter("relationship_id", operator: "eq", value: relationshipId.uuidString)
            .execute()
    }
    
    // MARK: - Profile Management

    func ensureProfileExists(for user: Supabase.User, displayName: String?) async {
        do {
            try await upsertProfile(
                userId: user.id,
                email: user.email,
                firstName: displayName,
                lastName: nil,
                dateOfBirth: nil,
                phone: nil,
                address: nil,
                insuranceId: nil,
                isActive: true
            )
        } catch {
            print("ensureProfileExists upsert error: \(error)")
        }
    }
    
    func refreshSessionIfNeeded() async {
        do {
            // Attempt refresh; if not needed or no session, this may throw and we ignore
            _ = try await client.auth.refreshSession()
        } catch {
            // No active session or refresh not required; ignore
        }
    }

    // MARK: - Caretaker by email (RPC)

    struct CaretakerRelationshipResponse: Decodable, Identifiable {
        let relationship_id: UUID
        let user_id: UUID
        let caretaker_id: UUID
        let permission_level: String
        let accessible_metrics: [String]?
        let relationship_type: String
        let access_start_date: String?
        let access_end_date: String?
        let consent_status: String
        let created_at: String
        var id: UUID { relationship_id }
    }

    func createCaretakerByEmail(caretakerEmail: String,
                                permissionLevel: String,
                                accessibleMetrics: [String],
                                relationshipType: String,
                                accessStart: Date?,
                                accessEnd: Date?) async throws {
        guard let uid = client.auth.currentUser?.id else { throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"]) }
        let iso = ISO8601DateFormatter()
        let payload = CreateCaretakerByEmailParams(
            p_user: uid.uuidString,
            p_caretaker_email: caretakerEmail,
            p_permission: permissionLevel,
            p_accessible_metrics: accessibleMetrics,
            p_relationship: relationshipType,
            p_access_start: accessStart.map { iso.string(from: $0) },
            p_access_end: accessEnd.map { iso.string(from: $0) }
        )
        
        _ = try await client.rpc("create_caretaker_by_email", params: payload).execute()
    }

    func fetchMyCaretakerRelationships(limit: Int = 50) async throws -> [CaretakerRelationshipResponse] {
        guard let uid = client.auth.currentUser?.id else { return [] }
        let rows: [CaretakerRelationshipResponse] = try await client
            .from("caretaker_relationships")
            .select()
            .filter("user_id", operator: "eq", value: uid.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows
    }
    
    /// Fetches relationships where the current user is the CARETAKER.
    func fetchMyCareRecipients(limit: Int = 50) async throws -> [CaretakerRelationshipResponse] {
        guard let uid = client.auth.currentUser?.id else { return [] }
        let rows: [CaretakerRelationshipResponse] = try await client
            .from("caretaker_relationships")
            .select()
            .filter("caretaker_id", operator: "eq", value: uid.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows
    }
    
    struct ProfileRow: Decodable { let user_id: UUID; let email: String?; let first_name: String?; let last_name: String? }
    
    func fetchProfile(userId: UUID) async throws -> ProfileRow? {
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .filter("user_id", operator: "eq", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
    
    func fetchCareRecipientLatestRecord(userId: UUID, metricType: String) async throws -> HealthRecordResponse? {
        let rows: [HealthRecordResponse] = try await client
            .from("health_data")
            .select()
            .filter("user_id", operator: "eq", value: userId.uuidString)
            .filter("metric_type", operator: "eq", value: metricType)
            .order("recorded_date", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
    
    func fetchCareRecipientRecentRecords(userId: UUID, metricType: String, limit: Int = 20) async throws -> [HealthRecordResponse] {
        let rows: [HealthRecordResponse] = try await client
            .from("health_data")
            .select()
            .filter("user_id", operator: "eq", value: userId.uuidString)
            .filter("metric_type", operator: "eq", value: metricType)
            .order("recorded_date", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows
    }
    
    func fetchRelationshipById(_ id: UUID) async throws -> CaretakerRelationshipResponse? {
        let rows: [CaretakerRelationshipResponse] = try await client
            .from("caretaker_relationships")
            .select()
            .filter("relationship_id", operator: "eq", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
    
    struct ProfileRowComplete: Decodable, Sendable {
        let user_id: UUID
        let email: String?
        let first_name: String?
        let last_name: String?
        let date_of_birth: String?
        let gender: String?
        let phone_number: String?
    }

    nonisolated struct WellnessScoreInput: Encodable, Sendable {
        let user_id: String
        let cardiovascular_fitness_score: Double
        let sleep_quality_score: Double
        let physical_activity_score: Double
        let heart_health_score: Double
        let recovery_score: Double
        let consistency_score: Double
        let total_wellness_score: Double
        let score_category: String
        let calculation_date: String
    }
    
    func fetchProfileComplete(userId: UUID) async throws -> ProfileRowComplete? {
        let rows: [ProfileRowComplete] = try await client
            .from("profiles")
            .select()
            .filter("user_id", operator: "eq", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func saveWellnessScore(_ score: WellnessScoreComponents) async throws {
        guard let uid = client.auth.currentUser?.id else { return }
        
        let iso = ISO8601DateFormatter()
        let dateOnly = Calendar.current.startOfDay(for: Date())
        
        let record = WellnessScoreInput(
            user_id: uid.uuidString,
            cardiovascular_fitness_score: score.cardiovascularFitness,
            sleep_quality_score: score.sleepQuality,
            physical_activity_score: score.physicalActivity,
            heart_health_score: score.heartHealth,
            recovery_score: score.recovery,
            consistency_score: score.consistency,
            total_wellness_score: score.totalScore,
            score_category: score.category,
            calculation_date: iso.string(from: dateOnly)
        )
        
        _ = try await client.from("wellness_scores").upsert(record).execute()
    }

    func fetchWellnessScoreHistory(days: Int = 30) async throws -> [WellnessScoreResponse] {
        guard let uid = client.auth.currentUser?.id else { return [] }
        
        let rows: [WellnessScoreResponse] = try await client
            .from("wellness_scores")
            .select()
            .filter("user_id", operator: "eq", value: uid.uuidString)
            .order("calculation_date", ascending: false)
            .limit(days)
            .execute()
            .value
        
        return rows
    }
    
    
}
