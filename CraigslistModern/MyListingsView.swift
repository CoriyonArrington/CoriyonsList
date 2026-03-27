import SwiftUI

struct MyListingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var selectedListingID: UUID?
    @State private var isDetailPresented = false
    
    // Filters for listings where you are the seller
    var myListings: [Listing] {
        appState.listings.filter { $0.sellerName == "Coriyon Arrington" }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            CraigslistPattern()
            
            if myListings.isEmpty {
                VStack(spacing: Theme.Spacing.medium) {
                    Image(systemName: "tag.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("You haven't posted anything yet.")
                        .font(Theme.Typography.body())
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: Theme.Spacing.medium) {
                        ForEach(myListings, id: \.id) { listing in
                            ListListingCard(listing: listing)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedListingID = listing.id
                                    isDetailPresented = true
                                }
                        }
                    }
                    .padding(Theme.Spacing.medium)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("My Listings")
                    .font(Theme.Typography.headingM())
                    .foregroundColor(.primary)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 8) { // FIX: Increased spacing between chevron and "Back"
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(Theme.Typography.body(weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .toolbarBackground(Theme.Colors.surfaceCard.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $isDetailPresented) {
            ListingPagerView(
                listings: $appState.listings,
                filteredIDs: myListings.map { $0.id },
                selectedListingID: $selectedListingID
            )
        }
    }
}
