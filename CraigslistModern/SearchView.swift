import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @FocusState private var isSearchFocused: Bool
    
    @State private var searchText = ""
    @State private var isDetailPresented = false
    @State private var selectedListingID: UUID?
    
    var searchListings: [Listing] {
        var results = appState.listings.filter { $0.tags.contains("search") }
        if let cat = appState.selectedSubCategory { results = results.filter { $0.category == cat } }
        return results
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear.frame(height: 88)
                        
                        CraigslistCategoryBrowser()
                            .padding(.top, 16)
                        
                        if !searchText.isEmpty {
                            searchSuggestionsView
                        } else {
                            recentSearchesView
                        }
                    }
                }
                
                // MARK: - TOP FIXED HEADER
                VStack(spacing: 0) {
                    GlassHeader(
                        searchText: $searchText,
                        placeholder: "What are you looking for?",
                        autoFocus: true,
                        onCancel: {
                            searchText = ""
                            isSearchFocused = false
                            appState.selectedTab = appState.previousTab
                        }
                    )
                    Spacer()
                }
                .zIndex(10)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if appState.selectedTab == 1 { DispatchQueue.main.async { isSearchFocused = true } }
            }
            .onChange(of: appState.selectedTab) { newTab in
                if newTab == 1 { DispatchQueue.main.async { isSearchFocused = true } }
                else { isSearchFocused = false }
            }
            .sheet(isPresented: $isDetailPresented) {
                ListingPagerView(listings: $appState.listings, filteredIDs: searchListings.map { $0.id }, selectedListingID: $selectedListingID)
            }
        }
    }
    
    // MARK: - Extracted Subviews
    @ViewBuilder
    private var searchSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let cat = appState.selectedSubCategory ?? appState.selectedTopCategory {
                Button(action: {
                    isSearchFocused = false
                    appState.selectedTab = appState.previousTab
                }) {
                    HStack(spacing: 0) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.craigslistPurple)
                            .padding(.trailing, 8)
                        
                        Text("Search \"\(searchText)\" in ")
                            .font(.custom("NunitoSans", size: 16).weight(.regular))
                            .foregroundColor(.primary)
                        
                        Text(cat)
                            .font(.custom("Montserrat", size: 16).weight(.bold))
                            .foregroundColor(.craigslistPurple)
                        
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.craigslistPurple.opacity(0.1))
                }
                Divider().padding(.leading, 44)
            }
            
            let suggestions = appState.getSuggestions(for: searchText)
            if !suggestions.isEmpty {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        searchText = suggestion
                        isSearchFocused = false
                        appState.selectedTab = appState.previousTab
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            Text(suggestion)
                                .font(.custom("NunitoSans", size: 16).weight(.regular))
                                .foregroundColor(.primary).padding(.leading, 4)
                            Spacer()
                            Image(systemName: "arrow.up.backward").foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    Divider().padding(.leading, 44)
                }
            }
        }
    }
    
    @ViewBuilder
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Searches").font(.custom("Montserrat", size: 20).weight(.bold))
            }.padding(.horizontal, 16)
            
            let recentListings = Array(searchListings.prefix(3))
            
            ForEach(recentListings) { listing in
                Button(action: {
                    selectedListingID = listing.id
                    isDetailPresented = true
                }) {
                    RecentSearchRow(
                        icon: "clock.arrow.circlepath",
                        title: listing.title,
                        subtitle: "\(String(format: "%.1f", listing.distance)) miles • \(listing.neighborhood)",
                        isItem: true
                    )
                }.buttonStyle(.plain)
                
                if listing.id != recentListings.last?.id {
                    Divider().padding(.leading, 64)
                }
            }
        }
    }
}

// MARK: - Local Search Components
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
                            Text(sub).font(.custom("NunitoSans", size: 14).weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 8)
                                .background(appState.selectedSubCategory == sub ? Color.craigslistPurple : Color(.secondarySystemGroupedBackground))
                                .foregroundColor(appState.selectedSubCategory == sub ? .white : .primary)
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                }.padding(.horizontal, 16)
            }
        }
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
                Text(title).font(.custom("Montserrat", size: 16).weight(.semibold)).foregroundColor(.primary)
                Text(subtitle).font(.custom("NunitoSans", size: 14).weight(.regular)).foregroundColor(.secondary)
            }
            Spacer()
        }.padding(.horizontal, 16)
    }
}
