import SwiftUI
import MapKit

struct HomeFeedView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 44.9778, longitude: -93.2650), span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15))
    )
    @State private var selectedListingID: UUID?
    @State private var isDetailPresented = false
    
    @State private var viewMode: ViewMode = .gallery
    @State private var isNearbyMode = false
    
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var homeListings: [Listing] {
        var results = appState.listings.filter { $0.tags.contains("home") }
        
        if let topCat = appState.selectedTopCategory {
            if let validSubs = appState.subCategories[topCat] {
                results = results.filter { validSubs.contains($0.category) }
            }
        }
        
        if let subCat = appState.selectedSubCategory {
            results = results.filter { $0.category == subCat }
        }
        
        return results
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                
                Color(viewMode == .map ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewMode == .map {
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        ForEach(homeListings) { listing in
                            Annotation(listing.title, coordinate: listing.coordinate) {
                                Text("$\(listing.price)")
                                    .font(.custom("Montserrat", size: 14).weight(.bold))
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.white).foregroundColor(.black).clipShape(Capsule()).shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    .onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                            }
                        }
                    }
                    .environment(\.colorScheme, .dark)
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 112)
                        FilterAndViewBar(viewMode: $viewMode)
                            .padding(.top, 16)
                        
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
                                Text("Trending Nearby")
                                    .font(.custom("Montserrat", size: 20).weight(.bold))
                                    .padding(.horizontal, 16).shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(homeListings.prefix(8)) { listing in
                                            Button(action: { selectedListingID = listing.id; isDetailPresented = true }) { MapFeedCard(listing: listing) }.buttonStyle(.plain)
                                        }
                                    }.padding(.horizontal, 16)
                                }
                            }.padding(.bottom, 24)
                        }
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            Color.clear.frame(height: 88)
                            
                            FilterAndViewBar(viewMode: $viewMode)
                                .padding(.top, 16)
                            
                            if homeListings.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass").font(.system(size: 34)).foregroundColor(.gray)
                                    Text("No items found in this category")
                                        .font(.custom("NunitoSans", size: 16).weight(.regular))
                                        .foregroundColor(.secondary)
                                }.padding(.top, 40).frame(maxWidth: .infinity)
                            } else {
                                if viewMode == .grid {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Top Deals")
                                            .font(.custom("Montserrat", size: 22).weight(.bold))
                                            .padding(.horizontal, 16)
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 16) {
                                                ForEach(homeListings.shuffled().prefix(8)) { listing in
                                                    SquareListingCard(listing: listing, size: 160).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                                                }
                                            }.padding(.horizontal, 16)
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Recently Listed")
                                            .font(.custom("Montserrat", size: 22).weight(.bold))
                                            .padding(.horizontal, 16)
                                        LazyVGrid(columns: columns, spacing: 16) {
                                            ForEach(homeListings.reversed()) { listing in
                                                GridListingCard(listing: listing).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                                            }
                                        }.padding(.horizontal, 16)
                                    }
                                } else if viewMode == .gallery {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Recently Listed")
                                            .font(.custom("Montserrat", size: 22).weight(.bold))
                                            .padding(.horizontal, 16)
                                        LazyVStack(spacing: 24) {
                                            ForEach(homeListings.reversed()) { listing in
                                                GalleryListingCard(listing: listing).onTapGesture { selectedListingID = listing.id; isDetailPresented = true }
                                            }
                                        }.padding(.horizontal, 16)
                                    }
                                } else if viewMode == .list {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Recently Listed")
                                            .font(.custom("Montserrat", size: 22).weight(.bold))
                                            .padding(.horizontal, 16)
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
                Image("CraigslistIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.craigslistPurple)
                
                Button(action: { showLocationSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill").foregroundColor(.primary).font(.system(size: 14))
                        Text(appState.selectedLocation)
                            .font(.custom("Montserrat", size: 15).weight(.bold))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                    }
                }
                .sheet(isPresented: $showLocationSheet) { LocationSelectionSheet().presentationDetents([.medium, .large]) }
                Spacer()
                Image(systemName: "person.circle.fill").resizable().frame(width: 30, height: 30).foregroundColor(.craigslistPurple)
            }
            .padding(.horizontal, 16).padding(.top, 12)
            
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 18)).foregroundColor(.secondary)
                    if autoFocus {
                        TextField(placeholder, text: $searchText)
                            .focused($isFocused)
                            .font(.custom("NunitoSans", size: 16).weight(.regular))
                            .onChange(of: searchText) { newValue in
                                appState.autoSelectCategory(for: newValue)
                            }
                    } else {
                        Text(placeholder)
                            .font(.custom("NunitoSans", size: 16).weight(.regular))
                            .foregroundColor(searchText.isEmpty ? .secondary : .primary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            appState.autoSelectCategory(for: "")
                        }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.systemGray5).opacity(autoFocus ? 1.0 : 0.6))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .onTapGesture { onTapped() }
                
                if let cancelAction = onCancel, autoFocus {
                    Button("Cancel", action: cancelAction)
                        .font(.custom("Montserrat", size: 16).weight(.medium))
                        .foregroundColor(.craigslistPurple).transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(
            Rectangle()
                .fill(.ultraThickMaterial)
                .ignoresSafeArea(.all, edges: .top)
        )
        .overlay(Divider().opacity(0.3), alignment: .bottom)
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
                .font(.custom("Montserrat", size: 13).weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 8).background(Color(.systemGray5).opacity(0.8)).cornerRadius(16).foregroundColor(appState.selectedTopCategory != nil ? .craigslistPurple : .primary)
            }
            .sheet(isPresented: $showFilterSheet) { FilterSelectionSheet().presentationDetents([.medium, .large]) }
            
            Spacer()
            
            Button(action: { showViewSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: viewMode.icon)
                    Text(viewMode.rawValue).fixedSize(horizontal: true, vertical: false)
                    Image(systemName: "chevron.down")
                }
                .font(.custom("Montserrat", size: 13).weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 8).background(Color(.systemGray5).opacity(0.8)).cornerRadius(16).foregroundColor(.primary)
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
                HStack {
                    Text("View Mode").font(.custom("Montserrat", size: 17).weight(.bold))
                    Spacer()
                    Button("Done") { dismiss() }.font(.custom("Montserrat", size: 17).weight(.bold)).foregroundColor(.craigslistPurple)
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button(action: { viewMode = mode; dismiss() }) {
                        HStack {
                            Image(systemName: mode.icon).foregroundColor(.primary).frame(width: 24, alignment: .leading)
                            Text(mode.rawValue).font(.custom("NunitoSans", size: 16).weight(.semibold)).foregroundColor(.primary)
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
                HStack {
                    Text("Filters").font(.custom("Montserrat", size: 17).weight(.bold))
                    Spacer()
                    Button("Done") { dismiss() }.font(.custom("Montserrat", size: 17).weight(.bold)).foregroundColor(.craigslistPurple)
                }
                .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 12)
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("CATEGORY").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary).padding(.horizontal, 16)
                    
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
                                Text("All")
                                    .font(appState.selectedTopCategory == nil ? .custom("Montserrat", size: 13).weight(.bold) : .custom("NunitoSans", size: 13).weight(.semibold))
                                    .foregroundColor(.primary)
                            }
                        }.buttonStyle(.plain)
                        
                        ForEach(appState.topCategories, id: \.0) { cat in
                            CategoryCircle(icon: cat.1, color: .craigslistPurple, label: cat.0)
                        }
                    }.padding(.horizontal, 16).padding(.top, 8)
                    
                    Divider().padding(.horizontal, 16)
                    Text("SUBCATEGORIES").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary).padding(.horizontal, 16)
                    
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
                                        .font(.custom("NunitoSans", size: 16).weight(.semibold))
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
                HStack {
                    Text("Location").font(.custom("Montserrat", size: 17).weight(.bold))
                    Spacer()
                    Button("Done") { dismiss() }.font(.custom("Montserrat", size: 17).weight(.bold)).foregroundColor(.craigslistPurple)
                }.padding(.horizontal, 16)
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    Button(action: {}) {
                        HStack { Image(systemName: "location.fill"); Text("Use Current Location") }
                        .font(.custom("Montserrat", size: 16).weight(.semibold)).foregroundColor(.craigslistPurple).frame(maxWidth: .infinity, alignment: .leading)
                        .padding().background(Color.craigslistPurple.opacity(0.1)).cornerRadius(12)
                    }.padding(.horizontal, 16).padding(.top, 24)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NEARBY MODE").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary)
                        Toggle(isOn: $isNearbyMode) { Text("Prioritize nearby items & deals").font(.custom("NunitoSans", size: 16).weight(.regular)) }
                    }.padding(.horizontal, 16).tint(.craigslistPurple)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SEARCH RADIUS").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(radii, id: \.self) { radius in
                                Button(action: { searchRadius = radius }) {
                                    Text("\(radius) miles")
                                        .font(.custom("NunitoSans", size: 14).weight(.semibold))
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(searchRadius == radius ? Color.craigslistPurple : Color(.systemGray6))
                                        .foregroundColor(searchRadius == radius ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }.padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("NEIGHBORHOODS").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.bottom, 8)
                        ForEach(neighborhoods, id: \.self) { loc in
                            Button(action: { appState.selectedLocation = loc; dismiss() }) {
                                HStack { Image(systemName: "mappin.and.ellipse").foregroundColor(.secondary); Text(loc).font(.custom("NunitoSans", size: 16).weight(.regular)).foregroundColor(.primary); Spacer(); if appState.selectedLocation == loc { Image(systemName: "checkmark").foregroundColor(.craigslistPurple) } }
                                .padding(.vertical, 14).padding(.horizontal, 16)
                            }
                            Divider().padding(.leading, 48)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("CITIES").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.bottom, 8)
                        ForEach(cities, id: \.self) { loc in
                            Button(action: { appState.selectedLocation = loc; dismiss() }) {
                                HStack { Image(systemName: "building.2.fill").foregroundColor(.secondary); Text(loc).font(.custom("NunitoSans", size: 16).weight(.regular)).foregroundColor(.primary); Spacer(); if appState.selectedLocation == loc { Image(systemName: "checkmark").foregroundColor(.craigslistPurple) } }
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
                
                Text(label)
                    .font(isSelected ? .custom("Montserrat", size: 13).weight(.bold) : .custom("NunitoSans", size: 13).weight(.semibold))
                    .foregroundColor(.primary)
            }
        }.buttonStyle(.plain)
    }
}

// MARK: - Refined Feed Cards
struct GalleryListingCard: View {
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
                
                HStack(alignment: .center, spacing: 6) {
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
                        .padding(.horizontal, 2)
                    
                    Text("\(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)")
                        .font(.custom("NunitoSans", size: 14).weight(.medium))
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

struct SquareListingCard: View {
    @EnvironmentObject var appState: AppState
    var listing: Listing; var size: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                .clipped()
                .overlay(
                    LinearGradient(gradient: Gradient(colors: [.black.opacity(0.3), .clear]), startPoint: .top, endPoint: .center)
                )
                .overlay(alignment: .topLeading) {
                     Text(listing.distance < 5.0 ? "Nearby" : "New")
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
                        .font(.custom("Montserrat", size: 14).weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("$\(listing.price)")
                        .font(.custom("Montserrat", size: 15).weight(.heavy))
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
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.yellow)
                        Text("\(String(format: "%.1f", listing.sellerRating))").font(.custom("NunitoSans", size: 11).weight(.bold)).foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .font(.custom("NunitoSans", size: 11).weight(.bold))
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", listing.distance)) mi")
                        .font(.custom("NunitoSans", size: 12).weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(width: size, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

struct MapFeedCard: View {
    @EnvironmentObject var appState: AppState
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
            
            LinearGradient(gradient: Gradient(colors: [.black.opacity(0.7), .clear, .black.opacity(0.9)]), startPoint: .top, endPoint: .bottom)
            
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Text(listing.distance < 5.0 ? "Nearby" : "Just Listed")
                        .font(.custom("NunitoSans", size: 10).weight(.bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Image(systemName: appState.isFavorited(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(appState.isFavorited(listing.id) ? .red : .primary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .onTapGesture { appState.toggleFavorite(listing.id) }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        Text(listing.title)
                            .font(.custom("Montserrat", size: 16).weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("$\(listing.price)")
                            .font(.custom("Montserrat", size: 20).weight(.heavy))
                            .foregroundColor(.green)
                    }
                    
                    HStack(spacing: 4) {
                        if let url = URL(string: listing.sellerAvatar) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                                else { Color(.systemGray4) }
                            }
                            .frame(width: 16, height: 16)
                            .clipShape(Circle())
                        } else {
                            Circle().fill(Color(.systemGray4)).frame(width: 16, height: 16)
                        }
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow)
                            Text("\(String(format: "%.1f", listing.sellerRating)) (\(listing.reviewCount))").font(.custom("NunitoSans", size: 11).weight(.bold)).foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 200, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct GridListingCard: View {
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
                        .font(.custom("NunitoSans", size: 12).weight(.medium))
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

struct ListListingCard: View {
    @EnvironmentObject var appState: AppState
    var listing: Listing
    
    var body: some View {
        HStack(spacing: 16) {
            Color(.systemGray5)
                .frame(width: 110, height: 110)
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
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: appState.isFavorited(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(appState.isFavorited(listing.id) ? .red : .primary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .padding(6)
                        .onTapGesture { appState.toggleFavorite(listing.id) }
                }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(listing.title)
                        .font(.custom("Montserrat", size: 17).weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("$\(listing.price)")
                        .font(.custom("Montserrat", size: 18).weight(.heavy))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                HStack(alignment: .center, spacing: 6) {
                    if let url = URL(string: listing.sellerAvatar) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            else { Color(.systemGray4) }
                        }
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                    } else {
                        Circle().fill(Color(.systemGray4)).frame(width: 16, height: 16)
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow)
                        Text("\(String(format: "%.1f", listing.sellerRating))").font(.custom("NunitoSans", size: 12).weight(.bold)).foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .font(.custom("NunitoSans", size: 12).weight(.bold))
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)")
                        .font(.custom("NunitoSans", size: 13).weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
