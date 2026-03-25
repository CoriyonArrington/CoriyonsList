import SwiftUI

// MARK: - App Background Pattern
struct CraigslistPattern: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Calculates a perfect grid based on screen size
    let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0)
    ]
    
    var body: some View {
        GeometryReader { geo in
            // Calculate enough rows to safely cover any screen height
            let rowCount = Int(geo.size.height / (geo.size.width / 4)) + 2
            let totalIcons = 4 * rowCount
            
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<totalIcons, id: \.self) { index in
                    let rotation = Double((index * 37) % 360)
                    
                    Image("CraigslistIcon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        // Bumps Light Mode opacity so it's visible but subtle
                        .opacity(colorScheme == .dark ? 0.06 : 0.03)
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
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image("CraigslistIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color.craigslistPurple)
                
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
                Image(systemName: "person.circle.fill").resizable().frame(width: 30, height: 30).foregroundColor(Color.craigslistPurple)
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
                        .foregroundColor(Color.craigslistPurple).transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(
            ZStack {
                Color(.systemBackground).opacity(0.95)
            }
            .background(.ultraThinMaterial)
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
    @Binding var isNearbyMode: Bool
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    
    @State private var showFilterSheet = false
    @State private var showViewSheet = false
    @State private var showLocationSheet = false
    
    var currentCategoryIcon: String {
        if let cat = appState.selectedTopCategory,
           let match = appState.topCategories.first(where: { $0.0 == cat }) {
            return match.1
        }
        return "slider.horizontal.3"
    }
    
    var mutedColor: Color {
        guard let label = appState.selectedTopCategory else { return Color.primary }
        switch label {
        case "For Sale": return Color.craigslistPurple
        case "Housing": return Color(red: 0.75, green: 0.45, blue: 0.35)
        case "Jobs": return Color(red: 0.35, green: 0.60, blue: 0.45)
        case "Community": return .blue
        case "Services": return Color(red: 0.75, green: 0.40, blue: 0.50)
        case "Gigs": return Color(red: 0.70, green: 0.55, blue: 0.30)
        default: return Color.primary
        }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: currentCategoryIcon)
                        Text(appState.selectedTopCategory ?? "All Categories").fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "chevron.down")
                    }
                    .font(.custom("Montserrat", size: 13).weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(appState.selectedTopCategory != nil ? mutedColor : Color.primary)
                    .cornerRadius(16)
                    .foregroundColor(appState.selectedTopCategory != nil ? Color.white : Color(.systemBackground))
                }
                .sheet(isPresented: $showFilterSheet) { FilterSelectionSheet().presentationDetents([.medium, .large]) }
                
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    showLocationSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isNearbyMode ? "location.fill" : "location")
                        Text(isNearbyMode ? "Nearby (\(Int(nearbyDistance)) mi)" : "Nearby").fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "chevron.down")
                    }
                    .font(.custom("Montserrat", size: 13).weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isNearbyMode ? Color.primary : Color(.systemGray5).opacity(0.8))
                    .cornerRadius(16)
                    .foregroundColor(isNearbyMode ? Color(.systemBackground) : .primary)
                }
                .sheet(isPresented: $showLocationSheet) { LocationSelectionSheet().presentationDetents([.medium, .large]) }
                
                Button(action: { showViewSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewMode.icon)
                        Text(viewMode.rawValue).fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "chevron.down")
                    }
                    .font(.custom("Montserrat", size: 13).weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 8).background(Color(.systemGray5).opacity(0.8)).cornerRadius(16).foregroundColor(.primary)
                }
                .sheet(isPresented: $showViewSheet) { ViewSelectionSheet(viewMode: $viewMode).presentationDetents([.height(350)]) }
                
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Sheets & Dropdowns
struct ViewSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var viewMode: ViewMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("View Mode").font(.custom("Montserrat", size: 17).weight(.bold))
                    Spacer()
                    Button("Done") { dismiss() }.font(.custom("Montserrat", size: 17).weight(.bold)).foregroundColor(.primary)
                }.padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 12)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button(action: { viewMode = mode; dismiss() }) {
                        HStack {
                            Image(systemName: mode.icon).foregroundColor(.primary).frame(width: 24, alignment: .leading)
                            Text(mode.rawValue).font(.custom("NunitoSans", size: 16).weight(.semibold)).foregroundColor(.primary)
                            Spacer()
                            if viewMode == mode { Image(systemName: "checkmark").foregroundColor(.primary) }
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
            headerView
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    topCategoriesSection
                    Divider().padding(.horizontal, 16)
                    subCategoriesSection
                }
                .padding(.top, 8).padding(.bottom, 40)
            }
        }
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Filters").font(.custom("Montserrat", size: 17).weight(.bold))
                Spacer()
                Button("Done") { dismiss() }.font(.custom("Montserrat", size: 17).weight(.bold)).foregroundColor(.primary)
            }
            .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 12)
        }
    }
    
    @ViewBuilder
    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CATEGORY").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary).padding(.horizontal, 16)
            
            LazyVGrid(columns: columns, spacing: 24) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appState.selectedTopCategory = nil; appState.selectedSubCategory = nil }
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(appState.selectedTopCategory == nil ? Color.primary : Color(.systemGray5))
                                .frame(width: appState.selectedTopCategory == nil ? 64 : 56, height: appState.selectedTopCategory == nil ? 64 : 56)
                                .shadow(color: appState.selectedTopCategory == nil ? Color.primary.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                            
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: appState.selectedTopCategory == nil ? 24 : 20, weight: appState.selectedTopCategory == nil ? .bold : .medium))
                                .foregroundColor(appState.selectedTopCategory == nil ? Color(.systemBackground) : .primary)
                        }
                        
                        Text("All")
                            .font(.custom(appState.selectedTopCategory == nil ? "Montserrat" : "NunitoSans", size: 12).weight(appState.selectedTopCategory == nil ? .bold : .medium))
                            .foregroundColor(appState.selectedTopCategory == nil ? .primary : .secondary)
                    }
                    .frame(width: 76)
                }.buttonStyle(.plain)
                
                ForEach(appState.topCategories, id: \.0) { cat in
                    CategoryCircle(icon: cat.1, color: Color.craigslistPurple, label: cat.0)
                }
            }.padding(.horizontal, 16).padding(.top, 16)
        }
    }
    
    @ViewBuilder
    private var subCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SUBCATEGORIES").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.bottom, 8)
            
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
                                .font(.custom("NunitoSans", size: 16).weight(appState.selectedSubCategory == sub ? .bold : .medium))
                                .foregroundColor(appState.selectedSubCategory == sub ? .primary : .primary)
                            Spacer()
                            if appState.selectedSubCategory == sub {
                                Image(systemName: "checkmark").foregroundColor(.primary)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                    Divider().padding(.leading, 16)
                }
            }
        }
    }
}

struct LocationSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @AppStorage("isNearbyMode") private var isNearbyMode = true
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    
    let cities = ["Minneapolis, MN", "St. Paul, MN", "Bloomington, MN", "Brooklyn Center, MN", "Edina, MN", "Plymouth, MN"]
    let neighborhoods = ["North Loop", "Uptown", "Northeast", "Downtown", "Linden Hills", "Dinkytown"]
    let radii = [1, 5, 10, 25]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    currentLocationButton
                    nearbyModeSection
                    searchRadiusSection
                    neighborhoodsSection
                    citiesSection
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Location").font(.custom("Montserrat", size: 17).weight(.bold))
                Spacer()
                Button("Done") { dismiss() }.font(.custom("Montserrat", size: 17).weight(.bold)).foregroundColor(.primary)
            }
            .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 12)
        }
    }
    
    @ViewBuilder
    private var currentLocationButton: some View {
        Button(action: {}) {
            HStack { Image(systemName: "location.fill"); Text("Use Current Location") }
            .font(.custom("Montserrat", size: 16).weight(.semibold)).foregroundColor(.primary).frame(maxWidth: .infinity, alignment: .leading)
            .padding().background(Color(.systemGray5)).cornerRadius(12)
        }.padding(.horizontal, 16).padding(.top, 16)
    }
    
    @ViewBuilder
    private var nearbyModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEARBY MODE").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary)
            Toggle(isOn: $isNearbyMode) { Text("Prioritize nearby items & deals").font(.custom("NunitoSans", size: 16).weight(.regular)) }
                .tint(Color.craigslistPurple)
            
            if isNearbyMode {
                Divider().padding(.vertical, 4)
                Stepper(value: $nearbyDistance, in: 1...50, step: 1) {
                    Text("Distance: \(Int(nearbyDistance)) miles")
                        .font(.custom("NunitoSans", size: 16).weight(.semibold))
                }
            }
        }.padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var searchRadiusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SEARCH RADIUS").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach(radii, id: \.self) { radius in
                    Button(action: { nearbyDistance = Double(radius) }) {
                        Text("\(radius) miles")
                            .font(.custom("NunitoSans", size: 14).weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Int(nearbyDistance) == radius ? Color.primary : Color(.systemGray5))
                            .foregroundColor(Int(nearbyDistance) == radius ? Color(.systemBackground) : .primary)
                            .cornerRadius(20)
                    }
                }
            }
        }.padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var neighborhoodsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NEIGHBORHOODS").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.bottom, 8)
            ForEach(neighborhoods, id: \.self) { loc in
                Button(action: { appState.selectedLocation = loc; dismiss() }) {
                    HStack { Image(systemName: "mappin.and.ellipse").foregroundColor(.secondary); Text(loc).font(.custom("NunitoSans", size: 16).weight(.regular)).foregroundColor(.primary); Spacer(); if appState.selectedLocation == loc { Image(systemName: "checkmark").foregroundColor(.primary) } }
                    .padding(.vertical, 14).padding(.horizontal, 16)
                }
                Divider().padding(.leading, 48)
            }
        }
    }
    
    @ViewBuilder
    private var citiesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CITIES").font(.custom("Montserrat", size: 12).weight(.bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.bottom, 8)
            ForEach(cities, id: \.self) { loc in
                Button(action: { appState.selectedLocation = loc; dismiss() }) {
                    HStack { Image(systemName: "building.2.fill").foregroundColor(.secondary); Text(loc).font(.custom("NunitoSans", size: 16).weight(.regular)).foregroundColor(.primary); Spacer(); if appState.selectedLocation == loc { Image(systemName: "checkmark").foregroundColor(.primary) } }
                    .padding(.vertical, 14).padding(.horizontal, 16)
                }
                if loc != cities.last { Divider().padding(.leading, 48) }
            }
        }
    }
}

// MARK: - Subcomponents
struct CategoryCircle: View {
    @EnvironmentObject var appState: AppState
    var icon: String; var color: Color; var label: String
    var onTap: (() -> Void)? = nil
    var isSelected: Bool { appState.selectedTopCategory == label }
    
    var mutedColor: Color {
        switch label {
        case "For Sale": return Color.craigslistPurple
        case "Housing": return Color(red: 0.75, green: 0.45, blue: 0.35)
        case "Jobs": return Color(red: 0.35, green: 0.60, blue: 0.45)
        case "Community": return .blue
        case "Services": return Color(red: 0.75, green: 0.40, blue: 0.50)
        case "Gigs": return Color(red: 0.70, green: 0.55, blue: 0.30)
        default: return color
        }
    }
    
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
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? mutedColor : Color(.systemGray5))
                        .frame(width: isSelected ? 64 : 56, height: isSelected ? 64 : 56)
                        .shadow(color: isSelected ? mutedColor.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
                    
                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 24 : 20, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                Text(label)
                    .font(.custom(isSelected ? "Montserrat" : "NunitoSans", size: 12).weight(isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? .primary : .secondary)
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
        VStack(alignment: .leading, spacing: 16) {
            topCategoriesScroll
            subCategoriesScroll
        }
    }
    
    @ViewBuilder
    private var topCategoriesScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(appState.topCategories, id: \.0) { cat in
                    CategoryCircle(icon: cat.1, color: Color.craigslistPurple, label: cat.0)
                }
            }.padding(.horizontal, 20).padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var subCategoriesScroll: some View {
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
                        Text(sub).font(.custom("NunitoSans", size: 14).weight(appState.selectedSubCategory == sub ? .bold : .semibold)).padding(.horizontal, 16).padding(.vertical, 8)
                            .background(appState.selectedSubCategory == sub ? Color.primary : Color(.systemGray5))
                            .foregroundColor(appState.selectedSubCategory == sub ? Color(.systemBackground) : .primary)
                            .clipShape(Capsule())
                    }
                }
            }.padding(.horizontal, 16)
        }
    }
}

struct RecentSearchRow: View {
    var icon: String; var title: String; var subtitle: String; var isItem: Bool = false
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color(.systemGray5).opacity(0.6)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(isItem ? Color.craigslistPurple : .secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.custom("Montserrat", size: 16).weight(.bold)).foregroundColor(.primary)
                Text(subtitle).font(.custom("NunitoSans", size: 14).weight(.regular)).foregroundColor(.secondary)
            }
            Spacer()
        }.padding(.horizontal, 16)
    }
}
