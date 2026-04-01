import SwiftUI
import Supabase

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedListingID: UUID?
    @State private var isDetailPresented = false
    @State private var searchText = ""
    
    @State private var listingToEdit: LiveListing?
    @State private var listingToDelete: LiveListing?
    
    let options = ["Favorites", "My Listings", "Voted", "Hidden"]
    @AppStorage("favoritesTabSelection") private var statusSelection = "Favorites"
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    // FIX: Decoupled from local feed. Now pulls from the global super-array.
    var myListings: [LiveListing] {
        guard let currentUserID = appState.currentUserID else { return [] }
        return appState.allKnownListings
            .filter { $0.sellerId == currentUserID }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                CraigslistPattern()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                        
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
                                            // FIX: Updated background and text color to match Action Bar styling
                                            .background(statusSelection == option ? Theme.Colors.primary : Color(.systemGray5))
                                            .foregroundColor(statusSelection == option ? .white : .primary)
                                            .cornerRadius(Theme.Radius.small)
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.screenMargin)
                        }
                        .padding(.top, Theme.Spacing.medium)
                        
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
                    ListingPagerView(listings: .constant(appState.allKnownListings), filteredIDs: myListings.map { $0.id }, selectedListingID: $selectedListingID)
                } else {
                    ListingPagerView(listings: .constant(appState.allKnownListings), filteredIDs: Array(getTargetIDs()), selectedListingID: $selectedListingID)
                }
            }
            .sheet(item: $listingToEdit) { listing in
                EditListingView(listing: listing)
            }
            .alert("Delete Listing", isPresented: Binding(
                get: { listingToDelete != nil },
                set: { if !$0 { listingToDelete = nil } }
            ), presenting: listingToDelete) { listing in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    appState.deleteListing(listing.id)
                }
            } message: { listing in
                Text("Are you sure you want to permanently delete '\(listing.title)'? This action cannot be undone.")
            }
        }
    }
    
    @ViewBuilder
    private func renderMyListings() -> some View {
        if myListings.isEmpty {
            EmptyStateView(
                icon: "tag.slash.fill",
                title: "No Posts Yet",
                description: "You haven't posted anything yet.",
                buttonTitle: "Post Your First Item",
                buttonAction: { appState.selectedTab = 2 }
            )
            .padding(.top, 100)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Text("Your Posts").font(Theme.Typography.headingM()).padding(.horizontal, Theme.Spacing.screenMargin)
                
                if let first = myListings.first {
                    FavoriteHeroCard(listing: first)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedListingID = first.id; isDetailPresented = true }
                        .contextMenu {
                            Button { listingToEdit = first } label: { Label("Edit Post", systemImage: "pencil") }
                            Button(role: .destructive) { listingToDelete = first } label: { Label("Delete Post", systemImage: "trash") }
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                }
                
                LazyVGrid(columns: columns, spacing: Theme.Spacing.medium) {
                    ForEach(myListings.dropFirst(), id: \.id) { listing in
                        FavoriteGridCard(listing: listing)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                            .contextMenu {
                                Button { listingToEdit = listing } label: { Label("Edit Post", systemImage: "pencil") }
                                Button(role: .destructive) { listingToDelete = listing } label: { Label("Delete Post", systemImage: "trash") }
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
            EmptyStateView(icon: getEmptyIcon(), title: getEmptyTitle(), description: getEmptyDescription(), buttonTitle: "Browse Trending Items", buttonAction: { appState.selectedTab = 0 }).padding(.top, 100)
        } else {
            // FIX: Pulls from global known arrays
            let filteredListings = appState.allKnownListings.filter { targetIDs.contains($0.id) }
            
            Text(getSectionTitle()).font(Theme.Typography.headingM()).padding(.horizontal, Theme.Spacing.screenMargin)
            
            if let first = filteredListings.first {
                FavoriteHeroCard(listing: first).onTapGesture { selectedListingID = first.id; isDetailPresented = true }.padding(.horizontal, Theme.Spacing.screenMargin)
            }
            
            LazyVGrid(columns: columns, spacing: Theme.Spacing.medium) {
                ForEach(filteredListings.dropFirst(), id: \.id) { listing in
                    FavoriteGridCard(listing: listing).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
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
    private func getEmptyTitle() -> String {
        if statusSelection == "Favorites" { return "No favorites yet" }
        if statusSelection == "Voted" { return "No upvotes yet" }
        return "No hidden items"
    }
    private func getEmptyDescription() -> String {
        if statusSelection == "Favorites" { return "Tap the heart on items you love to save them here for later." }
        if statusSelection == "Voted" { return "Listings you upvote to support will appear here." }
        return "Listings you hide from your feed will appear here."
    }
    private func getSectionTitle() -> String {
        if statusSelection == "Favorites" { return "Your Saved Items" }
        if statusSelection == "Voted" { return "Your Upvoted Items" }
        return "Hidden Items"
    }
}
