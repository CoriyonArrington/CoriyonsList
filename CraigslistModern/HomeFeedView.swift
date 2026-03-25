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
    
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var baseFilteredListings: [Listing] {
        var results = appState.listings.filter { $0.tags.contains("home") }
        
        if let topCat = appState.selectedTopCategory {
            if let validSubs = appState.subCategories[topCat] {
                results = results.filter { validSubs.contains($0.category) }
            }
        }
        
        if let subCat = appState.selectedSubCategory {
            results = results.filter { $0.category == subCat }
        }
        
        if isNearbyMode {
            results = results.filter { $0.distance <= nearbyDistance }
        }
        
        return results
    }
    
    var trendingListings: [Listing] {
        Array(baseFilteredListings.prefix(6)).filter {
            !appState.hiddenIDs.contains($0.id) &&
            !appState.votedIDs.contains($0.id) &&
            !appState.favoriteIDs.contains($0.id)
        }
    }
    
    var recentListings: [Listing] {
        let trendingIDs = Set(baseFilteredListings.prefix(6).map { $0.id })
        
        return baseFilteredListings.filter { $0.datePosted >= Date().addingTimeInterval(-86400) }
            .filter {
                !trendingIDs.contains($0.id) &&
                !appState.hiddenIDs.contains($0.id) &&
                !appState.votedIDs.contains($0.id) &&
                !appState.favoriteIDs.contains($0.id)
            }
    }
    
    var homeListings: [Listing] {
        baseFilteredListings.filter {
            !appState.hiddenIDs.contains($0.id) &&
            !appState.votedIDs.contains($0.id) &&
            !appState.favoriteIDs.contains($0.id)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(viewMode == .map ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewMode != .map {
                    CraigslistPattern()
                }
                
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
                                
                                if baseFilteredListings.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "magnifyingglass").font(.system(size: 34)).foregroundColor(.gray)
                                        Text("No items found in this category")
                                            .font(.custom("NunitoSans", size: 16).weight(.regular))
                                            .foregroundColor(.secondary)
                                    }.padding(.top, 40).frame(maxWidth: .infinity)
                                } else {
                                    sectionedFeed(viewMode: viewMode, proxy: proxy)
                                }
                                Spacer(minLength: 40)
                            }
                        }
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
    }
    
    @ViewBuilder
    private func sectionedFeed(viewMode: ViewMode, proxy: ScrollViewProxy) -> some View {
        if viewMode == .swipe && trendingListings.isEmpty && recentListings.isEmpty {
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(Color.craigslistGreen.opacity(0.15)).frame(width: 96, height: 96)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundColor(Color.craigslistGreen)
                }
                VStack(spacing: 8) {
                    Text("You're all caught up!")
                        .font(.custom("Montserrat", size: 22).weight(.bold))
                    Text("Try expanding your search radius, exploring other categories, or check back later for new listings.")
                        .font(.custom("NunitoSans", size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Button(action: {}) {
                    Text("Set Search Alert")
                        .font(.custom("NunitoSans", size: 16).weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.craigslistPurple)
                        .clipShape(Capsule())
                        .shadow(color: Color.craigslistPurple.opacity(0.3), radius: 8, y: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .transition(.opacity)
        } else {
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
                            Text("Recently Listed").font(.custom("Montserrat", size: 22).weight(.bold))
                            Spacer()
                            Text("\(recentListings.count) results").font(.custom("NunitoSans", size: 14).weight(.semibold)).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        
                        feedContent(for: viewMode, listings: recentListings, proxy: proxy)
                    }.id("RecentSection")
                }
            }
            .animation(.easeInOut(duration: 0.4), value: trendingListings.isEmpty)
            .animation(.easeInOut(duration: 0.4), value: recentListings.isEmpty)
        }
    }
    
    @ViewBuilder
    private func feedContent(for mode: ViewMode, listings: [Listing], proxy: ScrollViewProxy? = nil) -> some View {
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
