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
                // Solid background for maximum focus, no pattern here
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
                            .foregroundColor(Color.craigslistPurple)
                            .padding(.trailing, 8)
                        
                        Text("Search \"\(searchText)\" in ")
                            .font(.custom("NunitoSans", size: 16).weight(.regular))
                            .foregroundColor(.primary)
                        
                        Text(cat)
                            .font(.custom("Montserrat", size: 16).weight(.bold))
                            .foregroundColor(Color.craigslistPurple)
                        
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
                Text("Recent Searches").font(.custom("Montserrat", size: 22).weight(.bold))
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
