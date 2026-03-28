import Foundation
import CoreLocation
import SwiftUI
import Supabase

// Matches the parameters expected by the Supabase RPC function
struct RadiusQuery: Codable {
    let user_lon: Double
    let user_lat: Double
    let radius_meters: Double
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
    @Published var selectedTopCategory: String? = "For Sale"
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
            // Fetch the default seed listings once logged in
            await fetchListings(longitude: -93.2650, latitude: 44.9778, radiusInMiles: 50.0)
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
                self.listings = [] // Clear memory
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
        
        let queryParams = RadiusQuery(
            user_lon: longitude,
            user_lat: latitude,
            radius_meters: radiusInMeters
        )
        
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
    
    // MARK: - UI Helpers
    func toggleFavorite(_ id: UUID) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
            triggerToast(message: "Saved to Favorites")
        }
    }
    
    func toggleHidden(_ id: UUID) {
        if hiddenIDs.contains(id) {
            hiddenIDs.remove(id)
        } else {
            hiddenIDs.insert(id)
        }
    }
    
    func toggleVoted(_ id: UUID) {
        if votedIDs.contains(id) {
            votedIDs.remove(id)
        } else {
            votedIDs.insert(id)
            triggerToast(message: "Upvoted Listing")
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
            selectedTopCategory = "For Sale"
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
