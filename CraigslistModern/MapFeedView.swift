import SwiftUI
import MapKit

struct MapFeedView: View {
    @EnvironmentObject var appState: AppState
    @Binding var cameraPosition: MapCameraPosition
    
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    
    var listings: [LiveListing]
    var trendingListings: [LiveListing]
    var recentListings: [LiveListing]
    @Binding var selectedListingID: UUID?
    @Binding var isDetailPresented: Bool
    
    @State private var sheetHeight: CGFloat = UIScreen.main.bounds.height * 0.40
    @State private var lastSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.40
    
    @StateObject private var locationManager = LocationManager()
    
    let minHeight: CGFloat = 100
    let midHeight: CGFloat = UIScreen.main.bounds.height * 0.40
    let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.65
    
    var body: some View {
        ZStack(alignment: .bottom) {
            mapContent
                .onChange(of: nearbyDistance) { _, newDistance in
                    updateCameraPosition(for: newDistance)
                }
                .onAppear {
                    locationManager.requestLocationIfAuthorized()
                    updateCameraPosition(for: nearbyDistance)
                    sheetHeight = midHeight
                    lastSheetHeight = midHeight
                }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        locationManager.requestLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, sheetHeight + 16)
                    .animation(.spring(), value: sheetHeight)
                }
            }
            .onChange(of: locationManager.location) { _, loc in
                if let coord = loc?.coordinate {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        cameraPosition = .region(MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: nearbyDistance * 0.025, longitudeDelta: nearbyDistance * 0.025)))
                    }
                }
            }
            
            sheetContent
        }
    }
    
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(listings, id: \.id) { listing in
                // PostGIS lat/lon extraction placeholder
                Annotation(listing.title, coordinate: CLLocationCoordinate2D(latitude: appState.savedLatitude + Double.random(in: -0.01...0.01), longitude: appState.savedLongitude + Double.random(in: -0.01...0.01))) {
                    Button(action: {
                        selectedListingID = listing.id
                        isDetailPresented = true
                    }) {
                        MapPricePin(price: listing.price, isSelected: selectedListingID == listing.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private var sheetContent: some View {
        MapBottomSheet(
            listings: listings,
            trendingListings: trendingListings,
            recentListings: recentListings,
            selectedListingID: $selectedListingID,
            isDetailPresented: $isDetailPresented,
            sheetHeight: $sheetHeight,
            lastSheetHeight: $lastSheetHeight,
            minHeight: minHeight,
            midHeight: midHeight,
            maxHeight: maxHeight
        )
    }
    
    private func updateCameraPosition(for distance: Double) {
        // Use AppState's persistent memory as the ultimate fallback instead of hardcoded MN
        let center = locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: appState.savedLatitude, longitude: appState.savedLongitude)
        let span = MKCoordinateSpan(latitudeDelta: distance * 0.025, longitudeDelta: distance * 0.025)
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}

// MARK: - Subcomponents
struct MapPricePin: View {
    var price: Int
    var isSelected: Bool
    
    var body: some View {
        Text("$\(price)")
            .font(.custom("Montserrat", size: 14).weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.craigslistPurple : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

struct MapBottomSheet: View {
    var listings: [LiveListing]
    var trendingListings: [LiveListing]
    var recentListings: [LiveListing]
    @Binding var selectedListingID: UUID?
    @Binding var isDetailPresented: Bool
    
    @Binding var sheetHeight: CGFloat
    @Binding var lastSheetHeight: CGFloat
    let minHeight: CGFloat
    let midHeight: CGFloat
    let maxHeight: CGFloat
    
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Header
            VStack(spacing: 0) {
                Capsule().fill(Color.gray.opacity(0.4)).frame(width: 40, height: 5).padding(.top, 12)
                Text("\(listings.count) results nearby")
                    .font(.custom("NunitoSans", size: 16).weight(.bold))
                    .foregroundColor(.primary)
                    .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let proposed = lastSheetHeight - value.translation.height
                        if proposed > maxHeight {
                            sheetHeight = maxHeight + (proposed - maxHeight) * 0.2
                        } else if proposed < minHeight {
                            sheetHeight = minHeight + (proposed - minHeight) * 0.2
                        } else {
                            sheetHeight = proposed
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.height
                        let target = sheetHeight - velocity
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if target > (maxHeight + midHeight) / 2 {
                                sheetHeight = maxHeight
                            } else if target < (midHeight + minHeight) / 2 {
                                sheetHeight = minHeight
                            } else {
                                sheetHeight = midHeight
                            }
                            lastSheetHeight = sheetHeight
                        }
                    }
            )
            .zIndex(2)
            
            // Scroll Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if !trendingListings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Trending")
                                .font(.custom("Montserrat", size: 22).weight(.bold))
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(trendingListings, id: \.id) { listing in
                                        MapFeedCard(listing: listing)
                                            .onTapGesture {
                                                selectedListingID = listing.id
                                                isDetailPresented = true
                                            }
                                    }
                                }.padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    if !recentListings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("More Nearby")
                                .font(.custom("Montserrat", size: 22).weight(.bold))
                                .padding(.horizontal, 16)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(recentListings, id: \.id) { listing in
                                    GridListingCard(listing: listing)
                                        .onTapGesture {
                                            selectedListingID = listing.id
                                            isDetailPresented = true
                                        }
                                }
                            }.padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .frame(height: sheetHeight)
        .background(Color(.systemBackground))
        .clipShape(TopCorners(radius: 24))
        .shadow(color: .black.opacity(0.15), radius: 10, y: -4)
    }
}

struct TopCorners: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
