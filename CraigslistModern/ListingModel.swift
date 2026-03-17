import Foundation
import CoreLocation
import SwiftUI

// Adaptive Craigslist Purple (Deep #551A8B in Light Mode, Luminous in Dark Mode)
extension Color {
    static let craigslistPurple = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.65, green: 0.40, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.33, green: 0.10, blue: 0.55, alpha: 1.0)
    })
}

// MARK: - Global App State
class AppState: ObservableObject {
    @Published var listings: [Listing] = initialMockListings
    @Published var favoriteIDs: Set<UUID> = []
    @Published var isLoading: Bool = false
    
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
    @Published var selectedTopCategory: String? = "For Sale"
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
    
    init() {
        fetchListings()
    }
    
    // MARK: - Network Fetch
    func fetchListings() {
        guard let url = URL(string: "https://gist.githubusercontent.com/CoriyonArrington/b8faab1369f51cef1f7d63631b9a5762/raw/mock-data.json") else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let decodedListings = try JSONDecoder().decode([MockarooListing].self, from: data)
                
                let fallbackImages = [
                    "https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?q=80&w=800&auto=format&fit=crop",
                    "https://images.unsplash.com/photo-1517336714731-489689fd1ca8?q=80&w=800&auto=format&fit=crop",
                    "https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?q=80&w=800&auto=format&fit=crop",
                    "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?q=80&w=800&auto=format&fit=crop",
                    "https://images.unsplash.com/photo-1576871337622-98d48d1cf531?q=80&w=800&auto=format&fit=crop"
                ]
                let fallbackCategories = ["Furniture", "Electronics", "Clothing", "Bikes", "Home Goods"]
                
                let mappedListings = decodedListings.map { mock in
                    let safeCategory = (mock.category?.contains("error") == true || mock.category == nil) ? fallbackCategories.randomElement()! : mock.category!
                    let safeImage = (mock.images?.contains("error") == true || mock.images == nil) ? fallbackImages.randomElement()! : mock.images!
                    let safeAvatar = mock.sellerAvatar ?? "https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200"
                    
                    return Listing(
                        id: UUID(uuidString: mock.id) ?? UUID(),
                        title: mock.title ?? "Untitled Listing",
                        price: Int(mock.price),
                        coordinate: CLLocationCoordinate2D(
                            latitude: 44.9778 + Double.random(in: -0.05...0.05),
                            longitude: -93.2650 + Double.random(in: -0.05...0.05)
                        ),
                        neighborhood: mock.neighborhood,
                        distance: Double.random(in: 0.5...10.0),
                        description: mock.description ?? "No description provided.",
                        category: safeCategory,
                        datePosted: Date().addingTimeInterval(-Double.random(in: 3600...86400*5)),
                        condition: ["Like New", "Good", "Excellent", "Used"].randomElement()!,
                        images: [safeImage],
                        sellerName: mock.sellerName,
                        sellerType: "Private Owner",
                        sellerAvatar: safeAvatar,
                        tags: ["home", "search"]
                    )
                }
                
                DispatchQueue.main.async {
                    self.listings = mappedListings
                    self.isLoading = false
                }
            } catch {
                print("Failed to decode JSON: \(error)")
            }
        }.resume()
    }
    
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
        
        if q.isEmpty {
            selectedTopCategory = "For Sale"
            selectedSubCategory = nil
            return
        }
        
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
    let id: UUID
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

struct MockarooListing: Codable {
    let id: String
    let title: String?
    let price: Double
    let neighborhood: String
    let description: String?
    let sellerName: String
    let category: String?
    let images: String?
    let sellerAvatar: String?
}

// MARK: - Initial Placholder State
let initialMockListings: [Listing] = []
