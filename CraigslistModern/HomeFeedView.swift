import SwiftUI
import MapKit

struct HomeFeedView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 44.9778, longitude: -93.2650), span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15))
    )
    @State private var selectedListingID: UUID?
    @State private var isDetailPresented = false
    
    @State private var viewMode: ViewMode = .swipe
    @AppStorage("isNearbyMode") private var isNearbyMode = true
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    @AppStorage("sortOption") private var sortOption: SortOption = .bestMatch
    @AppStorage("isSwipeViewEnabled") private var isSwipeViewEnabled = true
    
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    let emptyStateCategories: [(name: String, icon: String)] = [
        ("For Sale", "tag.fill"),
        ("Housing", "house.fill"),
        ("Services", "briefcase.fill"),
        ("Jobs", "person.2.fill")
    ]
    
    var baseFilteredListings: [LiveListing] {
        var results = appState.listings.filter { $0.tags?.contains("home") == true }
        
        if let topCat = appState.selectedTopCategory {
            if let validSubs = appState.subCategories[topCat] {
                results = results.filter { validSubs.contains($0.category ?? "") }
            }
        }
        
        if let subCat = appState.selectedSubCategory {
            results = results.filter { $0.category == subCat }
        }
        
        switch sortOption {
        case .bestMatch: break
        case .priceLowToHigh: results.sort { $0.price < $1.price }
        case .priceHighToLow: results.sort { $0.price > $1.price }
        case .closestFirst: break // Handled by DB Radius natively
        }
        
        return results
    }
    
    var homeListings: [LiveListing] {
        baseFilteredListings.filter {
            !appState.hiddenIDs.contains($0.id) &&
            !appState.votedIDs.contains($0.id) &&
            !appState.favoriteIDs.contains($0.id)
        }
    }
    
    var trendingListings: [LiveListing] {
        return Array(homeListings.prefix(6))
    }
    
    var recentListings: [LiveListing] {
        let trendingIDs = Set(trendingListings.map { $0.id })
        return homeListings.filter { !trendingIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(viewMode == .map ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewMode != .map { CraigslistPattern() }
                
                if viewMode == .map {
                    MapFeedView(
                        cameraPosition: $cameraPosition,
                        listings: homeListings,
                        trendingListings: trendingListings,
                        recentListings: recentListings,
                        selectedListingID: $selectedListingID,
                        isDetailPresented: $isDetailPresented
                    )
                    
                    VStack(spacing: 0) {
                        GlassHeader(searchText: .constant(""), placeholder: "What are you looking for?", onTapped: { appState.selectedTab = 1 })
                        FilterAndViewBar(viewMode: $viewMode, isNearbyMode: $isNearbyMode)
                            .padding(.top, 16)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        ScrollViewReader { proxy in
                            VStack(alignment: .leading, spacing: 24) {
                                FilterAndViewBar(viewMode: $viewMode, isNearbyMode: $isNearbyMode)
                                    .padding(.top, 16)
                                    .id("TopMarker")
                                
                                if homeListings.isEmpty {
                                    emptyStateView()
                                } else {
                                    sectionedFeed(viewMode: viewMode, proxy: proxy)
                                }
                                Spacer(minLength: 40)
                            }
                        }
                    }
                    .refreshable {
                        if isNearbyMode && nearbyDistance >= 50.0 { nearbyDistance = 3.0 }
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    .safeAreaInset(edge: .top) {
                        GlassHeader(searchText: .constant(""), placeholder: "What are you looking for?", onTapped: { appState.selectedTab = 1 })
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isDetailPresented) {
                ListingPagerView(listings: $appState.listings, filteredIDs: homeListings.map{$0.id}, selectedListingID: $selectedListingID)
            }
        }
        .onAppear {
            if !isSwipeViewEnabled && viewMode == .swipe { viewMode = .gallery }
        }
        .onChange(of: isSwipeViewEnabled) { newValue in
            if !newValue && viewMode == .swipe { viewMode = .gallery }
        }
    }
    
    @ViewBuilder
    private func emptyStateView() -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Theme.Colors.primary.opacity(0.15)).frame(width: 96, height: 96)
                Image(systemName: "magnifyingglass").font(.system(size: 48)).foregroundColor(Theme.Colors.primary)
            }
            VStack(spacing: 8) {
                Text("No items nearby").font(Theme.Typography.headingM())
                Text("We couldn't find any more items in this radius. Try adjusting your filters or explore these popular categories instead:")
                    .font(Theme.Typography.body())
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(emptyStateCategories, id: \.name) { cat in
                    Button(action: {
                        withAnimation {
                            appState.selectedTopCategory = cat.name
                            appState.selectedSubCategory = nil
                            nearbyDistance = 25.0
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: cat.icon).font(.system(size: 24))
                            Text(cat.name).font(Theme.Typography.body(weight: .bold))
                        }
                        .foregroundColor(Theme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.Colors.surfaceCard)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
    
    @ViewBuilder
    private func sectionedFeed(viewMode: ViewMode, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if !trendingListings.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Trending Nearby").font(.custom("Montserrat", size: 22).weight(.bold))
                        Spacer()
                        Text("\(trendingListings.count) results").font(.custom("NunitoSans", size: 14).weight(.semibold)).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    feedContent(for: viewMode, listings: trendingListings, proxy: proxy)
                }.id("TrendingSection")
            }
            
            if !recentListings.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("More Nearby").font(.custom("Montserrat", size: 22).weight(.bold))
                        Spacer()
                        Text("\(recentListings.count) results").font(.custom("NunitoSans", size: 14).weight(.semibold)).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    feedContent(for: viewMode, listings: recentListings, proxy: proxy)
                }.id("RecentSection")
            }
        }
    }
    
    @ViewBuilder
    private func feedContent(for mode: ViewMode, listings: [LiveListing], proxy: ScrollViewProxy? = nil) -> some View {
        if mode == .grid {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(listings, id: \.id) { listing in
                    GridListingCard(listing: listing)
                        .onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                }
            }.padding(.horizontal, 16)
        } else if mode == .gallery {
            LazyVStack(spacing: 24) {
                ForEach(listings, id: \.id) { listing in
                    GalleryListingCard(listing: listing)
                        .onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                }
            }.padding(.horizontal, 16)
        } else if mode == .list {
            LazyVStack(spacing: 16) {
                ForEach(listings, id: \.id) { listing in
                    ListListingCard(listing: listing)
                        .onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                }
            }.padding(.horizontal, 16)
        } else if mode == .swipe {
            SwipeFeedView(listings: listings, selectedListingID: $selectedListingID, isDetailPresented: $isDetailPresented, proxy: proxy)
                .frame(height: 480)
        }
    }
}
