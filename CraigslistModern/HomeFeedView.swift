import SwiftUI
import MapKit

struct HomeFeedView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: UserDefaults.standard.object(forKey: "savedLatitude") as? Double ?? 44.9778,
                longitude: UserDefaults.standard.object(forKey: "savedLongitude") as? Double ?? -93.2650
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    
    @State private var selectedListingID: UUID?
    @State private var isDetailPresented = false
    
    // FIX: State flag to ensure the empty state doesn't flash during initial network queries
    @State private var isFetching = true
    
    @AppStorage("homeViewMode") private var viewMode: ViewMode = .swipe
    @AppStorage("isNearbyMode") private var isNearbyMode = true
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 50.0
    @AppStorage("sortOption") private var sortOption: SortOption = .bestMatch
    @AppStorage("isSwipeViewEnabled") private var isSwipeViewEnabled = true
    @AppStorage("globalSearchText") private var globalSearchText = ""
    
    @State private var refreshTask: Task<Void, Never>? = nil
    
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var shortLocationName: String {
        appState.selectedLocation.components(separatedBy: ",").first ?? "your area"
    }
    
    var baseFilteredListings: [LiveListing] {
        var results = globalSearchText.isEmpty ? appState.listings : appState.searchResults
        
        let effectiveTopCat = appState.selectedTopCategory ?? (globalSearchText.isEmpty ? nil : appState.suggestedTopCategory)
        
        if let topCat = effectiveTopCat {
            results = results.filter { $0.category == topCat }
        }
        
        if let subCat = appState.selectedSubCategory {
            results = results.filter { $0.subCategory == subCat }
        }
        
        switch sortOption {
        case .bestMatch: break
        case .priceLowToHigh: results.sort { $0.price < $1.price }
        case .priceHighToLow: results.sort { $0.price > $1.price }
        case .closestFirst: break
        }
        return results
    }
    
    var homeListings: [LiveListing] {
        return baseFilteredListings.filter { listing in
            let isNotOwnItem = listing.sellerId != appState.currentUserID
            let isNotHidden = viewMode == .swipe ? true : !appState.hiddenIDs.contains(listing.id)
            
            return isNotOwnItem && isNotHidden
        }
    }
    
    var trendingListings: [LiveListing] {
        if !globalSearchText.isEmpty { return [] }
        return Array(homeListings.prefix(6))
    }
    
    var recentListings: [LiveListing] {
        if !globalSearchText.isEmpty { return homeListings }
        let trendingIDs = Set(trendingListings.map { $0.id })
        return homeListings.filter { !trendingIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(viewMode == .map ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
                    .sheet(isPresented: $isDetailPresented) {
                        ListingPagerView(listings: $appState.listings, filteredIDs: homeListings.map{$0.id}, selectedListingID: $selectedListingID)
                    }
                
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
                        GlassHeader(
                            searchText: $globalSearchText,
                            placeholder: "What are you looking for?",
                            onTapped: { appState.selectedTab = 1 },
                            onFetchStarted: { isFetching = true },
                            onFetchCompleted: { isFetching = false }
                        )
                        FilterAndViewBar(viewMode: $viewMode).padding(.top, 16)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        ScrollViewReader { proxy in
                            VStack(alignment: .leading, spacing: 24) {
                                FilterAndViewBar(viewMode: $viewMode)
                                    .padding(.top, 16)
                                    .id("TopMarker")
                                    .zIndex(100)
                                
                                if homeListings.isEmpty {
                                    // FIX: Gated the empty state so it doesn't flash during initial load
                                    if isFetching {
                                        VStack(spacing: 24) {
                                            Spacer().frame(height: 60)
                                            ProgressView().scaleEffect(1.5).tint(Theme.Colors.primary)
                                            Text("Finding local items...")
                                                .font(Theme.Typography.body(weight: .semibold))
                                                .foregroundColor(Theme.Colors.textSecondary)
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity)
                                    } else {
                                        emptyStateView()
                                    }
                                } else {
                                    sectionedFeed(viewMode: viewMode, proxy: proxy)
                                        .zIndex(1)
                                }
                                Spacer(minLength: 40)
                            }
                        }
                    }
                    .refreshable {
                        triggerRefresh(resetFilters: false)
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                    .safeAreaInset(edge: .top) {
                        GlassHeader(
                            searchText: $globalSearchText,
                            placeholder: "What are you looking for?",
                            onTapped: { appState.selectedTab = 1 },
                            onFetchStarted: { isFetching = true },
                            onFetchCompleted: { isFetching = false }
                        )
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            if !isSwipeViewEnabled && viewMode == .swipe { viewMode = .gallery }
            if nearbyDistance < 5.0 { nearbyDistance = 50.0 }
            
            // FIX: Prevent infinite loading if we already have data
            if appState.listings.isEmpty {
                triggerRefresh(resetFilters: false)
            } else {
                isFetching = false
            }
        }
        .onChange(of: isSwipeViewEnabled) { newValue in if !newValue && viewMode == .swipe { viewMode = .gallery } }
        .onChange(of: globalSearchText) { _, newValue in
            if !newValue.isEmpty { Task { await appState.fetchSearchResults(query: newValue) } }
        }
        .onChange(of: appState.savedLatitude) { _, _ in handleLocationChange() }
        .onChange(of: appState.savedLongitude) { _, _ in handleLocationChange() }
        .onChange(of: nearbyDistance) { _, _ in triggerRefresh(resetFilters: false) }
        .onChange(of: isNearbyMode) { _, _ in triggerRefresh(resetFilters: false) }
    }
    
    private func handleLocationChange() {
        cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: appState.savedLatitude, longitude: appState.savedLongitude),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        ))
        triggerRefresh(resetFilters: true)
    }
    
    private func triggerRefresh(resetFilters: Bool) {
        if resetFilters {
            appState.selectedTopCategory = nil
            appState.selectedSubCategory = nil
            globalSearchText = ""
        }
        
        isFetching = true
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
            
            let fetchRadius = isNearbyMode ? (nearbyDistance > 0 ? nearbyDistance : 50.0) : 5000.0
            await appState.fetchListings(longitude: appState.savedLongitude, latitude: appState.savedLatitude, radiusInMiles: fetchRadius)
            await appState.fetchDashboardListings()
            if !globalSearchText.isEmpty { await appState.fetchSearchResults(query: globalSearchText) }
            
            await MainActor.run { isFetching = false }
        }
    }
    
    @ViewBuilder
    private func emptyStateView() -> some View {
        VStack(spacing: 24) {
            
            let hasFilters = appState.selectedTopCategory != nil || appState.selectedSubCategory != nil || !globalSearchText.isEmpty
            let canExpand = isNearbyMode && nearbyDistance < 50.0
            
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No results found",
                description: "We couldn't find any items matching your criteria in this area.",
                buttonTitle: canExpand ? "Expand Search to 50 Miles" : (hasFilters ? "Clear All Filters" : nil),
                buttonAction: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    withAnimation {
                        if canExpand {
                            nearbyDistance = 50.0
                        } else if hasFilters {
                            appState.selectedTopCategory = nil
                            appState.selectedSubCategory = nil
                            globalSearchText = ""
                        }
                    }
                }
            ).padding(.top, 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func sectionedFeed(viewMode: ViewMode, proxy: ScrollViewProxy) -> some View {
        if viewMode == .swipe {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(globalSearchText.isEmpty ? "Top Results" : "Search Results")
                        .font(.custom("Montserrat", size: 22).weight(.bold))
                    Spacer()
                    Text("\(homeListings.count) results")
                        .font(.custom("NunitoSans", size: 14).weight(.semibold))
                        .foregroundColor(.secondary)
                }.padding(.horizontal, 16)
                
                SwipeFeedView(listings: homeListings, selectedListingID: $selectedListingID, isDetailPresented: $isDetailPresented, proxy: proxy, isSearch: !globalSearchText.isEmpty)
                    .frame(height: 520)
            }
            .padding(.top, 8)
        } else {
            VStack(alignment: .leading, spacing: 24) {
                if !trendingListings.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(globalSearchText.isEmpty ? "Trending" : "Top Results").font(.custom("Montserrat", size: 22).weight(.bold))
                            Spacer()
                            Text("\(trendingListings.count) results").font(.custom("NunitoSans", size: 14).weight(.semibold)).foregroundColor(.secondary)
                        }.padding(.horizontal, 16)
                        feedContent(for: viewMode, listings: trendingListings, proxy: proxy)
                    }.id("TrendingSection")
                }
                
                if !recentListings.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(globalSearchText.isEmpty ? "More" : "More Results").font(.custom("Montserrat", size: 22).weight(.bold))
                            Spacer()
                            Text("\(recentListings.count) results").font(.custom("NunitoSans", size: 14).weight(.semibold)).foregroundColor(.secondary)
                        }.padding(.horizontal, 16)
                        feedContent(for: viewMode, listings: recentListings, proxy: proxy)
                    }.id("RecentSection")
                }
            }
        }
    }
    
    @ViewBuilder
    private func feedContent(for mode: ViewMode, listings: [LiveListing], proxy: ScrollViewProxy? = nil) -> some View {
        if mode == .grid {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(listings, id: \.id) { listing in
                    GridListingCard(listing: listing).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                }
            }.padding(.horizontal, 16)
        } else if mode == .gallery {
            LazyVStack(spacing: 24) {
                ForEach(listings, id: \.id) { listing in
                    GalleryListingCard(listing: listing).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                }
            }.padding(.horizontal, 16)
        } else if mode == .list {
            LazyVStack(spacing: 16) {
                ForEach(listings, id: \.id) { listing in
                    ListListingCard(listing: listing).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                }
            }.padding(.horizontal, 16)
        }
    }
}
