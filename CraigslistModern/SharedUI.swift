import SwiftUI
import CoreLocation
import MapKit

// MARK: - CoreLocation Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var cityNeighborhood: String?
    @Published var isRequesting = false

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation() {
        isRequesting = true
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func requestLocationIfAuthorized() {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        self.location = loc
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isRequesting = false
                if let place = placemarks?.first {
                    let city = place.locality ?? "Unknown City"
                    let state = place.administrativeArea ?? ""
                    self?.cityNeighborhood = "\(city), \(state)"
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isRequesting = false
        }
    }
}

// MARK: - Location Search Service for Auto-Complete
class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = "" {
        didSet {
            if searchQuery.isEmpty {
                completions = []
            } else {
                completer.queryFragment = searchQuery
            }
        }
    }
    @Published var completions: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.completions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    }
}

// MARK: - THEME ENGINE (Design System)
struct Theme {
    struct Colors {
        static let primary = Color.craigslistPurple
        static let success = Color.craigslistGreen
        static let surfaceCard = Color(.systemBackground)
        static let surfaceBackground = Color(.systemGroupedBackground)
        static let surfaceGray = Color(.systemGray5)
        static let inputBackground = Color(.systemGray6)
        static let textSecondary = Color.secondary
        static let actionPrimary = Color.craigslistPurple
    }
    
    struct Typography {
        static func display() -> Font { .custom("Montserrat", size: 44).weight(.bold) }
        static func headingXL() -> Font { .custom("Montserrat", size: 35).weight(.bold) }
        static func headingL() -> Font { .custom("Montserrat", size: 28).weight(.bold) }
        static func headingM() -> Font { .custom("Montserrat", size: 23).weight(.bold) }
        static func headingS() -> Font { .custom("Montserrat", size: 18).weight(.bold) }
        
        static func body(weight: Font.Weight = .regular) -> Font { .custom("NunitoSans", size: 18).weight(weight) }
        static func caption(weight: Font.Weight = .regular) -> Font { .custom("NunitoSans", size: 14).weight(weight) }
        static func helper(weight: Font.Weight = .regular) -> Font { .custom("NunitoSans", size: 11).weight(weight) }
    }
    
    struct Spacing {
        static let screenMargin: CGFloat = 24
        static let gutter: CGFloat = 16
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let section: CGFloat = 40
    }
    
    struct Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
    }
}

// MARK: - REUSABLE STYLES & MODIFIERS

struct MSPInputStyle: ViewModifier {
    var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.body())
            .padding(.horizontal, Theme.Spacing.medium)
            .frame(minHeight: 56)
            .background(Theme.Colors.inputBackground)
            .cornerRadius(Theme.Radius.small)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(isFocused ? Theme.Colors.actionPrimary : Color.primary.opacity(0.1), lineWidth: isFocused ? 2 : 1)
            )
    }
}

struct MSPPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.body(weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(isEnabled ? Theme.Colors.primary : Color.gray.opacity(0.3))
            .cornerRadius(Theme.Radius.small)
            .shadow(color: isEnabled ? Theme.Colors.primary.opacity(0.15) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func mspInput(isFocused: Bool) -> some View {
        self.modifier(MSPInputStyle(isFocused: isFocused))
    }
}

// MARK: - Empty State Component
struct EmptyStateView: View {
    var icon: String
    var title: String
    var description: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Theme.Colors.primary.opacity(0.15)).frame(width: 96, height: 96)
                Image(systemName: icon).font(.system(size: 48)).foregroundColor(Theme.Colors.primary)
            }
            VStack(spacing: 8) {
                Text(title).font(Theme.Typography.headingM())
                Text(description)
                    .font(Theme.Typography.body())
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                }
                .buttonStyle(MSPPrimaryButtonStyle())
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Global Enums
enum SortOption: String, CaseIterable {
    case bestMatch = "Best Match"
    case priceLowToHigh = "Lowest Price"
    case priceHighToLow = "Highest Price"
    case closestFirst = "Closest First"
    
    var icon: String {
        switch self {
        case .bestMatch: return "sparkles"
        case .priceLowToHigh: return "arrow.up.right"
        case .priceHighToLow: return "arrow.down.right"
        case .closestFirst: return "location.fill"
        }
    }
}

// MARK: - App Background Pattern
struct CraigslistPattern: View {
    @Environment(\.colorScheme) var colorScheme
    
    let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0)
    ]
    
    var body: some View {
        GeometryReader { geo in
            let rowCount = Int(geo.size.height / (geo.size.width / 4)) + 2
            let totalIcons = 4 * rowCount
            
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<totalIcons, id: \.self) { index in
                    let rotation = Double((index * 37) % 360)
                    
                    Image(systemName: "bag.fill")
                        .font(.system(size: 24))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .opacity(colorScheme == .dark ? 0.08 : 0.05)
                        .rotationEffect(.degrees(rotation))
                        .frame(height: geo.size.width / 4)
                }
            }
            .offset(x: -10, y: -10)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Headers & Action Bars
struct GlassHeader: View {
    @EnvironmentObject var appState: AppState
    @Binding var searchText: String
    var placeholder: String
    var autoFocus: Bool = false
    @FocusState private var isFocused: Bool
    var onTapped: () -> Void = {}
    var onCancel: (() -> Void)? = nil
    
    @State private var showLocationSheet = false
    @State private var showAccountSheet = false
    
    @StateObject private var locationManager = LocationManager()
    @AppStorage("hasSetInitialLocation") private var hasSetInitialLocation = false
    
    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            HStack {
                Image("CraigslistIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Button(action: { showLocationSheet = true }) {
                    HStack(spacing: Theme.Spacing.small) {
                        Text(appState.selectedLocation)
                            .font(Theme.Typography.body(weight: .bold))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                .sheet(isPresented: $showLocationSheet) { LocationSelectionSheet().presentationDetents([.medium, .large]) }
                Spacer()
                
                Button(action: { showAccountSheet = true }) {
                    if let avatarUrl = appState.displayAvatarURL,
                       let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
                .sheet(isPresented: $showAccountSheet) {
                    AccountView().presentationDetents([.medium, .large])
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.top, Theme.Spacing.small)
            
            HStack(spacing: Theme.Spacing.medium) {
                HStack(spacing: Theme.Spacing.small) {
                    Image(systemName: "magnifyingglass").font(.system(size: 18)).foregroundColor(Theme.Colors.textSecondary)
                    if autoFocus {
                        TextField(placeholder, text: $searchText)
                            .focused($isFocused)
                            .font(Theme.Typography.body())
                            .onChange(of: searchText) { newValue in
                                appState.autoSelectCategory(for: newValue)
                            }
                    } else {
                        Text(placeholder)
                            .font(Theme.Typography.body())
                            .foregroundColor(searchText.isEmpty ? Theme.Colors.textSecondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                .padding(.horizontal, Theme.Spacing.medium)
                .frame(minHeight: 56)
                .background(Theme.Colors.inputBackground)
                .cornerRadius(Theme.Radius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .stroke(isFocused ? Theme.Colors.actionPrimary : Color.clear, lineWidth: 2)
                )
                .onTapGesture { onTapped() }
                
                if let cancelAction = onCancel, autoFocus {
                    Button("Cancel", action: cancelAction)
                        .font(Theme.Typography.body(weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.bottom, Theme.Spacing.medium)
        }
        .background(
            Color(.systemBackground).opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        )
        .overlay(Divider().opacity(0.3), alignment: .bottom)
        .onAppear {
            if autoFocus { DispatchQueue.main.async { isFocused = true } }
            
            if !hasSetInitialLocation {
                locationManager.requestLocation()
            }
        }
        .onChange(of: locationManager.cityNeighborhood) { _, newValue in
            if !hasSetInitialLocation, let city = newValue, let coord = locationManager.location?.coordinate {
                hasSetInitialLocation = true
                
                appState.selectedLocation = city
                appState.savedLatitude = coord.latitude
                appState.savedLongitude = coord.longitude
                
                Task {
                    await appState.fetchListings(longitude: coord.longitude, latitude: coord.latitude, radiusInMiles: 50.0)
                }
            }
        }
    }
}

struct FilterAndViewBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var viewMode: ViewMode
    @Binding var isNearbyMode: Bool
    
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    @AppStorage("sortOption") private var sortOption: SortOption = .bestMatch
    
    @State private var showFilterSheet = false
    @State private var showViewSheet = false
    @State private var showLocationSheet = false
    @State private var showSortSheet = false
    
    var currentCategoryIcon: String {
        if let cat = appState.selectedTopCategory, let match = appState.topCategories.first(where: { $0.0 == cat }) { return match.1 }
        return "slider.horizontal.3"
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.small) {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: currentCategoryIcon)
                        Text(appState.selectedTopCategory ?? "All Categories").fixedSize()
                        Image(systemName: "chevron.down")
                    }
                    .font(Theme.Typography.caption(weight: .bold))
                    .padding(.horizontal, Theme.Spacing.medium).padding(.vertical, 10)
                    .background(appState.selectedTopCategory != nil ? Theme.Colors.primary : Color.primary)
                    .cornerRadius(Theme.Radius.small)
                    .foregroundColor(Color(.systemBackground))
                }
                .sheet(isPresented: $showFilterSheet) { FilterSelectionSheet().presentationDetents([.medium, .large]) }
                
                Button(action: { showLocationSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: isNearbyMode ? "location.fill" : "location")
                        Text(isNearbyMode ? "Nearby (\(Int(nearbyDistance))mi)" : "Nearby").fixedSize()
                        Image(systemName: "chevron.down")
                    }
                    .font(Theme.Typography.caption(weight: .bold))
                    .padding(.horizontal, Theme.Spacing.medium).padding(.vertical, 10)
                    .background(isNearbyMode ? Color.primary : Theme.Colors.surfaceCard)
                    .cornerRadius(Theme.Radius.small)
                    .foregroundColor(isNearbyMode ? Color(.systemBackground) : .primary)
                }
                .sheet(isPresented: $showLocationSheet) { LocationSelectionSheet().presentationDetents([.medium, .large]) }
                
                Button(action: { showSortSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: sortOption.icon)
                        Text(sortOption.rawValue).fixedSize()
                        Image(systemName: "chevron.down")
                    }
                    .font(Theme.Typography.caption(weight: .bold))
                    .padding(.horizontal, Theme.Spacing.medium).padding(.vertical, 10)
                    .background(Color.primary)
                    .cornerRadius(Theme.Radius.small)
                    .foregroundColor(Color(.systemBackground))
                }
                .sheet(isPresented: $showSortSheet) { SortSelectionSheet(sortOption: $sortOption).presentationDetents([.height(350)]) }
                
                Button(action: { showViewSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewMode.icon)
                        Text(viewMode.rawValue).fixedSize()
                        Image(systemName: "chevron.down")
                    }
                    .font(Theme.Typography.caption(weight: .bold))
                    .padding(.horizontal, Theme.Spacing.medium).padding(.vertical, 10)
                    .background(Color.primary)
                    .cornerRadius(Theme.Radius.small)
                    .foregroundColor(Color(.systemBackground))
                }
                .sheet(isPresented: $showViewSheet) { ViewSelectionSheet(viewMode: $viewMode).presentationDetents([.height(350)]) }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
        }
    }
}

// MARK: - Sheets & Dropdowns
struct SortSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var sortOption: SortOption
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 12)
                HStack {
                    Text("Sort By").font(Theme.Typography.headingM())
                    Spacer()
                    Button("Done") { dismiss() }.font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.primary)
                }.padding(.horizontal, Theme.Spacing.screenMargin).padding(.top, 12).padding(.bottom, 12)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: { sortOption = option; dismiss() }) {
                        HStack {
                            Image(systemName: option.icon).foregroundColor(.primary).frame(width: 24, alignment: .leading)
                            Text(option.rawValue).font(Theme.Typography.body(weight: .semibold)).foregroundColor(.primary)
                            Spacer()
                            if sortOption == option { Image(systemName: "checkmark").foregroundColor(Theme.Colors.primary) }
                        }
                        .padding(.vertical, Theme.Spacing.medium).padding(.horizontal, Theme.Spacing.screenMargin)
                    }
                    if option != SortOption.allCases.last { Divider().padding(.leading, 48) }
                }
            }.padding(.top, 8)
            Spacer()
        }.background(Color(.systemBackground))
    }
}

struct ViewSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var viewMode: ViewMode
    @AppStorage("isSwipeViewEnabled") private var isSwipeViewEnabled = true
    
    var availableModes: [ViewMode] {
        ViewMode.allCases.filter { mode in
            if mode == .swipe { return isSwipeViewEnabled }
            return true
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("View Mode").font(Theme.Typography.headingM())
                    Spacer()
                    Button("Done") { dismiss() }.font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.primary)
                }.padding(.horizontal, Theme.Spacing.screenMargin).padding(.top, 24).padding(.bottom, 12)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(availableModes, id: \.self) { mode in
                    Button(action: { viewMode = mode; dismiss() }) {
                        HStack {
                            Image(systemName: mode.icon).foregroundColor(.primary).frame(width: 24, alignment: .leading)
                            Text(mode.rawValue).font(Theme.Typography.body(weight: .semibold)).foregroundColor(.primary)
                            Spacer()
                            if viewMode == mode { Image(systemName: "checkmark").foregroundColor(Theme.Colors.primary) }
                        }
                        .padding(.vertical, Theme.Spacing.medium).padding(.horizontal, Theme.Spacing.screenMargin)
                    }
                    if mode != availableModes.last { Divider().padding(.leading, 48) }
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
            VStack(spacing: Theme.Spacing.small) {
                HStack {
                    Text("Filters").font(Theme.Typography.headingL())
                    Spacer()
                    Button("Done") { dismiss() }.font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.primary)
                }
                .padding(.horizontal, Theme.Spacing.screenMargin).padding(.top, Theme.Spacing.large).padding(.bottom, Theme.Spacing.small)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("CATEGORY").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary).padding(.horizontal, Theme.Spacing.screenMargin)
                        
                        LazyVGrid(columns: columns, spacing: Theme.Spacing.large) {
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation { appState.selectedTopCategory = nil; appState.selectedSubCategory = nil }
                            }) {
                                VStack(spacing: Theme.Spacing.small) {
                                    ZStack {
                                        Circle()
                                            .fill(appState.selectedTopCategory == nil ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                                            .frame(width: appState.selectedTopCategory == nil ? 64 : 56, height: appState.selectedTopCategory == nil ? 64 : 56)
                                        
                                        Image(systemName: "square.grid.2x2.fill")
                                            .font(.system(size: appState.selectedTopCategory == nil ? 24 : 20, weight: .bold))
                                            .foregroundColor(appState.selectedTopCategory == nil ? Color(.systemBackground) : .primary)
                                    }
                                    Text("All")
                                        .font(appState.selectedTopCategory == nil ? Theme.Typography.caption(weight: .bold) : Theme.Typography.helper(weight: .bold))
                                        .foregroundColor(appState.selectedTopCategory == nil ? .primary : Theme.Colors.textSecondary)
                                }
                                .frame(width: 76)
                            }.buttonStyle(.plain)
                            
                            ForEach(appState.topCategories, id: \.0) { cat in
                                CategoryCircle(icon: cat.1, color: Theme.Colors.primary, label: cat.0)
                            }
                        }.padding(.horizontal, Theme.Spacing.screenMargin)
                    }
                    
                    Divider().padding(.horizontal, Theme.Spacing.screenMargin)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("SUBCATEGORIES").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary).padding(.horizontal, Theme.Spacing.screenMargin).padding(.bottom, Theme.Spacing.small)
                        
                        VStack(spacing: 0) {
                            ForEach(activeSubs, id: \.self) { sub in
                                Button(action: {
                                    withAnimation(.spring()) {
                                        appState.selectedSubCategory = (appState.selectedSubCategory == sub) ? nil : sub
                                    }
                                }) {
                                    HStack {
                                        Text(sub)
                                            .font(Theme.Typography.body(weight: appState.selectedSubCategory == sub ? .bold : .regular))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if appState.selectedSubCategory == sub {
                                            Image(systemName: "checkmark").foregroundColor(Theme.Colors.primary)
                                        }
                                    }
                                    .padding(.vertical, Theme.Spacing.medium)
                                    .padding(.horizontal, Theme.Spacing.screenMargin)
                                }
                                Divider().padding(.leading, Theme.Spacing.screenMargin)
                            }
                        }
                    }
                }
                .padding(.top, Theme.Spacing.small).padding(.bottom, 40)
            }
        }
        .background(Color(.systemBackground))
    }
}

struct LocationSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService = LocationSearchService()
    
    @AppStorage("isNearbyMode") private var isNearbyMode = true
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    
    @State private var isGeocoding: Bool = false
    let radii = [1, 5, 10, 25]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("Location").font(Theme.Typography.headingM())
                    Spacer()
                    Button("Done") { dismiss() }.font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.primary)
                }
                .padding(.horizontal, Theme.Spacing.screenMargin).padding(.top, 24).padding(.bottom, 12)
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MANUAL LOCATION").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(Theme.Colors.textSecondary)
                            TextField("Enter city, state, or zip...", text: $searchService.searchQuery)
                                .font(Theme.Typography.body())
                                .disableAutocorrection(true)
                            
                            if isGeocoding {
                                ProgressView().scaleEffect(0.8)
                            } else if !searchService.searchQuery.isEmpty {
                                Button(action: { searchService.searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(Theme.Colors.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .background(Theme.Colors.surfaceGray)
                        .cornerRadius(Theme.Radius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.small)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.screenMargin)

                    if !searchService.completions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("SUGGESTIONS").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary).padding(.horizontal, Theme.Spacing.screenMargin).padding(.bottom, 8)
                            
                            ForEach(searchService.completions, id: \.self) { completion in
                                Button(action: { selectCompletion(completion) }) {
                                    HStack {
                                        Image(systemName: "mappin.and.ellipse").foregroundColor(Theme.Colors.textSecondary)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(completion.title).font(Theme.Typography.body()).foregroundColor(.primary)
                                            if !completion.subtitle.isEmpty {
                                                Text(completion.subtitle).font(Theme.Typography.caption()).foregroundColor(Theme.Colors.textSecondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 14).padding(.horizontal, Theme.Spacing.screenMargin)
                                }
                                Divider().padding(.leading, 48)
                            }
                        }
                    } else {
                        Button(action: { locationManager.requestLocation() }) {
                            HStack {
                                Image(systemName: "location.fill")
                                if locationManager.isRequesting {
                                    Text("Locating...")
                                    Spacer()
                                    ProgressView()
                                } else {
                                    Text("Use Current Location")
                                }
                            }
                            .font(Theme.Typography.body(weight: .semibold)).foregroundColor(.primary).frame(maxWidth: .infinity, alignment: .leading)
                            .padding().background(Theme.Colors.surfaceGray).cornerRadius(Theme.Radius.small)
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        .onChange(of: locationManager.cityNeighborhood) { _, newValue in
                            if let city = newValue, let coord = locationManager.location?.coordinate {
                                updateLocationAndFetch(city: city, coordinate: coord)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("NEARBY MODE").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                            Toggle(isOn: $isNearbyMode) { Text("Prioritize nearby items & deals").font(Theme.Typography.body()) }
                                .tint(Theme.Colors.primary)
                            
                            if isNearbyMode {
                                Divider().padding(.vertical, 4)
                                Stepper(value: $nearbyDistance, in: 1...50, step: 1) {
                                    Text("Distance: \(Int(nearbyDistance)) miles")
                                        .font(Theme.Typography.body(weight: .semibold))
                                }
                            }
                        }.padding(.horizontal, Theme.Spacing.screenMargin)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SEARCH RADIUS").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                            HStack(spacing: 8) {
                                ForEach(radii, id: \.self) { radius in
                                    Button(action: { nearbyDistance = Double(radius) }) {
                                        Text("\(radius) miles")
                                            .font(Theme.Typography.caption(weight: .semibold))
                                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                                            .background(Int(nearbyDistance) == radius ? Theme.Colors.primary : Theme.Colors.surfaceGray)
                                            .foregroundColor(Int(nearbyDistance) == radius ? Color(.systemBackground) : .primary)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }.padding(.horizontal, Theme.Spacing.screenMargin)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        isGeocoding = true
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            DispatchQueue.main.async {
                isGeocoding = false
                if let coordinate = response?.mapItems.first?.placemark.coordinate {
                    let subtitleSuffix = completion.subtitle.isEmpty ? "" : ", \(completion.subtitle.components(separatedBy: ",").first ?? "")"
                    let cityLabel = completion.title + subtitleSuffix
                    
                    updateLocationAndFetch(city: cityLabel, coordinate: coordinate)
                } else {
                    appState.triggerToast(message: "Location not found.")
                }
            }
        }
    }

    private func updateLocationAndFetch(city: String, coordinate: CLLocationCoordinate2D) {
        appState.selectedLocation = city
        appState.savedLatitude = coordinate.latitude
        appState.savedLongitude = coordinate.longitude
        
        Task {
            await appState.fetchListings(longitude: coordinate.longitude, latitude: coordinate.latitude, radiusInMiles: nearbyDistance)
        }
        dismiss()
    }
}

// MARK: - Subcomponents
struct CategoryCircle: View {
    @EnvironmentObject var appState: AppState
    var icon: String; var color: Color; var label: String
    var onTap: (() -> Void)? = nil
    var isSelected: Bool { appState.selectedTopCategory == label }
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                if appState.selectedTopCategory == label {
                    appState.selectedTopCategory = nil; appState.selectedSubCategory = nil
                } else {
                    appState.selectedTopCategory = label; appState.selectedSubCategory = nil
                }
            }
            onTap?()
        }) {
            VStack(spacing: Theme.Spacing.small) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                        .frame(width: isSelected ? 64 : 56, height: isSelected ? 64 : 56)
                        .shadow(color: isSelected ? Theme.Colors.primary.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                    
                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 24 : 20, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                Text(label)
                    .font(isSelected ? Theme.Typography.caption(weight: .bold) : Theme.Typography.helper(weight: .bold))
                    .foregroundColor(isSelected ? .primary : Theme.Colors.textSecondary)
            }
            .frame(width: 76)
        }.buttonStyle(.plain)
    }
}

struct CraigslistCategoryBrowser: View {
    @EnvironmentObject var appState: AppState
    
    var activeSubs: [String] {
        if let topCat = appState.selectedTopCategory, let subs = appState.subCategories[topCat] { return subs }
        return ["Free", "Furniture", "Electronics", "Apts / Housing", "Cars", "Gigs"]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(appState.topCategories, id: \.0) { cat in
                        CategoryCircle(icon: cat.1, color: Theme.Colors.primary, label: cat.0)
                    }
                }.padding(.horizontal, 20).padding(.vertical, 8)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(activeSubs, id: \.self) { sub in
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.spring()) {
                                if appState.selectedSubCategory == sub { appState.selectedSubCategory = nil }
                                else { appState.selectedSubCategory = sub }
                            }
                        }) {
                            Text(sub).font(Theme.Typography.caption(weight: appState.selectedSubCategory == sub ? .bold : .semibold)).padding(.horizontal, 16).padding(.vertical, 8)
                                .background(appState.selectedSubCategory == sub ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                                .foregroundColor(appState.selectedSubCategory == sub ? Color(.systemBackground) : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }.padding(.horizontal, Theme.Spacing.screenMargin)
            }
        }
    }
}

struct RecentSearchRow: View {
    var icon: String; var title: String; var subtitle: String; var isItem: Bool = false
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.Colors.surfaceCard).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(isItem ? Theme.Colors.primary : Theme.Colors.textSecondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.Typography.body(weight: .bold)).foregroundColor(.primary)
                Text(subtitle).font(Theme.Typography.caption()).foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
        }.padding(.horizontal, Theme.Spacing.screenMargin)
    }
}
