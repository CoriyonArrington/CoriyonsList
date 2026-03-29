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

@MainActor
class AppState: ObservableObject {
    
    // MARK: - Authentication State
    @Published var isAuthenticated: Bool = false
    @Published var currentUserID: UUID? = nil
    
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
    // FIX: Default to nil so "All Categories" is shown on launch
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
    
    // MARK: - Auth Methods
    func checkAuth() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            await MainActor.run {
                self.currentUserID = session.user.id
                self.isAuthenticated = true
            }
            await fetchListings(longitude: -93.2650, latitude: 44.9778, radiusInMiles: 50.0)
            await fetchUserInteractions()
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUserID = nil
            }
        }
    }
    
    func signOut() async {
        do {
            try await SupabaseManager.shared.client.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUserID = nil
                self.listings = []
                self.favoriteIDs.removeAll()
                self.votedIDs.removeAll()
                self.hiddenIDs.removeAll()
            }
        } catch {
            print("Error signing out: \(error)")
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
            print("Supabase RPC Query Error: \(error.localizedDescription)")
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
            print("Failed to fetch interactions: \(error.localizedDescription)")
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
                print("Supabase Delete Error: \(error)")
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
            } catch { print("Supabase Favorite Sync Error: \(error)") }
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
            } catch { print("Supabase Hide Sync Error: \(error)") }
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
            } catch { print("Supabase Vote Sync Error: \(error)") }
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
            // FIX: Clearing the search query now resets the feed to All Categories
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
