import Foundation
import CoreLocation
import SwiftUI

// Luminous, Dark-Mode Accessible Craigslist Purple
extension Color {
    static let craigslistPurple = Color(red: 0.65, green: 0.40, blue: 1.0)
}

// MARK: - Global App State
class AppState: ObservableObject {
    @Published var listings: [Listing] = initialMockListings
    @Published var favoriteIDs: Set<UUID> = []
    
    // Smart Tab Routing
    @Published var previousTab: Int = 0
    @Published var selectedTab: Int = 0 {
        didSet {
            if oldValue != 1 && oldValue != selectedTab {
                previousTab = oldValue
            }
        }
    }
    
    // Global Navigation & Filter State
    @Published var selectedLocation: String = "Minneapolis, MN"
    @Published var selectedTopCategory: String? = "For Sale" // Smart Default
    @Published var selectedSubCategory: String? = nil
    
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    
    // Craigslist Taxonomy
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
    
    func toggleFavorite(_ id: UUID) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
            triggerToast(message: "Saved to Favorites")
        }
    }
    
    func isFavorited(_ id: UUID) -> Bool {
        return favoriteIDs.contains(id)
    }
    
    func triggerToast(message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut) { self.showToast = false }
        }
    }
    
    // MARK: - NLP Smart Search & Auto-Select
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
        if q.contains("laptop") || q.contains("tv") || q.contains("macbook") || q.contains("sony") || q.contains("electronics") {
            selectedTopCategory = "For Sale"
            selectedSubCategory = "Electronics"
        } else if q.contains("chair") || q.contains("table") || q.contains("sofa") || q.contains("furniture") {
            selectedTopCategory = "For Sale"
            selectedSubCategory = "Furniture"
        } else if q.contains("bike") || q.contains("trek") {
            selectedTopCategory = "For Sale"
            selectedSubCategory = "Bikes"
        } else if q.contains("jacket") || q.contains("shirt") || q.contains("clothes") {
            selectedTopCategory = "For Sale"
            selectedSubCategory = "Clothing"
        } else if q.contains("apartment") || q.contains("rent") || q.contains("room") {
            selectedTopCategory = "Housing"
            selectedSubCategory = "Apts / Housing"
        } else if q.contains("developer") || q.contains("job") || q.contains("hire") {
            selectedTopCategory = "Jobs"
            selectedSubCategory = "Tech / Software"
        }
    }
}

// MARK: - Models
enum ViewMode: String, CaseIterable {
    // Reordered to match logical progression: Gallery -> Grid -> List -> Map
    case gallery = "Gallery"
    case grid = "Grid"
    case list = "List"
    case map = "Map"
    
    var icon: String {
        switch self {
        case .gallery: return "rectangle.grid.1x2.fill"
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .map: return "map"
        }
    }
}

struct Listing: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let price: Int
    let coordinate: CLLocationCoordinate2D
    let neighborhood: String
    let distance: Double
    let description: String
    let category: String
    let datePosted: Date
    let condition: String
    let images: [String]
    let sellerName: String
    let sellerType: String
    let sellerAvatar: String
    let tags: [String]
    
    static func == (lhs: Listing, rhs: Listing) -> Bool { return lhs.id == rhs.id }
}

// MARK: - Expanded Mock Data
let now = Date()
let initialMockListings: [Listing] = [
    Listing(
        title: "Vintage Mid-Century Chair", price: 120,
        coordinate: CLLocationCoordinate2D(latitude: 44.9848, longitude: -93.2743),
        neighborhood: "North Loop", distance: 1.2, description: "Beautiful authentic mid-century modern accent chair.",
        category: "Furniture", datePosted: now.addingTimeInterval(-86400 * 2), condition: "Good - Minor Wear",
        images: ["https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?q=80&w=800&auto=format&fit=crop"],
        sellerName: "Alex M.", sellerType: "Private Owner", sellerAvatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=200&auto=format&fit=crop", tags: ["home"]
    ),
    Listing(
        title: "MacBook Pro M1", price: 850,
        coordinate: CLLocationCoordinate2D(latitude: 44.9778, longitude: -93.2650),
        neighborhood: "Downtown", distance: 0.5, description: "Space Gray, 16GB RAM, perfectly maintained.",
        category: "Electronics", datePosted: now.addingTimeInterval(-3600 * 8), condition: "Like New",
        images: ["https://images.unsplash.com/photo-1517336714731-489689fd1ca8?q=80&w=800&auto=format&fit=crop"],
        sellerName: "Jordan T.", sellerType: "Private Owner", sellerAvatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=200&auto=format&fit=crop", tags: ["home"]
    ),
    Listing(
        title: "Sony 4K Smart TV", price: 250,
        coordinate: CLLocationCoordinate2D(latitude: 44.8897, longitude: -93.3501),
        neighborhood: "Edina", distance: 5.5, description: "55 inch Sony TV. Works perfectly, upgrading to larger size.",
        category: "Electronics", datePosted: now.addingTimeInterval(-3600 * 12), condition: "Excellent",
        images: ["https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?q=80&w=800&auto=format&fit=crop"],
        sellerName: "Chris K.", sellerType: "Private Owner", sellerAvatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200&auto=format&fit=crop", tags: ["search"]
    ),
    Listing(
        title: "Leather Chesterfield Sofa", price: 450,
        coordinate: CLLocationCoordinate2D(latitude: 45.0132, longitude: -93.1415),
        neighborhood: "Roseville", distance: 8.2, description: "Genuine leather, very comfortable. Must pick up.",
        category: "Furniture", datePosted: now.addingTimeInterval(-86400 * 1), condition: "Good - Minor Wear",
        images: ["https://images.unsplash.com/photo-1555041469-a586c61ea9bc?q=80&w=800&auto=format&fit=crop"],
        sellerName: "Morgan F.", sellerType: "Dealer", sellerAvatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop", tags: ["search"]
    ),
    Listing(
        title: "Vintage Denim Jacket", price: 45,
        coordinate: CLLocationCoordinate2D(latitude: 44.9250, longitude: -93.3150),
        neighborhood: "Linden Hills", distance: 4.1, description: "Classic Levi's wash, size medium.",
        category: "Clothing", datePosted: now.addingTimeInterval(-86400 * 3), condition: "Vintage",
        images: ["https://images.unsplash.com/photo-1576871337622-98d48d1cf531?q=80&w=800&auto=format&fit=crop"],
        sellerName: "Riley Q.", sellerType: "Private Owner", sellerAvatar: "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?q=80&w=200&auto=format&fit=crop", tags: ["search", "home"]
    ),
    Listing(
        title: "Board Game Collection", price: 30,
        coordinate: CLLocationCoordinate2D(latitude: 44.9811, longitude: -93.2355),
        neighborhood: "Dinkytown", distance: 2.8, description: "Includes Catan, Ticket to Ride, and Monopoly.",
        category: "Books & Games", datePosted: now.addingTimeInterval(-3600 * 24), condition: "Good",
        images: ["https://images.unsplash.com/photo-1610890716171-6b1bb98ffaed?q=80&w=800&auto=format&fit=crop"],
        sellerName: "Sam W.", sellerType: "Private Owner", sellerAvatar: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=200&auto=format&fit=crop", tags: ["search"]
    )
]
