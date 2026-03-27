import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedListingID: UUID?
    @State private var isDetailPresented = false
    @State private var searchText = ""
    @State private var listingToEdit: Listing?
    
    let options = ["Favorites", "My Listings", "Voted", "Hidden"]
    
    // Elevated to AppStorage so PostView can trigger a jump directly to "My Listings"
    @AppStorage("favoritesTabSelection") private var statusSelection = "Favorites"
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var myListings: [Listing] {
        appState.listings.filter { $0.sellerName == "Coriyon Arrington" }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                CraigslistPattern()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                        
                        // Custom Scrollable Segmented Bar
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.small) {
                                ForEach(options, id: \.self) { option in
                                    Button(action: {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            statusSelection = option
                                        }
                                    }) {
                                        Text(option)
                                            .font(Theme.Typography.caption(weight: statusSelection == option ? .bold : .semibold))
                                            .padding(.horizontal, Theme.Spacing.medium)
                                            .frame(minHeight: 38)
                                            .background(statusSelection == option ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                                            .foregroundColor(statusSelection == option ? Color(.systemBackground) : .primary)
                                            .cornerRadius(Theme.Radius.small)
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.screenMargin)
                        }
                        .padding(.top, Theme.Spacing.medium)
                        
                        // Content Rendering
                        if statusSelection == "My Listings" {
                            renderMyListings()
                        } else {
                            renderTargetListings()
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
                .safeAreaInset(edge: .top) {
                    GlassHeader(searchText: $searchText, placeholder: "Search activity")
                }
            }
            .sheet(isPresented: $isDetailPresented) {
                if statusSelection == "My Listings" {
                    ListingPagerView(listings: $appState.listings, filteredIDs: myListings.map { $0.id }, selectedListingID: $selectedListingID)
                } else {
                    ListingPagerView(listings: $appState.listings, filteredIDs: Array(getTargetIDs()), selectedListingID: $selectedListingID)
                }
            }
            .sheet(item: $listingToEdit) { listing in
                EditListingView(listing: listing)
            }
        }
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func renderMyListings() -> some View {
        if myListings.isEmpty {
            VStack(spacing: Theme.Spacing.medium) {
                Image(systemName: "tag.slash.fill").font(.system(size: 48)).foregroundColor(.gray)
                Text("You haven't posted anything yet.")
                    .font(Theme.Typography.body())
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 100)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Text("Your Posts")
                    .font(Theme.Typography.headingM())
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                
                if let first = myListings.first {
                    FavoriteHeroCard(listing: first)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedListingID = first.id
                            isDetailPresented = true
                        }
                        .contextMenu {
                            Button { listingToEdit = first } label: { Label("Edit Post", systemImage: "pencil") }
                            Button(role: .destructive) { deleteListing(first) } label: { Label("Delete Post", systemImage: "trash") }
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                }
                
                LazyVGrid(columns: columns, spacing: Theme.Spacing.medium) {
                    ForEach(myListings.dropFirst(), id: \.id) { listing in
                        FavoriteGridCard(listing: listing)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedListingID = listing.id
                                isDetailPresented = true
                            }
                            .contextMenu {
                                Button { listingToEdit = listing } label: { Label("Edit Post", systemImage: "pencil") }
                                Button(role: .destructive) { deleteListing(listing) } label: { Label("Delete Post", systemImage: "trash") }
                            }
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenMargin)
            }
        }
    }
    
    @ViewBuilder
    private func renderTargetListings() -> some View {
        let targetIDs = getTargetIDs()
        
        if targetIDs.isEmpty {
            VStack(spacing: Theme.Spacing.medium) {
                Image(systemName: getEmptyIcon()).font(.system(size: 48)).foregroundColor(.gray)
                Text("No \(statusSelection.lowercased()) items yet")
                    .font(Theme.Typography.body())
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 100)
        } else {
            let filteredListings = appState.listings.filter { targetIDs.contains($0.id) }
            
            Text(getSectionTitle())
                .font(Theme.Typography.headingM())
                .padding(.horizontal, Theme.Spacing.screenMargin)
            
            if let first = filteredListings.first {
                FavoriteHeroCard(listing: first)
                    .onTapGesture { selectedListingID = first.id; isDetailPresented = true }
                    .padding(.horizontal, Theme.Spacing.screenMargin)
            }
            
            LazyVGrid(columns: columns, spacing: Theme.Spacing.medium) {
                ForEach(filteredListings.dropFirst(), id: \.id) { listing in
                    FavoriteGridCard(listing: listing)
                        .onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
        }
    }
    
    // MARK: - Logic Helpers
    
    private func deleteListing(_ listing: Listing) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation {
            appState.listings.removeAll { $0.id == listing.id }
        }
        appState.triggerToast(message: "Listing Deleted")
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
