import SwiftUI
import MapKit
import PhotosUI

struct PostView: View {
    @EnvironmentObject var appState: AppState
    
    // MARK: - Form State
    @State private var currentStep = 1
    @State private var title = ""
    @State private var price = ""
    @State private var itemDescription = ""
    @State private var condition = "Like New"
    @State private var selectedTopCategory: String? = nil
    @State private var selectedSubCategory: String? = nil
    
    // PhotosUI & AI State
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    @State private var isScanningImage = false
    @State private var showAIInsights = false
    @State private var isGeneratingDetails = false
    @State private var hasGeneratedDetails = false
    
    // Overlays & Focus
    @FocusState private var isInputFocused: Bool
    @State private var showLocationSheet = false
    @State private var showPreviewDetail = false
    
    let conditions = ["New", "Like New", "Excellent", "Good", "Fair", "Salvage"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                CraigslistPattern()
                
                // Main Scrollable Content
                TabView(selection: $currentStep) {
                    stepOneBasics.tag(1)
                    stepTwoDetails.tag(2)
                    stepThreeReview.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Centered Main Title
                ToolbarItem(placement: .principal) {
                    Text("Create Post")
                        .font(Theme.Typography.body(weight: .bold))
                        .foregroundColor(.primary)
                }
                
                // Right Aligned Step Counter & Progress Bar
                ToolbarItem(placement: .navigationBarTrailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Step \(currentStep) of 3")
                            .font(Theme.Typography.caption(weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Theme.Colors.surfaceGray)
                                    .frame(height: 4)
                                
                                Capsule()
                                    .fill(Theme.Colors.primary)
                                    .frame(width: geo.size.width * (CGFloat(currentStep) / 3.0), height: 4)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                            }
                        }
                        .frame(width: 70, height: 4)
                    }
                }
                
                // Left Action Button
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep == 1 {
                        Button("Cancel") { resetForm() }
                            .font(Theme.Typography.body(weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    } else {
                        Button(action: { goBackStep() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(Theme.Typography.body(weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                        }
                    }
                }
            }
            .toolbarBackground(Color(.systemBackground).opacity(0.95), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                footerView
            }
            .onTapGesture {
                isInputFocused = false
            }
            // Trigger the native location sheet for edits
            .sheet(isPresented: $showLocationSheet) {
                LocationSelectionSheet().presentationDetents([.medium, .large])
            }
            // Real Full Screen Preview of the active draft
            .fullScreenCover(isPresented: $showPreviewDetail) {
                let previewListing = Listing(
                    id: UUID(),
                    title: title.isEmpty ? "Untitled Listing" : title,
                    price: Int(price) ?? 0,
                    coordinate: CLLocationCoordinate2D(latitude: 44.9778, longitude: -93.2650),
                    neighborhood: appState.selectedLocation,
                    distance: 0.1,
                    description: itemDescription.isEmpty ? "No description provided." : itemDescription,
                    category: selectedSubCategory ?? selectedTopCategory ?? "For Sale",
                    datePosted: Date(),
                    condition: condition,
                    images: saveImagesLocally(),
                    sellerName: "Coriyon Arrington",
                    sellerType: "Private Owner",
                    sellerAvatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200",
                    sellerRating: 5.0,
                    reviewCount: 0,
                    tags: ["preview"]
                )
                
                NavigationStack {
                    ListingDetailView(
                        listing: previewListing,
                        allIDs: [previewListing.id],
                        selectedListingID: .constant(previewListing.id),
                        onDismiss: { showPreviewDetail = false },
                        onDelete: { showPreviewDetail = false }
                    )
                }
            }
        }
    }
    
    // MARK: - Sticky Footer
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)
            VStack {
                Button(action: {
                    if currentStep < 3 { advanceStep() }
                    else { publishListing() }
                }) {
                    Text(currentStep < 3 ? "Next" : "Post")
                }
                .buttonStyle(MSPPrimaryButtonStyle(isEnabled: canProceed))
                .disabled(!canProceed)
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.top, Theme.Spacing.medium)
                .padding(.bottom, Theme.Spacing.medium)
            }
            .background(
                Color(.systemBackground).opacity(0.95)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
    
    // MARK: - Step 1: Photos, Title, Price
    private var stepOneBasics: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                Text("What are you selling?")
                    .font(Theme.Typography.headingL())
                    .padding(.top, Theme.Spacing.large)
                
                // Prominent Photos Picker Area
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    if selectedImages.isEmpty {
                        // Empty State: Large Prominent Drop Zone
                        PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                            VStack(spacing: Theme.Spacing.medium) {
                                Image(systemName: "camera.fill").font(.system(size: 40))
                                Text("Add Photos").font(Theme.Typography.body(weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .background(Theme.Colors.surfaceCard)
                            .foregroundColor(Theme.Colors.primary)
                            .cornerRadius(Theme.Radius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                                    .stroke(Theme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                            )
                        }
                        
                        Text("Add at least 1 photo of the item you're selling.")
                            .font(Theme.Typography.caption())
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.top, 4)
                            .padding(.horizontal, 4)
                    } else {
                        // Filled State: Horizontal Scroll with "Add More" button
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.small) {
                                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                                    VStack(spacing: Theme.Spacing.small) {
                                        Image(systemName: "camera.fill").font(.system(size: 28))
                                        Text("Add More").font(Theme.Typography.helper(weight: .bold))
                                    }
                                    .frame(width: 110, height: 110)
                                    .background(Theme.Colors.surfaceCard)
                                    .foregroundColor(Theme.Colors.primary)
                                    .cornerRadius(Theme.Radius.medium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.medium)
                                            .stroke(Theme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    )
                                }
                                
                                ForEach(selectedImages, id: \.self) { image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
                                }
                            }
                        }
                    }
                    
                    // AI Image Scanning
                    if isScanningImage {
                        HStack(spacing: Theme.Spacing.small) {
                            ProgressView().tint(Theme.Colors.primary)
                            Text("Analyzing image...")
                                .font(Theme.Typography.caption(weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.top, Theme.Spacing.small)
                        .transition(.opacity)
                    } else if showAIInsights {
                        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("AI Insights").font(Theme.Typography.caption(weight: .bold))
                            }
                            .foregroundColor(Theme.Colors.primary)
                            
                            Text("Looks like a **Standing Desk**! Here are some suggestions based on similar listings nearby:")
                                .font(Theme.Typography.caption())
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                            
                            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                Text("SUGGESTED TITLES").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Spacing.small) {
                                        ForEach(["Standing Desk", "Adjustable Standing Desk", "Electric Sit-Stand Desk"], id: \.self) { sug in
                                            Button(action: {
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                                title = sug
                                            }) {
                                                Text(sug)
                                                    .font(Theme.Typography.body(weight: .bold))
                                                    .frame(minHeight: 48)
                                                    .padding(.horizontal, Theme.Spacing.medium)
                                                    .background(title == sug ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.1))
                                                    .foregroundColor(title == sug ? .white : Theme.Colors.primary)
                                                    .cornerRadius(24)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                Text("SUGGESTED PRICES").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.Spacing.small) {
                                        ForEach(["150", "175", "200"], id: \.self) { sug in
                                            Button(action: {
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                                price = sug
                                            }) {
                                                Text("$\(sug)")
                                                    .font(Theme.Typography.body(weight: .bold))
                                                    .frame(minHeight: 48)
                                                    .padding(.horizontal, Theme.Spacing.medium)
                                                    .background(price == sug ? Theme.Colors.success : Theme.Colors.success.opacity(0.1))
                                                    .foregroundColor(price == sug ? .white : Theme.Colors.success)
                                                    .cornerRadius(24)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(Theme.Spacing.large)
                        .background(Theme.Colors.surfaceCard)
                        .cornerRadius(Theme.Radius.medium)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1))
                        .padding(.top, Theme.Spacing.small)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .onChange(of: selectedPhotoItems) { newItems in loadSelectedPhotos(from: newItems) }
                
                // Fields
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("TITLE").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    TextField("e.g. Vintage Leather Sofa", text: $title)
                        .focused($isInputFocused)
                        .mspInput(isFocused: isInputFocused)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("PRICE").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    HStack {
                        Text("$").font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                        TextField("0", text: $price)
                            .focused($isInputFocused)
                            .keyboardType(.numberPad)
                    }
                    .mspInput(isFocused: isInputFocused)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.bottom, Theme.Spacing.section)
        }
    }
    
    // MARK: - Step 2: Category, Condition, Description
    private var stepTwoDetails: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                Text("Add some details")
                    .font(Theme.Typography.headingL())
                    .padding(.top, Theme.Spacing.large)
                
                if isGeneratingDetails {
                    VStack(spacing: Theme.Spacing.medium) {
                        ProgressView().scaleEffect(1.5).tint(Theme.Colors.primary)
                        Text("Drafting description & categorizing...")
                            .font(Theme.Typography.body(weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    // Category Selection
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        HStack {
                            Text("CATEGORY").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                            if hasGeneratedDetails {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("AI Selected").font(Theme.Typography.helper(weight: .bold))
                                }.foregroundColor(Theme.Colors.primary)
                            }
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.medium) {
                                ForEach(appState.topCategories, id: \.0) { cat in
                                    PostCategoryCircle(
                                        icon: cat.1, label: cat.0, isSelected: selectedTopCategory == cat.0,
                                        action: { selectedTopCategory = cat.0; selectedSubCategory = nil }
                                    )
                                }
                            }
                        }
                        
                        if let topCat = selectedTopCategory, let subs = appState.subCategories[topCat] {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.small) {
                                    ForEach(subs, id: \.self) { sub in
                                        Button(action: {
                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                            generator.impactOccurred()
                                            selectedSubCategory = sub
                                        }) {
                                            Text(sub)
                                                .font(Theme.Typography.caption(weight: selectedSubCategory == sub ? .bold : .semibold))
                                                .frame(minHeight: 44)
                                                .padding(.horizontal, Theme.Spacing.medium)
                                                .background(selectedSubCategory == sub ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                                                .foregroundColor(selectedSubCategory == sub ? .white : .primary)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                        }
                                    }
                                }
                            }
                            .padding(.top, Theme.Spacing.small)
                        }
                    }
                    
                    // Condition
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("CONDITION").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.small) {
                                ForEach(conditions, id: \.self) { cond in
                                    Button(action: {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        condition = cond
                                    }) {
                                        Text(cond)
                                            .font(Theme.Typography.caption(weight: condition == cond ? .bold : .semibold))
                                            .frame(minHeight: 44)
                                            .padding(.horizontal, Theme.Spacing.medium)
                                            .background(condition == cond ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                                            .foregroundColor(condition == cond ? Color(.systemBackground) : .primary)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        HStack {
                            Text("DESCRIPTION").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                            if hasGeneratedDetails {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("AI Generated").font(Theme.Typography.helper(weight: .bold))
                                }.foregroundColor(Theme.Colors.primary)
                            }
                        }
                        
                        TextEditor(text: $itemDescription)
                            .focused($isInputFocused)
                            .scrollContentBackground(.hidden)
                            .font(Theme.Typography.body())
                            .frame(height: 140)
                            .padding(8)
                            .background(Theme.Colors.inputBackground)
                            .cornerRadius(Theme.Radius.small)
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(isInputFocused ? Theme.Colors.actionPrimary : Color.primary.opacity(0.1), lineWidth: isInputFocused ? 2 : 1))
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.bottom, Theme.Spacing.section)
        }
    }
    
    // MARK: - Step 3: Location & Review
    private var stepThreeReview: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                Text("Review & Post")
                    .font(Theme.Typography.headingL())
                    .padding(.top, Theme.Spacing.large)
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("MEETUP LOCATION").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    HStack {
                        Image(systemName: "location.fill").foregroundColor(Theme.Colors.primary).font(.system(size: 18))
                        Text(appState.selectedLocation).font(Theme.Typography.body(weight: .bold)).foregroundColor(.primary)
                        Spacer()
                        
                        // Active Location Edit Button
                        Button(action: { showLocationSheet = true }) {
                            Text("Edit").font(Theme.Typography.caption(weight: .bold)).foregroundColor(Theme.Colors.actionPrimary)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.medium)
                    .frame(minHeight: 56)
                    .background(Theme.Colors.inputBackground)
                    .cornerRadius(Theme.Radius.small)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("LISTING PREVIEW").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    
                    // Active Preview Button
                    Button(action: { showPreviewDetail = true }) {
                        HStack(spacing: Theme.Spacing.medium) {
                            if let firstImg = selectedImages.first {
                                Image(uiImage: firstImg)
                                    .resizable().scaledToFill().frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                            } else {
                                Color(.systemGray4).frame(width: 88, height: 88).cornerRadius(Theme.Radius.small)
                                    .overlay(Image(systemName: "photo").font(.system(size: 24)).foregroundColor(.gray))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(title.isEmpty ? "Untitled Listing" : title)
                                    .font(Theme.Typography.body(weight: .bold)).foregroundColor(.primary).lineLimit(1)
                                Text("$\(price.isEmpty ? "0" : price)")
                                    .font(Theme.Typography.body(weight: .heavy)).foregroundColor(Theme.Colors.success)
                                Text("\(selectedSubCategory ?? selectedTopCategory ?? "For Sale") • \(condition)")
                                    .font(Theme.Typography.caption(weight: .semibold)).foregroundColor(Theme.Colors.textSecondary).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(Theme.Spacing.medium)
                        .background(Theme.Colors.inputBackground)
                        .cornerRadius(Theme.Radius.medium)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.bottom, Theme.Spacing.section)
        }
    }
    
    // MARK: - Logic
    private var canProceed: Bool { currentStep == 1 ? (!title.isEmpty && !price.isEmpty) : true }
    
    private func advanceStep() {
        if currentStep == 1 {
            withAnimation { currentStep += 1 }
            if !hasGeneratedDetails {
                isGeneratingDetails = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    guessCategoryFromTitle()
                    autoGenerateDescription()
                    withAnimation { isGeneratingDetails = false; hasGeneratedDetails = true }
                }
            }
        } else if currentStep == 2 {
            withAnimation { currentStep += 1 }
        }
    }
    
    private func goBackStep() { withAnimation { currentStep -= 1 } }
    
    private func guessCategoryFromTitle() {
        let q = title.lowercased()
        if q.contains("desk") || q.contains("chair") || q.contains("table") || q.contains("sofa") { selectedTopCategory = "For Sale"; selectedSubCategory = "Furniture" }
        else if q.contains("laptop") || q.contains("tv") || q.contains("macbook") { selectedTopCategory = "For Sale"; selectedSubCategory = "Electronics" }
        else if q.contains("bike") || q.contains("trek") { selectedTopCategory = "For Sale"; selectedSubCategory = "Bikes" }
        else if q.contains("apartment") || q.contains("rent") { selectedTopCategory = "Housing"; selectedSubCategory = "Apts / Housing" }
        else { selectedTopCategory = "For Sale"; selectedSubCategory = "Furniture" }
    }
    
    private func autoGenerateDescription() {
        let cat = selectedSubCategory ?? selectedTopCategory ?? "item"
        withAnimation { itemDescription = "Selling my \(condition.lowercased()) \(title). It's a great \(cat.lowercased()) and works perfectly. I am located in \(appState.selectedLocation) and am looking to sell as soon as possible. Feel free to message me if you have any questions!" }
    }
    
    private func loadSelectedPhotos(from items: [PhotosPickerItem]) {
        Task {
            var newImages: [UIImage] = []
            for item in items { if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { newImages.append(image) } }
            DispatchQueue.main.async {
                self.selectedImages = newImages
                if !self.selectedImages.isEmpty && !self.showAIInsights {
                    withAnimation { self.isScanningImage = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            self.isScanningImage = false
                            self.showAIInsights = true
                            if self.title.isEmpty { self.title = "Standing Desk" }
                            if self.price.isEmpty { self.price = "150" }
                        }
                    }
                }
            }
        }
    }
    
    private func saveImagesLocally() -> [String] {
        var urls: [String] = []
        for image in selectedImages {
            if let data = image.jpegData(compressionQuality: 0.8) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                try? data.write(to: url); urls.append(url.absoluteString)
            }
        }
        if urls.isEmpty { urls.append("https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?q=80&w=800&auto=format&fit=crop") }
        return urls
    }
    
    private func publishListing() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        let newListing = Listing(
            id: UUID(),
            title: title.isEmpty ? "Untitled Listing" : title,
            price: Int(price) ?? 0,
            coordinate: CLLocationCoordinate2D(latitude: 44.9778 + Double.random(in: -0.02...0.02), longitude: -93.2650 + Double.random(in: -0.02...0.02)),
            neighborhood: appState.selectedLocation,
            distance: 0.1,
            description: itemDescription.isEmpty ? "No description provided." : itemDescription,
            category: selectedSubCategory ?? selectedTopCategory ?? "For Sale",
            datePosted: Date(),
            condition: condition,
            images: saveImagesLocally(),
            sellerName: "Coriyon Arrington",
            sellerType: "Private Owner",
            sellerAvatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200",
            sellerRating: 5.0,
            reviewCount: 0,
            tags: ["home", "search"]
        )
        
        withAnimation { appState.listings.insert(newListing, at: 0) }
        
        resetForm()
        UserDefaults.standard.set("My Listings", forKey: "favoritesTabSelection")
        appState.selectedTab = 3
        appState.triggerToast(message: "Listing Published Successfully")
    }
    
    private func resetForm() {
        currentStep = 1
        title = ""
        price = ""
        itemDescription = ""
        condition = "Like New"
        selectedTopCategory = nil
        selectedSubCategory = nil
        selectedPhotoItems.removeAll()
        selectedImages.removeAll()
        isScanningImage = false
        showAIInsights = false
        isGeneratingDetails = false
        hasGeneratedDetails = false
        isInputFocused = false
    }
}

// MARK: - Subcomponents
struct PostCategoryCircle: View {
    var icon: String
    var label: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: Theme.Spacing.small) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                        .frame(width: isSelected ? 64 : 56, height: isSelected ? 64 : 56)
                        .shadow(color: isSelected ? Theme.Colors.primary.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    
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
