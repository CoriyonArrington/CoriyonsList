import Foundation
import CoreLocation
import SwiftUI
import Supabase

struct RadiusQuery: Codable {
    let user_lon: Double
    let user_lat: Double
    let radius_meters: Double
}

struct SearchQuery: Codable {
    let user_lon: Double
    let user_lat: Double
    let radius_meters: Double
    let search_term: String
}

struct UserInteraction: Codable {
    var userId: UUID
    var listingId: UUID
    var interactionType: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case listingId = "listing_id"
        case interactionType = "interaction_type"
    }
}

// Struct strictly used for explicit profile updates
struct ProfileUpdate: Encodable {
    let full_name: String
    let avatar_url: String
}

// MARK: - Trust & Safety Payloads
struct BlockUserPayload: Encodable {
    let blockerId: UUID
    let blockedId: UUID
    
    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

struct ReportItemPayload: Encodable {
    let reporterId: UUID
    let targetId: UUID
    let reportType: String
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case reporterId = "reporter_id"
        case targetId = "target_id"
        case reportType = "report_type"
        case reason = "reason"
    }
}

struct BlockedUserRecord: Decodable {
    let blockedId: UUID
    
    enum CodingKeys: String, CodingKey {
        case blockedId = "blocked_id"
    }
}

@MainActor
class AppState: ObservableObject {
    
    // MARK: - Authentication State
    @Published var isAuthenticated: Bool = false
    @Published var currentUserID: UUID? = nil
    @Published var currentUserEmail: String? = nil
    @Published var authProvider: String? = nil
    @Published var currentUserProfile: [String: Any]? = nil
    @Published var oauthAvatarURL: String? = nil
    
    var displayAvatarURL: String? {
        let dbAvatar = currentUserProfile?["avatar_url"] as? String
        
        if let dbAvatar = dbAvatar, dbAvatar.contains("supabase.co") || dbAvatar.contains("avatars") {
            return dbAvatar
        }
        
        return oauthAvatarURL ?? dbAvatar
    }
    
    // MARK: - UI State & User Actions
    @Published var favoriteIDs: Set<UUID> = []
    @Published var hiddenIDs: Set<UUID> = []
    @Published var votedIDs: Set<UUID> = []
    @Published var blockedUserIDs: Set<UUID> = []
    
    @Published var isShowingFallback: Bool = false
    
    @Published var previousTab: Int = 0
    @Published var selectedTab: Int = 0 {
        didSet {
            if oldValue != 1 && oldValue != selectedTab {
                previousTab = oldValue
            }
        }
    }
    
    @Published var selectedLocation: String = UserDefaults.standard.string(forKey: "savedLocationName") ?? "Minneapolis, MN" {
        didSet { UserDefaults.standard.set(selectedLocation, forKey: "savedLocationName") }
    }
    
    @Published var savedLatitude: Double = UserDefaults.standard.object(forKey: "savedLatitude") as? Double ?? 44.9778 {
        didSet { UserDefaults.standard.set(savedLatitude, forKey: "savedLatitude") }
    }
    
    @Published var savedLongitude: Double = UserDefaults.standard.object(forKey: "savedLongitude") as? Double ?? -93.2650 {
        didSet { UserDefaults.standard.set(savedLongitude, forKey: "savedLongitude") }
    }
    
    @Published var selectedTopCategory: String? = nil
    @Published var selectedSubCategory: String? = nil
    
    // NEW: Smart Server-Inferred Category Suggestions
    @Published var suggestedTopCategory: String? = nil
    @Published var suggestedSubCategory: String? = nil
    
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    
    let topCategories = [
        ("For Sale", "tag.fill"),
        ("Housing", "house.fill"),
        ("Jobs", "briefcase.fill"),
        ("Community", "person.2.fill"),
        ("Services", "wrench.and.screwdriver.fill"),
        ("Gigs", "bolt.fill")
    ]
    
    let subCategories: [String: [String]] = [
        "For Sale": ["Free", "Furniture", "Electronics", "Bikes", "Cars", "Clothing", "Tools", "Books", "Tickets"],
        "Housing": ["Apts / Housing", "Rooms / Shared", "Sublets / Temporary", "Parking / Storage", "Office / Commercial"],
        "Jobs": ["Tech / Software", "Hospitality", "Labor", "Education", "Creative", "Healthcare"],
        "Community": ["Activities", "Events", "Volunteers", "Groups", "Lost & Found", "Childcare"],
        "Services": ["Automotive", "Beauty", "Creative", "Financial", "Labor / Move", "Real Estate"],
        "Gigs": ["Computer", "Creative", "Crew", "Domestic", "Event", "Labor"]
    ]

    // MARK: - Live Data Properties
    @Published var listings: [LiveListing] = []
    @Published var searchResults: [LiveListing] = []
    @Published var isLoading: Bool = false
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Auth & Account Methods
    func checkAuth() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            await MainActor.run {
                self.currentUserID = session.user.id
                self.currentUserEmail = session.user.email
                
                let providerRaw = String(describing: session.user.appMetadata["provider"] ?? "email")
                if providerRaw.lowercased().contains("google") { self.authProvider = "Google" }
                else if providerRaw.lowercased().contains("apple") { self.authProvider = "Apple" }
                else { self.authProvider = "Email" }
                
                var bestAvatar: String? = nil
                
                let metadata = session.user.userMetadata
                if let data = try? JSONEncoder().encode(metadata),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let pic = (dict["avatar_url"] as? String) ?? (dict["picture"] as? String), pic.hasPrefix("http") {
                        bestAvatar = pic
                    }
                }
                
                if bestAvatar == nil, let identities = session.user.identities {
                    for identity in identities {
                        let identityData = identity.identityData
                        if let data = try? JSONEncoder().encode(identityData),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let pic = (dict["avatar_url"] as? String) ?? (dict["picture"] as? String), pic.hasPrefix("http") {
                                bestAvatar = pic
                                break
                            }
                        }
                    }
                }
                
                self.oauthAvatarURL = bestAvatar
                self.isAuthenticated = true
            }
            
            await fetchUserProfile()
            await fetchBlockedUsers()
            
            let initialRadius = UserDefaults.standard.double(forKey: "nearbyDistance")
            await fetchListings(longitude: savedLongitude, latitude: savedLatitude, radiusInMiles: initialRadius > 0 ? initialRadius : 50.0)
            
            await fetchUserInteractions()
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUserID = nil
                self.currentUserEmail = nil
                self.authProvider = nil
                self.oauthAvatarURL = nil
            }
        }
    }
    
    func updateProfile(fullName: String, avatarImageData: Data?) async -> Bool {
        guard let uid = currentUserID else { return false }
        
        await MainActor.run { isLoading = true }
        
        var finalAvatarUrl = self.displayAvatarURL ?? ""
        
        do {
            if let imageData = avatarImageData {
                let filename = "\(UUID().uuidString)-avatar.jpg"
                let path = "\(uid)/\(filename)"
                
                try await SupabaseManager.shared.client.storage
                    .from("avatars")
                    .upload(
                        path,
                        data: imageData,
                        options: FileOptions(contentType: "image/jpeg", upsert: true)
                    )
                
                finalAvatarUrl = try SupabaseManager.shared.client.storage
                    .from("avatars")
                    .getPublicURL(path: path).absoluteString
            }
            
            let updatePayload = ProfileUpdate(full_name: fullName, avatar_url: finalAvatarUrl)
            
            try await SupabaseManager.shared.client
                .from("profiles")
                .update(updatePayload)
                .eq("id", value: uid)
                .execute()
            
            await fetchUserProfile()
            
            await MainActor.run {
                triggerToast(message: "Profile updated successfully.")
                self.oauthAvatarURL = finalAvatarUrl
                isLoading = false
            }
            return true
            
        } catch {
            await MainActor.run {
                triggerToast(message: "Failed to update profile image.")
                isLoading = false
            }
            return false
        }
    }
    
    func signOut() async {
        do {
            try await SupabaseManager.shared.client.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUserID = nil
                self.currentUserEmail = nil
                self.authProvider = nil
                self.currentUserProfile = nil
                self.oauthAvatarURL = nil
                self.listings = []
                self.searchResults = []
                self.favoriteIDs.removeAll()
                self.votedIDs.removeAll()
                self.hiddenIDs.removeAll()
                self.blockedUserIDs.removeAll()
                self.isShowingFallback = false
            }
        } catch {
        }
    }
    
    func fetchUserProfile() async {
        guard let userId = currentUserID else { return }
        do {
            let response = try await SupabaseManager.shared.client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
            
            if let profile = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                await MainActor.run {
                    self.currentUserProfile = profile
                }
            }
        } catch {
        }
    }

    func deleteAccount() async -> Bool {
        guard currentUserID != nil else { return false }
        
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            try await SupabaseManager.shared.client.rpc("delete_user_account").execute()
            
            await signOut()
            
            await MainActor.run {
                triggerToast(message: "Account permanently deleted.")
                isLoading = false
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Deletion Failed: \(error.localizedDescription)"
                isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Fetch Data
    func fetchListings(longitude: Double, latitude: Double, radiusInMiles: Double) async {
        isLoading = true
        errorMessage = nil
        
        let radiusInMeters = radiusInMiles * 1609.34
        let queryParams = RadiusQuery(user_lon: longitude, user_lat: latitude, radius_meters: radiusInMeters)
        
        do {
            let fetchedListings: [LiveListing] = try await SupabaseManager.shared.client
                .rpc("get_listings_within_radius", params: queryParams)
                .execute()
                .value
            
            let safeListings = fetchedListings.filter { !self.blockedUserIDs.contains($0.sellerId) }
            self.listings = safeListings
            
            if !safeListings.isEmpty && !self.selectedLocation.contains("MN") {
                self.isShowingFallback = true
                self.triggerToast(message: "No local results. Showing featured listings.")
            } else {
                self.isShowingFallback = false
            }
            
        } catch {
            self.errorMessage = "Failed to load local listings. Please check your connection."
        }
        
        isLoading = false
    }
    
    func fetchSearchResults(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                self.searchResults = []
                self.suggestedTopCategory = nil
                self.suggestedSubCategory = nil
            }
            return
        }
        
        await MainActor.run { self.isSearching = true }
        
        let initialRadius = UserDefaults.standard.double(forKey: "nearbyDistance")
        let radiusInMiles = initialRadius > 0 ? initialRadius : 50.0
        let radiusInMeters = radiusInMiles * 1609.34
        
        let queryParams = SearchQuery(user_lon: savedLongitude, user_lat: savedLatitude, radius_meters: radiusInMeters, search_term: query)
        
        do {
            let fetchedListings: [LiveListing] = try await SupabaseManager.shared.client
                .rpc("search_listings_within_radius", params: queryParams)
                .execute()
                .value
            
            let safeListings = fetchedListings.filter { !self.blockedUserIDs.contains($0.sellerId) }
            
            await MainActor.run {
                self.searchResults = safeListings
                self.determineSuggestedCategory(from: safeListings)
                self.isSearching = false
            }
        } catch {
            await MainActor.run { self.isSearching = false }
        }
    }
    
    // NEW: Analyzes DB results to determine the most relevant category dynamically
    private func determineSuggestedCategory(from listings: [LiveListing]) {
        guard !listings.isEmpty else {
            suggestedTopCategory = nil
            suggestedSubCategory = nil
            return
        }
        
        var categoryCounts: [String: Int] = [:]
        for listing in listings {
            if let cat = listing.category { categoryCounts[cat, default: 0] += 1 }
        }
        
        // Find the most frequent category in the search results
        guard let dominantCat = categoryCounts.max(by: { $0.value < $1.value })?.key else {
            suggestedTopCategory = nil
            suggestedSubCategory = nil
            return
        }
        
        // Reverse-lookup to find if it maps to a SubCategory and TopCategory
        for (top, subs) in subCategories {
            if subs.contains(dominantCat) {
                suggestedTopCategory = top
                suggestedSubCategory = dominantCat
                return
            }
        }
        
        // Check if it's already a TopCategory itself
        if topCategories.contains(where: { $0.0 == dominantCat }) {
            suggestedTopCategory = dominantCat
            suggestedSubCategory = nil
            return
        }
        
        suggestedTopCategory = nil
        suggestedSubCategory = nil
    }
    
    func fetchUserInteractions() async {
        guard let userId = currentUserID else { return }
        
        do {
            let interactions: [UserInteraction] = try await SupabaseManager.shared.client
                .from("user_interactions")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                self.favoriteIDs = Set(interactions.filter { $0.interactionType == "favorite" }.map { $0.listingId })
                self.votedIDs = Set(interactions.filter { $0.interactionType == "vote" }.map { $0.listingId })
                self.hiddenIDs = Set(interactions.filter { $0.interactionType == "hide" }.map { $0.listingId })
            }
        } catch {
        }
    }
    
    // MARK: - Trust & Safety
    func fetchBlockedUsers() async {
        guard let userId = currentUserID else { return }
        do {
            let records: [BlockedUserRecord] = try await SupabaseManager.shared.client
                .from("blocked_users")
                .select("blocked_id")
                .eq("blocker_id", value: userId)
                .execute()
                .value
            
            await MainActor.run {
                self.blockedUserIDs = Set(records.map { $0.blockedId })
            }
        } catch {
        }
    }
    
    func blockUser(_ userId: UUID) {
        guard let currentId = currentUserID, currentId != userId else { return }
        
        withAnimation {
            self.blockedUserIDs.insert(userId)
            self.listings.removeAll { $0.sellerId == userId }
            self.searchResults.removeAll { $0.sellerId == userId }
        }
        
        triggerToast(message: "User Blocked")
        
        Task {
            do {
                let payload = BlockUserPayload(blockerId: currentId, blockedId: userId)
                try await SupabaseManager.shared.client.from("blocked_users").insert(payload).execute()
            } catch {
            }
        }
    }
    
    func reportItem(targetId: UUID, type: String, reason: String) {
        guard let currentId = currentUserID else { return }
        
        Task {
            do {
                let payload = ReportItemPayload(reporterId: currentId, targetId: targetId, reportType: type, reason: reason)
                try await SupabaseManager.shared.client.from("reports").insert(payload).execute()
                
                await MainActor.run {
                    triggerToast(message: "Report Submitted to Admins")
                }
            } catch {
                await MainActor.run {
                    triggerToast(message: "Failed to submit report. Please try again.")
                }
            }
        }
    }
    
    // MARK: - Listing Management
    func deleteListing(_ id: UUID) {
        guard let listingBackup = listings.first(where: { $0.id == id }) else { return }
        let wasFavorited = favoriteIDs.contains(id)
        let wasVoted = votedIDs.contains(id)
        let wasHidden = hiddenIDs.contains(id)
        
        withAnimation {
            self.listings.removeAll { $0.id == id }
            self.searchResults.removeAll { $0.id == id }
            self.favoriteIDs.remove(id)
            self.votedIDs.remove(id)
            self.hiddenIDs.remove(id)
        }
        
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("listings")
                    .delete()
                    .eq("id", value: id)
                    .execute()
                
                await MainActor.run {
                    triggerToast(message: "Listing Permanently Deleted")
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        self.listings.insert(listingBackup, at: 0)
                        if wasFavorited { self.favoriteIDs.insert(id) }
                        if wasVoted { self.votedIDs.insert(id) }
                        if wasHidden { self.hiddenIDs.insert(id) }
                    }
                    triggerToast(message: "Failed to delete from server.")
                }
            }
        }
    }
    
    // MARK: - Live UI Sync Helpers
    func toggleFavorite(_ id: UUID) {
        let isAdding = !favoriteIDs.contains(id)
        
        if isAdding {
            favoriteIDs.insert(id)
            triggerToast(message: "Saved to Favorites")
        } else {
            favoriteIDs.remove(id)
        }
        
        guard let userId = currentUserID else { return }
        Task {
            do {
                if isAdding {
                    let interaction = UserInteraction(userId: userId, listingId: id, interactionType: "favorite")
                    try await SupabaseManager.shared.client.from("user_interactions").insert(interaction).execute()
                } else {
                    try await SupabaseManager.shared.client.from("user_interactions").delete()
                        .eq("user_id", value: userId).eq("listing_id", value: id).eq("interaction_type", value: "favorite").execute()
                }
            } catch { }
        }
    }
    
    func toggleHidden(_ id: UUID) {
        let isAdding = !hiddenIDs.contains(id)
        if isAdding { hiddenIDs.insert(id) } else { hiddenIDs.remove(id) }
        
        guard let userId = currentUserID else { return }
        Task {
            do {
                if isAdding {
                    let interaction = UserInteraction(userId: userId, listingId: id, interactionType: "hide")
                    try await SupabaseManager.shared.client.from("user_interactions").insert(interaction).execute()
                } else {
                    try await SupabaseManager.shared.client.from("user_interactions").delete()
                        .eq("user_id", value: userId).eq("listing_id", value: id).eq("interaction_type", value: "hide").execute()
                }
            } catch { }
        }
    }
    
    func toggleVoted(_ id: UUID) {
        let isAdding = !votedIDs.contains(id)
        
        if isAdding {
            votedIDs.insert(id)
            triggerToast(message: "Upvoted Listing")
        } else {
            votedIDs.remove(id)
        }
        
        guard let userId = currentUserID else { return }
        Task {
            do {
                if isAdding {
                    let interaction = UserInteraction(userId: userId, listingId: id, interactionType: "vote")
                    try await SupabaseManager.shared.client.from("user_interactions").insert(interaction).execute()
                } else {
                    try await SupabaseManager.shared.client.from("user_interactions").delete()
                        .eq("user_id", value: userId).eq("listing_id", value: id).eq("interaction_type", value: "vote").execute()
                }
            } catch { }
        }
    }
    
    func isFavorited(_ id: UUID) -> Bool { return favoriteIDs.contains(id) }
    
    func triggerToast(message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut) { self.showToast = false }
        }
    }
}
