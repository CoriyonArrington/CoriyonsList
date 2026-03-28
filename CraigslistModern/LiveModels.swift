import Foundation

struct LiveProfile: Codable, Identifiable {
    let id: UUID
    let fullName: String?
    let avatarUrl: String?
    let rating: Double?
    let reviewCount: Int?
    let sellerType: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case rating
        case reviewCount = "review_count"
        case sellerType = "seller_type"
        case createdAt = "created_at"
    }
}

struct LiveListing: Codable, Identifiable, Equatable {
    let id: UUID
    let sellerId: UUID
    let title: String
    let price: Int
    let description: String?
    let category: String?
    let subCategory: String?
    let condition: String?
    let neighborhood: String?
    let images: [String]?
    let tags: [String]?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case sellerId = "seller_id"
        case title
        case price
        case description
        case category
        case subCategory = "sub_category"
        case condition
        case neighborhood
        case images
        case tags
        case createdAt = "created_at"
    }
}
