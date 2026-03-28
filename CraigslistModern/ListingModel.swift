import Foundation
import CoreLocation
import SwiftUI

extension Color {
    static let craigslistPurple = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.65, green: 0.40, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.33, green: 0.10, blue: 0.55, alpha: 1.0)
    })
    
    static let craigslistGreen = Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
            : UIColor(red: 0.12, green: 0.55, blue: 0.22, alpha: 1.0)
    })
}

enum ViewMode: String, CaseIterable {
    case swipe = "Swipe"
    case gallery = "Gallery"
    case grid = "Grid"
    case list = "List"
    case map = "Map"
    
    var icon: String {
        switch self {
        case .swipe: return "rectangle.stack.fill"
        case .gallery: return "rectangle.grid.1x2.fill"
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .map: return "map"
        }
    }
}

// Keeping the original Listing struct around temporarily
// so you can migrate your sub-views to LiveListing one by one.
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
    let sellerRating: Double
    let reviewCount: Int
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
    let sellerRating: Double?
    let reviewCount: Int?
}

let initialMockListings: [Listing] = []
