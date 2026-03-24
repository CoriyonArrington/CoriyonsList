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
    var listing: Listing
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(.systemGray5)
                    }
                }
            } else {
                Color(.systemGray5)
            }
            
            LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .center, endPoint: .bottom)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(listing.price)").font(.custom("Montserrat", size: 22).weight(.heavy)).foregroundColor(.white)
                Text(listing.title).font(.custom("Montserrat", size: 18).weight(.bold)).foregroundColor(.white).lineLimit(2)
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct FavoriteGridCard: View {
    var listing: Listing
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                    else { Color(.systemGray5) }
                }
                .frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(listing.price)").font(.custom("Montserrat", size: 16).weight(.bold)).foregroundColor(.primary)
                Text(listing.title).font(.custom("NunitoSans", size: 14).weight(.regular)).foregroundColor(.secondary).lineLimit(1)
                Text("\(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)").font(.custom("NunitoSans", size: 12).weight(.regular)).foregroundColor(.gray).lineLimit(1)
            }
        }
        .background(Color(.systemBackground))
    }
}
