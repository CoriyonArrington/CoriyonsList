import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @FocusState private var isSearchFocused: Bool
    
    @AppStorage("globalSearchText") private var globalSearchText = ""
    @State private var localSearchText = ""
    @State private var isDetailPresented = false
    @State private var selectedListingID: UUID?
    @State private var searchTask: Task<Void, Never>?
    
    var searchListings: [LiveListing] {
        var results = appState.listings.filter { $0.tags?.contains("search") == true }
        if let cat = appState.selectedSubCategory { results = results.filter { $0.category == cat } }
        return results
    }
    
    var pagerListings: Binding<[LiveListing]> {
        Binding(
            get: { !localSearchText.isEmpty ? appState.searchResults : appState.listings },
            set: { if !localSearchText.isEmpty { appState.searchResults = $0 } else { appState.listings = $0 } }
        )
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
                        
                        if !localSearchText.isEmpty {
                            searchSuggestionsView
                        } else {
                            recentSearchesView
                        }
                    }
                }
                
                VStack(spacing: 0) {
                    GlassHeader(
                        searchText: $localSearchText,
                        placeholder: "What are you looking for?",
                        autoFocus: true,
                        onCancel: {
                            if appState.selectedTab == 1 {
                                localSearchText = ""
                                globalSearchText = ""
                                isSearchFocused = false
                                appState.selectedTab = appState.previousTab
                            }
                        },
                        onSubmit: {
                            guard !localSearchText.isEmpty else { return }
                            globalSearchText = localSearchText
                            
                            // Clear categories if they hit Enter to perform a true global keyword search
                            appState.selectedTopCategory = nil
                            appState.selectedSubCategory = nil
                            
                            isSearchFocused = false
                            appState.selectedTab = 0
                        }
                    )
                    Spacer()
                }
                .zIndex(10)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                localSearchText = globalSearchText
                if appState.selectedTab == 1 { DispatchQueue.main.async { isSearchFocused = true } }
            }
            .onChange(of: appState.selectedTab) { _, newTab in
                if newTab == 1 {
                    localSearchText = globalSearchText
                    DispatchQueue.main.async { isSearchFocused = true }
                }
                else { isSearchFocused = false }
            }
            .onChange(of: localSearchText) { _, newValue in
                if newValue.isEmpty {
                    appState.suggestedTopCategory = nil
                    appState.suggestedSubCategory = nil
                }
                
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await appState.fetchSearchResults(query: newValue)
                }
            }
            .sheet(isPresented: $isDetailPresented) {
                let filtered = !localSearchText.isEmpty ? appState.searchResults.map { $0.id } : searchListings.map { $0.id }
                ListingPagerView(listings: pagerListings, filteredIDs: filtered, selectedListingID: $selectedListingID)
            }
        }
    }
    
    @ViewBuilder
    private var searchSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // Reads from the dynamic server-inferred category instead of what is actively clicked
            if let cat = appState.suggestedSubCategory ?? appState.suggestedTopCategory {
                Button(action: {
                    let textToPass = localSearchText
                    
                    // Actually apply the suggested categories to the app state
                    appState.selectedTopCategory = appState.suggestedTopCategory
                    appState.selectedSubCategory = appState.suggestedSubCategory
                    
                    isSearchFocused = false
                    appState.selectedTab = 0
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        globalSearchText = textToPass
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.craigslistPurple)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 24, alignment: .center)
                        
                        HStack(spacing: 4) {
                            Text("Search \"\(localSearchText)\" in ")
                                .font(.custom("NunitoSans", size: 16).weight(.regular))
                                .foregroundColor(.primary)
                            
                            Text(cat)
                                .font(.custom("Montserrat", size: 16).weight(.bold))
                                .foregroundColor(Color.craigslistPurple)
                        }
                        
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.craigslistPurple.opacity(0.1))
                }
                Divider().padding(.leading, 64)
            }
            
            if appState.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 32)
                        .tint(.craigslistPurple)
                    Spacer()
                }
            } else if appState.searchResults.isEmpty {
                HStack {
                    Spacer()
                    Text("No local results found.")
                        .font(.custom("NunitoSans", size: 16).weight(.regular))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                ForEach(appState.searchResults) { listing in
                    Button(action: {
                        selectedListingID = listing.id
                        isSearchFocused = false
                        isDetailPresented = true
                    }) {
                        RecentSearchRow(
                            icon: "magnifyingglass",
                            title: listing.title,
                            subtitle: listing.neighborhood ?? "Local Area",
                            isItem: true
                        )
                        .padding(.vertical, 12)
                    }.buttonStyle(.plain)
                    
                    Divider().padding(.leading, 64)
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
                        subtitle: listing.neighborhood ?? "Local Area",
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
