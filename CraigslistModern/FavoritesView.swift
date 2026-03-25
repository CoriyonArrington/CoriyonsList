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
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                CraigslistPattern()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        StatusActionBar(options: ["Favorites", "Voted", "Hidden"], selection: $statusSelection)
                            .padding(.top, 16)
                        
                        let targetIDs = getTargetIDs()
                        
                        if targetIDs.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: getEmptyIcon()).font(.system(size: 48)).foregroundColor(.gray)
                                Text("No \(statusSelection.lowercased()) items yet").font(.custom("NunitoSans", size: 20).weight(.regular)).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 100)
                        } else {
                            let filteredListings = appState.listings.filter { targetIDs.contains($0.id) }
                            
                            Text(getSectionTitle())
                                .font(.custom("Montserrat", size: 22).weight(.bold))
                                .padding(.horizontal, 16)
                            
                            if let first = filteredListings.first {
                                FavoriteHeroCard(listing: first)
                                    .onTapGesture { selectedListingID = first.id; isDetailPresented = true }
                                    .padding(.horizontal, 16)
                            }
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(filteredListings.dropFirst(), id: \.id) { listing in
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
                    GlassHeader(searchText: $searchText, placeholder: "Search activity")
                }
            }
            .sheet(isPresented: $isDetailPresented) {
                ListingPagerView(listings: $appState.listings, filteredIDs: Array(getTargetIDs()), selectedListingID: $selectedListingID)
            }
        }
    }
    
    private func getTargetIDs() -> Set<UUID> {
        if statusSelection == "Favorites" { return appState.favoriteIDs }
        if statusSelection == "Voted" { return appState.votedIDs }
        return appState.hiddenIDs
    }
    
    private func getEmptyIcon() -> String {
        if statusSelection == "Favorites" { return "heart.slash" }
        if statusSelection == "Voted" { return "hand.thumbsup" }
        return "eye.slash"
    }
    
    private func getSectionTitle() -> String {
        if statusSelection == "Favorites" { return "Your Saved Items" }
        if statusSelection == "Voted" { return "Your Upvoted Items" }
        return "Hidden Items"
    }
}
