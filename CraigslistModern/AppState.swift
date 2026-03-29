import Foundation
import CoreLocation
import SwiftUI
import Supabase

struct RadiusQuery: Codable {
    let user_lon: Double
    let user_lat: Double
    let radius_meters: Double
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

@MainActor
class AppState: ObservableObject {
    
    // MARK: - Authentication State
    @Published var isAuthenticated: Bool = false
    @Published var currentUserID: UUID? = nil
    @Published var currentUserEmail: String? = nil
    @Published var authProvider: String? = nil
    @Published var currentUserProfile: [String: Any]? = nil
    @Published var oauthAvatarURL: String? = nil
    
    // FIXED: Smart property that now prioritizes explicit storage uploads over OAuth defaults
    var displayAvatarURL: String? {
        let dbAvatar = currentUserProfile?["avatar_url"] as? String
        
        // If the database has a Supabase storage URL (meaning they explicitly uploaded one), prioritize it
        if let dbAvatar = dbAvatar, dbAvatar.contains("supabase.co") || dbAvatar.contains("avatars") {
            return dbAvatar
        }
        
        // Otherwise, fall back to the OAuth avatar, and finally the generic DB avatar
        return oauthAvatarURL ?? dbAvatar
    }
    
    // MARK: - UI State & User Actions
    @Published var favoriteIDs: Set<UUID> = []
    @Published var hiddenIDs: Set<UUID> = []
    @Published var votedIDs: Set<UUID> = []
    
    @Published var previousTab: Int = 0
    @Published var selectedTab: Int = 0 {
        didSet {
            if oldValue != 1 && oldValue != selectedTab {
                previousTab = oldValue
            }
        }
    }
    
    @Published var selectedLocation: String = "Minneapolis, MN"
    @Published var selectedTopCategory: String? = nil
    @Published var selectedSubCategory: String? = nil
    
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
    @Published var isLoading: Bool = false
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
            await fetchListings(longitude: -93.2650, latitude: 44.9778, radiusInMiles: 50.0)
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
    
    // Consolidates the storage upload AND database profile update
    func updateProfile(fullName: String, avatarImageData: Data?) async -> Bool {
        guard let uid = currentUserID else { return false }
        
        await MainActor.run { isLoading = true }
        
        var finalAvatarUrl = self.displayAvatarURL ?? ""
        
        do {
            // MARK: - 1. Handle Storage Upload (If Image Changed)
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
            
            // MARK: - 2. Handle Database Update
            let updatePayload = ProfileUpdate(full_name: fullName, avatar_url: finalAvatarUrl)
            
            try await SupabaseManager.shared.client
                .from("profiles")
                .update(updatePayload)
                .eq("id", value: uid)
                .execute()
            
            // Refresh local profile state
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
                self.favoriteIDs.removeAll()
                self.votedIDs.removeAll()
                self.hiddenIDs.removeAll()
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
            
            self.listings = fetchedListings
        } catch {
            self.errorMessage = "Failed to load local listings. Please check your connection."
        }
        
        isLoading = false
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
    
    // MARK: - Listing Management
    func deleteListing(_ id: UUID) {
        guard let listingBackup = listings.first(where: { $0.id == id }) else { return }
        let wasFavorited = favoriteIDs.contains(id)
        let wasVoted = votedIDs.contains(id)
        let wasHidden = hiddenIDs.contains(id)
        
        withAnimation {
            self.listings.removeAll { $0.id == id }
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
    
    // MARK: - Search Logic
    func getSuggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        let lowerQuery = query.lowercased()
        var suggestions = Set<String>()
        
        for cat in topCategories.map({$0.0}) where cat.lowercased().contains(lowerQuery) { suggestions.insert(cat) }
        for subs in subCategories.values {
            for sub in subs where sub.lowercased().contains(lowerQuery) { suggestions.insert(sub) }
        }
        
        let hoods = ["North Loop", "Uptown", "Northeast", "Downtown", "Linden Hills", "Dinkytown", "Edina", "Bloomington"]
        for hood in hoods where hood.lowercased().contains(lowerQuery) { suggestions.insert(hood) }
        for listing in listings where listing.title.lowercased().contains(lowerQuery) { suggestions.insert(listing.title) }
        
        return Array(suggestions.prefix(6)).sorted()
    }
    
    func autoSelectCategory(for query: String) {
        let q = query.lowercased()
        if q.isEmpty {
            selectedTopCategory = nil
            selectedSubCategory = nil
            return
        }
        if q.contains("laptop") || q.contains("tv") || q.contains("macbook") || q.contains("sony") || q.contains("electronics") {
            selectedTopCategory = "For Sale"; selectedSubCategory = "Electronics"
        } else if q.contains("chair") || q.contains("table") || q.contains("sofa") || q.contains("furniture") {
            selectedTopCategory = "For Sale"; selectedSubCategory = "Furniture"
        } else if q.contains("bike") || q.contains("trek") {
            selectedTopCategory = "For Sale"; selectedSubCategory = "Bikes"
        } else if q.contains("jacket") || q.contains("shirt") || q.contains("clothes") {
            selectedTopCategory = "For Sale"; selectedSubCategory = "Clothing"
        } else if q.contains("apartment") || q.contains("rent") || q.contains("room") {
            selectedTopCategory = "Housing"; selectedSubCategory = "Apts / Housing"
        } else if q.contains("developer") || q.contains("job") || q.contains("hire") {
            selectedTopCategory = "Jobs"; selectedSubCategory = "Tech / Software"
        }
    }
}
