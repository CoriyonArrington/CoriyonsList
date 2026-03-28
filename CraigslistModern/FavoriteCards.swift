import SwiftUI

struct FavoriteHeroCard: View {
    @EnvironmentObject var appState: AppState
    var listing: LiveListing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(.systemGray5)
                .frame(height: 300)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images?.first, let url = URL(string: firstImageStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            }
                        }
                    }
                )
                .clipped()
                .overlay(
                    LinearGradient(gradient: Gradient(colors: [.black.opacity(0.3), .clear]), startPoint: .top, endPoint: .center)
                )
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 8) {
                        if let createdAt = listing.createdAt, createdAt >= Date().addingTimeInterval(-86400) {
                            Text("Just Listed").font(.custom("NunitoSans", size: 11).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 10).padding(.vertical, 6).background(.ultraThickMaterial).clipShape(Capsule())
                        }
                    }.padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: appState.favoriteIDs.contains(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                        .frame(width: 36, height: 36)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .padding(12)
                        .onTapGesture { appState.toggleFavorite(listing.id) }
                }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text(listing.title).font(.custom("Montserrat", size: 21).weight(.bold)).foregroundColor(.primary).lineLimit(1)
                    Spacer()
                    Text("$\(listing.price)").font(.custom("Montserrat", size: 21).weight(.heavy)).foregroundColor(Color.craigslistGreen)
                }
                
                HStack(alignment: .center, spacing: 8) {
                    Text(listing.neighborhood ?? "Local Area")
                        .font(.custom("NunitoSans", size: 15).weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

struct FavoriteGridCard: View {
    @EnvironmentObject var appState: AppState
    var listing: LiveListing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(.systemGray5)
                .frame(height: 160)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images?.first, let url = URL(string: firstImageStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            }
                        }
                    }
                )
                .clipped()
                .overlay(
                    LinearGradient(gradient: Gradient(colors: [.black.opacity(0.3), .clear]), startPoint: .top, endPoint: .center)
                )
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        if let createdAt = listing.createdAt, createdAt >= Date().addingTimeInterval(-86400) {
                            Text("New").font(.custom("NunitoSans", size: 10).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThickMaterial).clipShape(Capsule())
                        }
                    }.padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: appState.favoriteIDs.contains(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                        .frame(width: 28, height: 28)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .padding(8)
                        .onTapGesture { appState.toggleFavorite(listing.id) }
                }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(listing.title).font(.custom("Montserrat", size: 15).weight(.bold)).foregroundColor(.primary).lineLimit(1)
                    Spacer()
                    Text("$\(listing.price)").font(.custom("Montserrat", size: 16).weight(.heavy)).foregroundColor(Color.craigslistGreen)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    Text(listing.neighborhood ?? "Local Area")
                        .font(.custom("NunitoSans", size: 11).weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
