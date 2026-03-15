import SwiftUI
import MapKit

struct HomeView: View {
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 44.9778, longitude: -93.2650),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    @State private var sheetDetent: PresentationDetent = .fraction(0.20)
    
    @State private var allListings: [Listing] = initialMockListings
    @State private var searchText = ""
    
    @State private var isDetailPresented = false
    @State private var selectedListingID: UUID?
    
    @State private var viewMode: ViewMode = .map
    @State private var isNearbyMode = false // Lifted out of bottom sheet
    
    var filteredListings: [Listing] {
        if searchText.isEmpty {
            return allListings
        } else {
            return allListings.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack(alignment: .top) {
            
            if viewMode == .map {
                Map(position: $cameraPosition) {
                    // Native Apple Maps User Location Blue Dot
                    UserAnnotation()
                    
                    ForEach(filteredListings) { listing in
                        Annotation(listing.title, coordinate: listing.coordinate) {
                            Text("$\(listing.price)")
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                .onTapGesture {
                                    selectedListingID = listing.id
                                    isDetailPresented = true
                                }
                        }
                    }
                }
                .ignoresSafeArea()
                // Apple Maps floating controls block
                .overlay(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        Button(action: { isNearbyMode.toggle() }) {
                            Image(systemName: isNearbyMode ? "sparkles" : "binoculars.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isNearbyMode ? .green : .primary)
                                .frame(width: 48, height: 48)
                        }
                        
                        Divider().padding(.horizontal, 8)
                        
                        Button(action: {
                            // Reset location action here
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 48, height: 48)
                        }
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.trailing, 16)
                    .padding(.top, 60) // Clears dynamic island / notch
                }
                
            }
            else if viewMode == .grid {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredListings) { listing in
                            GridListingCard(listing: listing)
                                .onTapGesture {
                                    selectedListingID = listing.id
                                    isDetailPresented = true
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    .padding(.bottom, 240)
                }
            }
            else if viewMode == .list {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredListings) { listing in
                            ListListingCard(listing: listing)
                                .onTapGesture {
                                    selectedListingID = listing.id
                                    isDetailPresented = true
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    .padding(.bottom, 240)
                }
            }
        }
        .sheet(isPresented: .constant(true)) {
            BottomSheetContent(
                selectedListingID: $selectedListingID,
                isDetailPresented: $isDetailPresented,
                searchText: $searchText,
                viewMode: $viewMode,
                listings: filteredListings
            )
            .presentationDetents([.fraction(0.20), .medium, .large], selection: $sheetDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .interactiveDismissDisabled()
            // Apple Maps specific styling
            .presentationCornerRadius(32)
            .presentationBackground(.regularMaterial) // The glass effect
            
            .sheet(isPresented: $isDetailPresented) {
                ListingPagerView(
                    listings: $allListings,
                    filteredIDs: filteredListings.map { $0.id },
                    selectedListingID: $selectedListingID
                )
            }
        }
    }
}

// MARK: - View Mode UI Components
// (GridListingCard and ListListingCard remain exactly the same as the previous step)
struct GridListingCard: View {
    var listing: Listing
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(.systemGray5)
                    }
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(listing.price)").font(.headline).foregroundColor(.primary)
                Text(listing.title).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                Text("\(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)").font(.caption).foregroundColor(.gray).lineLimit(1)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct ListListingCard: View {
    var listing: Listing
    var body: some View {
        HStack(spacing: 16) {
            if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(.systemGray5)
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(listing.title).font(.headline).foregroundColor(.primary).lineLimit(2)
                Text("$\(listing.price)").font(.title3).fontWeight(.bold).foregroundColor(.green)
                Text("\(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)").font(.subheadline).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
