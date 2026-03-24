import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedListingID: UUID?
    @State private var isDetailPresented = false
    @State private var searchText = ""
    @State private var statusSelection = "Favorites"
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    StatusActionBar(options: ["Favorites", "Hidden"], selection: $statusSelection)
                        .padding(.top, 16)
                    
                    if appState.favoriteIDs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "heart.slash").font(.system(size: 48)).foregroundColor(.gray)
                            Text("No favorites yet").font(.custom("NunitoSans", size: 20).weight(.regular)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 100)
                    } else {
                        let favListings = appState.listings.filter { appState.favoriteIDs.contains($0.id) }
                        
                        Text("Your Saved Items")
                            .font(.custom("Montserrat", size: 28).weight(.bold))
                            .padding(.horizontal, 16)
                        
                        if let first = favListings.first {
                            FavoriteHeroCard(listing: first)
                                .onTapGesture { selectedListingID = first.id; isDetailPresented = true }
                                .padding(.horizontal, 16)
                        }
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(favListings.dropFirst()) { listing in
                                FavoriteGridCard(listing: listing)
                                    .onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    Spacer(minLength: 40)
                }
            }
            .safeAreaInset(edge: .top) {
                GlassHeader(searchText: $searchText, placeholder: "Search favorites")
            }
            .sheet(isPresented: $isDetailPresented) {
                ListingPagerView(listings: $appState.listings, filteredIDs: Array(appState.favoriteIDs), selectedListingID: $selectedListingID)
            }
        }
    }
}

private struct FavoriteHeroCard: View {
    @EnvironmentObject var appState: AppState
    var listing: Listing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(.systemGray5)
                .frame(height: 300)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
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
                    Text(listing.distance < 5.0 ? "Nearby" : "Just Listed")
                        .font(.custom("NunitoSans", size: 11).weight(.bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.ultraThickMaterial)
                        .clipShape(Capsule())
                        .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: appState.isFavorited(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(appState.isFavorited(listing.id) ? .red : .primary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .padding(12)
                        .onTapGesture {
                            appState.toggleFavorite(listing.id)
                        }
                }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text(listing.title)
                        .font(.custom("Montserrat", size: 21).weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("$\(listing.price)")
                        .font(.custom("Montserrat", size: 21).weight(.heavy))
                        .foregroundColor(.green)
                }
                
                HStack(alignment: .center, spacing: 12) {
                    if let url = URL(string: listing.sellerAvatar) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            else { Color(.systemGray4) }
                        }
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                    } else {
                        Circle().fill(Color(.systemGray4)).frame(width: 20, height: 20)
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.yellow)
                        Text("\(String(format: "%.1f", listing.sellerRating)) (\(listing.reviewCount))")
                            .font(.custom("NunitoSans", size: 12).weight(.bold))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .font(.custom("NunitoSans", size: 12).weight(.bold))
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)")
                        .font(.custom("NunitoSans", size: 15).weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

private struct FavoriteGridCard: View {
    @EnvironmentObject var appState: AppState
    var listing: Listing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(.systemGray5)
                .frame(height: 160)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
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
                    Text(listing.distance < 5.0 ? "Nearby" : "Just Listed")
                        .font(.custom("NunitoSans", size: 10).weight(.bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThickMaterial)
                        .clipShape(Capsule())
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: appState.isFavorited(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(appState.isFavorited(listing.id) ? .red : .primary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .padding(8)
                        .onTapGesture { appState.toggleFavorite(listing.id) }
                }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(listing.title)
                        .font(.custom("Montserrat", size: 15).weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("$\(listing.price)")
                        .font(.custom("Montserrat", size: 16).weight(.heavy))
                        .foregroundColor(.green)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    if let url = URL(string: listing.sellerAvatar) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            else { Color(.systemGray4) }
                        }
                        .frame(width: 14, height: 14)
                        .clipShape(Circle())
                    } else {
                        Circle().fill(Color(.systemGray4)).frame(width: 14, height: 14)
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow)
                        Text("\(String(format: "%.1f", listing.sellerRating))").font(.custom("NunitoSans", size: 11).weight(.bold)).foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .font(.custom("NunitoSans", size: 11).weight(.bold))
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", listing.distance)) mi")
                        .font(.custom("NunitoSans", size: 13).weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
