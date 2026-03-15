import SwiftUI
import MapKit

struct HomeFeedView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 44.9778, longitude: -93.2650), span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15))
    )
    @State private var selectedListingID: UUID?
    @State private var isDetailPresented = false
    
    // Sets the default View Mode to Gallery
    @State private var viewMode: ViewMode = .gallery
    @State private var isNearbyMode = false
    
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var homeListings: [Listing] {
        var results = appState.listings.filter { $0.tags.contains("home") }
        if let cat = appState.selectedSubCategory {
            results = results.filter { $0.category == cat }
        }
        return results
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                
                // UNIVERSAL BACKGROUND ANCHOR
                Color(viewMode == .map ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
                
                // MARK: - 1. Map View
                if viewMode == .map {
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        ForEach(homeListings) { listing in
                            Annotation(listing.title, coordinate: listing.coordinate) {
                                Text("$\(listing.price)").font(.system(size: 14, weight: .bold)).padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.white).foregroundColor(.black).clipShape(Capsule()).shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    .onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                            }
                        }
                    }
                    .environment(\.colorScheme, .dark)
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 112) // GlassHeader absolute height
                        FilterAndViewBar(viewMode: $viewMode)
                            .padding(.top, 16) // Exactly 128px total offset
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 12) {
                            HStack {
                                Spacer()
                                VStack(spacing: 0) {
                                    Button(action: { isNearbyMode.toggle() }) {
                                        Image(systemName: isNearbyMode ? "sparkles" : "binoculars.fill").font(.system(size: 20)).foregroundColor(isNearbyMode ? .green : .primary).frame(width: 48, height: 48)
                                    }
                                    Divider().padding(.horizontal, 8)
                                    Button(action: {}) {
                                        Image(systemName: "location.fill").font(.system(size: 20)).foregroundColor(.craigslistPurple).frame(width: 48, height: 48)
                                    }
                                }
                                .frame(width: 48).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4).padding(.trailing, 16)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Trending Nearby").font(.title3.bold()).padding(.horizontal, 16).shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(homeListings) { listing in
                                            Button(action: { selectedListingID = listing.id; isDetailPresented = true }) { MapFeedCard(listing: listing) }.buttonStyle(.plain)
                                        }
                                    }.padding(.horizontal, 16)
                                }
                            }.padding(.bottom, 24)
                        }
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        // 88px spacer + 24px VStack spacing + 16px top padding = 128px offset!
                        VStack(alignment: .leading, spacing: 24) {
                            Color.clear.frame(height: 88)
                            
                            FilterAndViewBar(viewMode: $viewMode)
                                .padding(.top, 16) // Flawless sync with Map View
                            
                            CraigslistCategoryBrowser()
                            
                            if homeListings.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass").font(.largeTitle).foregroundColor(.gray)
                                    Text("No items found in this category").foregroundColor(.secondary)
                                }.padding(.top, 40).frame(maxWidth: .infinity)
                            } else {
                                if viewMode == .grid {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Top Deals").font(.title2.bold()).padding(.horizontal, 16)
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 16) {
                                                ForEach(homeListings.shuffled()) { listing in
                                                    SquareListingCard(listing: listing, size: 160).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                                                }
                                            }.padding(.horizontal, 16)
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Recently Listed").font(.title2.bold()).padding(.horizontal, 16)
                                        LazyVGrid(columns: columns, spacing: 24) {
                                            ForEach(homeListings.reversed()) { listing in
                                                GridListingCard(listing: listing).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                                            }
                                        }.padding(.horizontal, 16)
                                    }
                                } else if viewMode == .gallery {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Recently Listed").font(.title2.bold()).padding(.horizontal, 16)
                                        LazyVStack(spacing: 24) {
                                            ForEach(homeListings.reversed()) { listing in
                                                GalleryListingCard(listing: listing).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                                            }
                                        }.padding(.horizontal, 16)
                                    }
                                } else if viewMode == .list {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Recently Listed").font(.title2.bold()).padding(.horizontal, 16)
                                        LazyVStack(spacing: 16) {
                                            ForEach(homeListings.reversed()) { listing in
                                                ListListingCard(listing: listing).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                                            }
                                        }.padding(.horizontal, 16)
                                    }
                                }
                            }
                            Spacer(minLength: 40)
                        }
                    }
                }
                
                // MARK: - TOP FIXED HEADER
                VStack(spacing: 0) {
                    GlassHeader(
                        searchText: .constant(""),
                        placeholder: "What are you looking for?",
                        onTapped: { appState.selectedTab = 1 }
                    )
                    Spacer()
                }
                .zIndex(10)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isDetailPresented) {
                ListingPagerView(listings: $appState.listings, filteredIDs: homeListings.map{$0.id}, selectedListingID: $selectedListingID)
            }
        }
    }
}

// MARK: - Global Reusable Components

struct GlassHeader: View {
    @EnvironmentObject var appState: AppState
    @Binding var searchText: String
    var placeholder: String
    var autoFocus: Bool = false
    @FocusState private var isFocused: Bool
    var onTapped: () -> Void = {}
    var onCancel: (() -> Void)? = nil
    @State private var showLocationSheet = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { showLocationSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill").foregroundColor(.craigslistPurple)
                        Text(appState.selectedLocation).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    }
                }
                .sheet(isPresented: $showLocationSheet) { LocationSelectionSheet().presentationDetents([.medium, .large]) }
                Spacer()
                Image(systemName: "person.circle.fill").resizable().frame(width: 32, height: 32).foregroundColor(.craigslistPurple)
            }
            .padding(.horizontal, 16).padding(.top, 12)
            
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 18)).foregroundColor(.secondary)
                    if autoFocus {
                        TextField(placeholder, text: $searchText)
                            .focused($isFocused)
                            .font(.system(size: 16))
                            .onChange(of: searchText) { newValue in
                                appState.autoSelectCategory(for: newValue)
                            }
                    } else {
                        Text(placeholder).font(.system(size: 16)).foregroundColor(searchText.isEmpty ? .secondary : .primary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.systemGray5).opacity(autoFocus ? 1.0 : 0.6))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .onTapGesture { onTapped() }
                
                if let cancelAction = onCancel, autoFocus {
                    Button("Cancel", action: cancelAction).font(.system(size: 16, weight: .medium)).foregroundColor(.craigslistPurple).transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(.regularMaterial, ignoresSafeAreaEdges: .top)
        .onAppear {
            if autoFocus { DispatchQueue.main.async { isFocused = true } }
        }
        .onChange(of: appState.selectedTab) { newTab in
            if autoFocus && newTab == 1 { DispatchQueue.main.async { isFocused = true } }
            else if autoFocus { isFocused = false }
        }
    }
}

struct FilterAndViewBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var viewMode: ViewMode
    @State private var showFilterSheet = false
    @State private var showViewSheet = false
    
    var body: some View {
        HStack {
            Button(action: { showFilterSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                    Text(appState.selectedTopCategory ?? "All Categories").fixedSize(horizontal: true, vertical: false)
                    Image(systemName: "chevron.down")
                }
                .font(.system(size: 13, weight: .semibold)).padding(.horizontal, 12).padding(.vertical, 8).background(Color(.systemGray5).opacity(0.8)).cornerRadius(16).foregroundColor(appState.selectedTopCategory != nil ? .craigslistPurple : .primary)
            }
            .sheet(isPresented: $showFilterSheet) { FilterSelectionSheet().presentationDetents([.medium, .large]) }
            
            Spacer()
            
            Button(action: { showViewSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: viewMode.icon)
                    Text(viewMode.rawValue).fixedSize(horizontal: true, vertical: false)
                    Image(systemName: "chevron.down")
                }
                .font(.system(size: 13, weight: .semibold)).padding(.horizontal, 12).padding(.vertical, 8).background(Color(.systemGray5).opacity(0.8)).cornerRadius(16).foregroundColor(.primary)
            }
            .sheet(isPresented: $showViewSheet) { ViewSelectionSheet(viewMode: $viewMode).presentationDetents([.height(310)]) }
            
        }.padding(.horizontal, 16)
    }
}

struct ViewSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var viewMode: ViewMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 12)
                HStack { Text("View Mode").font(.headline); Spacer(); Button("Done") { dismiss() }.font(.headline).foregroundColor(.craigslistPurple) }.padding(.horizontal, 16).padding(.bottom, 12)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button(action: { viewMode = mode; dismiss() }) {
                        HStack {
                            Image(systemName: mode.icon).foregroundColor(.primary).frame(width: 24, alignment: .leading)
                            Text(mode.rawValue).font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
                            Spacer()
                            if viewMode == mode { Image(systemName: "checkmark").foregroundColor(.craigslistPurple) }
                        }
                        .padding(.vertical, 16).padding(.horizontal, 16)
                    }
                    if mode != ViewMode.allCases.last { Divider().padding(.leading, 48) }
                }
            }.padding(.top, 8)
            Spacer()
        }.background(Color(.systemBackground))
    }
}

struct CraigslistCategoryBrowser: View {
    @EnvironmentObject var appState: AppState
    
    var activeSubs: [String] {
        if let topCat = appState.selectedTopCategory, let subs = appState.subCategories[topCat] { return subs }
        return ["Free", "Furniture", "Electronics", "Apts / Housing", "Cars", "Gigs"]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(appState.topCategories, id: \.0) { cat in
                        CategoryCircle(icon: cat.1, color: .craigslistPurple, label: cat.0)
                    }
                }.padding(.horizontal, 16).padding(.bottom, 4)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(activeSubs, id: \.self) { sub in
                        Button(action: {
                            withAnimation(.spring()) {
                                if appState.selectedSubCategory == sub { appState.selectedSubCategory = nil }
                                else { appState.selectedSubCategory = sub }
                            }
                        }) {
                            Text(sub).font(.system(size: 14, weight: .medium)).padding(.horizontal, 16).padding(.vertical, 8)
                                .background(appState.selectedSubCategory == sub ? Color.craigslistPurple : Color(.systemGray6))
                                .foregroundColor(appState.selectedSubCategory == sub ? .white : .primary).clipShape(Capsule())
                        }
                    }
                }.padding(.horizontal, 16)
            }
        }
    }
}

struct CategoryCircle: View {
    @EnvironmentObject var appState: AppState
    var icon: String; var color: Color; var label: String
    var onTap: (() -> Void)? = nil
    var isSelected: Bool { appState.selectedTopCategory == label }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                if appState.selectedTopCategory == label {
                    appState.selectedTopCategory = nil; appState.selectedSubCategory = nil
                } else {
                    appState.selectedTopCategory = label; appState.selectedSubCategory = nil
                }
            }
            onTap?()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(isSelected ? color : Color(.systemGray5)).frame(width: 72, height: 72)
                    Image(systemName: icon).font(.system(size: 30)).foregroundColor(isSelected ? .white : color)
                    
                    if isSelected {
                        Circle().stroke(color, lineWidth: 2).frame(width: 80, height: 80)
                    }
                }
                .frame(width: 86, height: 86)
                
                Text(label).font(.system(size: 13, weight: isSelected ? .bold : .medium)).foregroundColor(.primary)
            }
        }.buttonStyle(.plain)
    }
}

struct FilterSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var activeSubs: [String] {
        if let topCat = appState.selectedTopCategory, let subs = appState.subCategories[topCat] { return subs }
        return ["Free", "Furniture", "Electronics", "Apts / Housing", "Cars", "Gigs"]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 12)
                HStack { Text("Filters").font(.headline); Spacer(); Button("Done") { dismiss() }.font(.headline).foregroundColor(.craigslistPurple) }.padding(.horizontal, 16).padding(.bottom, 12)
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("CATEGORY").font(.caption).foregroundColor(.secondary).padding(.horizontal, 16)
                    
                    LazyVGrid(columns: columns, spacing: 24) {
                        Button(action: {
                            withAnimation(.spring()) { appState.selectedTopCategory = nil; appState.selectedSubCategory = nil }
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(appState.selectedTopCategory == nil ? Color.craigslistPurple : Color(.systemGray5)).frame(width: 72, height: 72)
                                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 30)).foregroundColor(appState.selectedTopCategory == nil ? .white : .primary)
                                    if appState.selectedTopCategory == nil { Circle().stroke(Color.craigslistPurple, lineWidth: 2).frame(width: 80, height: 80) }
                                }.frame(width: 86, height: 86)
                                Text("All").font(.system(size: 13, weight: appState.selectedTopCategory == nil ? .bold : .medium)).foregroundColor(.primary)
                            }
                        }.buttonStyle(.plain)
                        
                        ForEach(appState.topCategories, id: \.0) { cat in
                            CategoryCircle(icon: cat.1, color: .craigslistPurple, label: cat.0)
                        }
                    }.padding(.horizontal, 16).padding(.top, 8)
                    
                    Divider().padding(.horizontal, 16)
                    Text("SUBCATEGORIES").font(.caption).foregroundColor(.secondary).padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(activeSubs, id: \.self) { sub in
                            Button(action: {
                                withAnimation(.spring()) {
                                    if appState.selectedSubCategory == sub { appState.selectedSubCategory = nil }
                                    else { appState.selectedSubCategory = sub }
                                }
                            }) {
                                HStack {
                                    Text(sub)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(appState.selectedSubCategory == sub ? .craigslistPurple : .primary)
                                    Spacer()
                                    if appState.selectedSubCategory == sub {
                                        Image(systemName: "checkmark").foregroundColor(.craigslistPurple)
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                            }
                            Divider().padding(.leading, 16)
                        }
                    }
                    
                }.padding(.top, 8).padding(.bottom, 40)
            }
        }.background(Color(.systemBackground))
    }
}

struct LocationSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var searchRadius: Int = 10
    @State private var isNearbyMode: Bool = false
    
    let cities = ["Minneapolis, MN", "St. Paul, MN", "Bloomington, MN", "Brooklyn Center, MN", "Edina, MN", "Plymouth, MN"]
    let neighborhoods = ["North Loop", "Uptown", "Northeast", "Downtown", "Linden Hills", "Dinkytown"]
    let radii = [1, 5, 10, 25]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 12)
                HStack { Text("Location").font(.headline); Spacer(); Button("Done") { dismiss() }.font(.headline).foregroundColor(.craigslistPurple) }.padding(.horizontal, 16)
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    Button(action: {}) {
                        HStack { Image(systemName: "location.fill"); Text("Use Current Location") }
                        .font(.system(size: 16, weight: .medium)).foregroundColor(.craigslistPurple).frame(maxWidth: .infinity, alignment: .leading)
                        .padding().background(Color.craigslistPurple.opacity(0.1)).cornerRadius(12)
                    }.padding(.horizontal, 16).padding(.top, 24)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NEARBY MODE").font(.caption).foregroundColor(.secondary)
                        Toggle(isOn: $isNearbyMode) { Text("Prioritize nearby items & deals").font(.system(size: 16)) }
                    }.padding(.horizontal, 16).tint(.craigslistPurple)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SEARCH RADIUS").font(.caption).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(radii, id: \.self) { radius in
                                Button(action: { searchRadius = radius }) {
                                    Text("\(radius) miles").font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 10).background(searchRadius == radius ? Color.craigslistPurple : Color(.systemGray6)).foregroundColor(searchRadius == radius ? .white : .primary).cornerRadius(20)
                                }
                            }
                        }
                    }.padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("NEIGHBORHOODS").font(.caption).foregroundColor(.secondary).padding(.horizontal, 16).padding(.bottom, 8)
                        ForEach(neighborhoods, id: \.self) { loc in
                            Button(action: { appState.selectedLocation = loc; dismiss() }) {
                                HStack { Image(systemName: "mappin.and.ellipse").foregroundColor(.secondary); Text(loc).foregroundColor(.primary); Spacer(); if appState.selectedLocation == loc { Image(systemName: "checkmark").foregroundColor(.craigslistPurple) } }
                                .padding(.vertical, 14).padding(.horizontal, 16)
                            }
                            Divider().padding(.leading, 48)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("CITIES").font(.caption).foregroundColor(.secondary).padding(.horizontal, 16).padding(.bottom, 8)
                        ForEach(cities, id: \.self) { loc in
                            Button(action: { appState.selectedLocation = loc; dismiss() }) {
                                HStack { Image(systemName: "building.2.fill").foregroundColor(.secondary); Text(loc).foregroundColor(.primary); Spacer(); if appState.selectedLocation == loc { Image(systemName: "checkmark").foregroundColor(.craigslistPurple) } }
                                .padding(.vertical, 14).padding(.horizontal, 16)
                            }
                            if loc != cities.last { Divider().padding(.leading, 48) }
                        }
                    }.padding(.bottom, 40)
                }
            }
        }.background(Color(.systemBackground))
    }
}

// MARK: - Explicitly Bounded Feed Cards
struct GalleryListingCard: View {
    var listing: Listing
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(listing.title).font(.title3).fontWeight(.bold).foregroundColor(.primary)
                    Spacer()
                    Text("$\(listing.price)").font(.title3).fontWeight(.bold).foregroundColor(.green)
                }
                Text("\(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)").font(.subheadline).foregroundColor(.secondary)
            }.padding(.horizontal, 4)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct SquareListingCard: View {
    var listing: Listing; var size: CGFloat
    var body: some View {
        Color(.systemGray5)
            .frame(width: size, height: size)
            .overlay(
                Group {
                    if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray4), lineWidth: 1))
    }
}

struct MapFeedCard: View {
    var listing: Listing
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(.systemGray5)
                .frame(width: 200, height: 220)
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
            
            LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .center, endPoint: .bottom)
                .frame(width: 200, height: 220)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(listing.price)").font(.title2).fontWeight(.heavy).foregroundColor(.white)
                Text(listing.title).font(.subheadline).fontWeight(.bold).foregroundColor(.white).lineLimit(1)
            }.padding()
        }
        .frame(width: 200, height: 220).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

struct GridListingCard: View {
    var listing: Listing
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(listing.price)").font(.headline).foregroundColor(.primary)
                Text(listing.title).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                Text("\(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)").font(.caption).foregroundColor(.gray).lineLimit(1)
            }.padding(.horizontal, 4)
        }.background(Color(.systemGroupedBackground))
    }
}

struct ListListingCard: View {
    var listing: Listing
    var body: some View {
        HStack(spacing: 16) {
            Color(.systemGray5)
                .frame(width: 100, height: 100)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            }
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(listing.title).font(.headline).foregroundColor(.primary).lineLimit(2)
                Text("$\(listing.price)").font(.title3).fontWeight(.bold).foregroundColor(.green)
                Text("\(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)").font(.subheadline).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
        }.padding(12).background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct RecentSearchRow: View {
    var icon: String; var title: String; var subtitle: String; var isItem: Bool = false
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color(.systemGray5).opacity(0.6)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(isItem ? .craigslistPurple : .secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 14)).foregroundColor(.secondary)
            }
            Spacer()
        }.padding(.horizontal, 16)
    }
}
