import SwiftUI
import MapKit
import PhotosUI
import Supabase

// MARK: - Payloads & Models
struct InsertListingPayload: Encodable {
    let id: UUID
    let sellerId: UUID
    let title: String
    let price: Int
    let description: String?
    let category: String?
    let subCategory: String?
    let condition: String?
    let neighborhood: String?
    let location: String
    let images: [String]?
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case sellerId = "seller_id"
        case title
        case price
        case description
        case category
        case subCategory = "sub_category"
        case condition
        case neighborhood
        case location
        case images
        case tags
    }
}

struct AIListingSuggestion: Codable {
    let title: String
    let price: String
    let description: String
    let category: String
    let subCategory: String
    let condition: String
    
    enum CodingKeys: String, CodingKey {
        case title, price, description, category, subCategory, condition
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Suggested Listing"
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? "For Sale"
        self.subCategory = try container.decodeIfPresent(String.self, forKey: .subCategory) ?? "Free"
        self.condition = try container.decodeIfPresent(String.self, forKey: .condition) ?? "Good"
        
        if let intPrice = try? container.decodeIfPresent(Int.self, forKey: .price) {
            self.price = String(intPrice)
        } else if let strPrice = try? container.decodeIfPresent(String.self, forKey: .price) {
            self.price = strPrice.replacingOccurrences(of: "$", with: "")
        } else {
            self.price = "0"
        }
    }
}

struct AIAnalyzeRequest: Encodable {
    let image: String
}

enum PostField: Hashable {
    case title, price, description
}

// MARK: - Post View
struct PostView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var title = ""
    @State private var price = ""
    @State private var itemDescription = ""
    @State private var condition = "Good"
    @State private var selectedTopCategory: String? = nil
    @State private var selectedSubCategory: String? = nil
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    @State private var isGeneratingDetails = false
    @State private var hasGeneratedDetails = false
    @State private var isPublishing = false
    
    @FocusState private var focusedField: PostField?
    @State private var showLocationSheet = false
    
    let conditions = ["New", "Like New", "Excellent", "Good", "Fair", "Salvage"]
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Create Post")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .toolbarBackground(Color(.systemBackground).opacity(0.95), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .safeAreaInset(edge: .bottom) { footerView }
                .sheet(isPresented: $showLocationSheet) {
                    LocationSelectionSheet()
                        .presentationDetents([.medium, .large])
                        .environmentObject(appState)
                }
                .overlay {
                    if isPublishing { publishingOverlay }
                }
        }
    }
    
    // MARK: - Main Layout Wrappers
    private var mainContent: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            CraigslistPattern()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    photosSection
                        .padding(.top, Theme.Spacing.large)
                    
                    detailsSection
                    
                    locationSection
                    
                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, Theme.Spacing.screenMargin)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") {
                resetForm()
                appState.selectedTab = appState.previousTab
            }
            .font(Theme.Typography.body(weight: .bold))
            .foregroundColor(Theme.Colors.primary)
        }
        
        ToolbarItem(placement: .keyboard) {
            HStack {
                Spacer()
                Button("Done") { focusedField = nil }
                    .font(Theme.Typography.body(weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
            }
        }
    }
    
    private var publishingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 24) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Publishing Listing...").font(Theme.Typography.headingS()).foregroundColor(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .colorScheme(.dark)
        }
    }
    
    // MARK: - Photo Section Subcomponents
    @ViewBuilder
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("Photos").font(Theme.Typography.headingL())
            
            if selectedImages.isEmpty {
                emptyPhotosPicker
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.small) {
                        addMorePhotosPicker
                        
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            photoThumbnail(at: index)
                        }
                    }
                }
                
                if !hasGeneratedDetails {
                    generateDetailsButton
                }
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in loadSelectedPhotos(from: newItems) }
    }
    
    private var emptyPhotosPicker: some View {
        PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
            VStack(spacing: Theme.Spacing.medium) {
                Image(systemName: "camera.fill").font(.system(size: 40))
                Text("Add Photos").font(Theme.Typography.body(weight: .bold))
            }
            .frame(maxWidth: .infinity).frame(height: 160)
            .background(Theme.Colors.surfaceCard).foregroundColor(Theme.Colors.primary).cornerRadius(Theme.Radius.medium)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6])))
        }
    }
    
    private var addMorePhotosPicker: some View {
        PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
            VStack(spacing: Theme.Spacing.small) {
                Image(systemName: "camera.fill").font(.system(size: 28))
                Text("Add More").font(Theme.Typography.helper(weight: .bold))
            }
            .frame(width: 110, height: 110).background(Theme.Colors.surfaceCard).foregroundColor(Theme.Colors.primary)
            .cornerRadius(Theme.Radius.medium).overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5])))
        }
    }
    
    private func photoThumbnail(at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: selectedImages[index])
                .resizable().scaledToFill()
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
            
            Button(action: { removeImage(at: index) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .padding(6)
        }
    }
    
    private var generateDetailsButton: some View {
        Button(action: generateDetailsWithOpenAI) {
            HStack(spacing: 8) {
                if isGeneratingDetails {
                    ProgressView().tint(.white)
                    Text("Analyzing Image...")
                } else {
                    Image(systemName: "sparkles")
                    Text("Auto-Generate Details")
                }
            }
            .font(Theme.Typography.body(weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient(colors: [Color.craigslistPurple, Color.blue], startPoint: .leading, endPoint: .trailing))
            .cornerRadius(Theme.Radius.small)
            .shadow(color: Color.craigslistPurple.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isGeneratingDetails)
        .padding(.top, 8)
    }
    
    // MARK: - Detail Section Subcomponents
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Details").font(Theme.Typography.headingL())
            titleInput
            priceInput
            categoryInput
            subCategoryInput
            conditionInput
            descriptionInput
        }
    }
    
    private var titleInput: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("TITLE").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
            TextField("e.g. Vintage Leather Sofa", text: $title)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .price }
                .mspInput(isFocused: focusedField == .title)
        }
    }
    
    private var priceInput: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("PRICE").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
            HStack {
                Text("$").font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                TextField("0", text: $price)
                    .focused($focusedField, equals: .price)
                    .keyboardType(.numberPad)
            }
            .mspInput(isFocused: focusedField == .price)
        }
    }
    
    private var categoryInput: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("CATEGORY").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
            Menu {
                ForEach(appState.topCategories, id: \.0) { cat in
                    Button(cat.0) {
                        selectedTopCategory = cat.0
                        selectedSubCategory = nil
                    }
                }
            } label: {
                HStack {
                    Text(selectedTopCategory ?? "Select a Category")
                        .font(Theme.Typography.body())
                        .foregroundColor(selectedTopCategory == nil ? Theme.Colors.textSecondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").foregroundColor(.gray)
                }
                .padding(.horizontal, Theme.Spacing.medium)
                .frame(minHeight: 56)
                .background(Theme.Colors.inputBackground)
                .cornerRadius(Theme.Radius.small)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            }
        }
    }
    
    @ViewBuilder
    private var subCategoryInput: some View {
        if let topCat = selectedTopCategory, let validSubs = appState.subCategories[topCat] {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("SUBCATEGORY").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                Menu {
                    ForEach(validSubs, id: \.self) { sub in
                        Button(sub) { selectedSubCategory = sub }
                    }
                } label: {
                    HStack {
                        Text(selectedSubCategory ?? "Select a Subcategory")
                            .font(Theme.Typography.body())
                            .foregroundColor(selectedSubCategory == nil ? Theme.Colors.textSecondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").foregroundColor(.gray)
                    }
                    .padding(.horizontal, Theme.Spacing.medium)
                    .frame(minHeight: 56)
                    .background(Theme.Colors.inputBackground)
                    .cornerRadius(Theme.Radius.small)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
            }
        }
    }
    
    private var conditionInput: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("CONDITION").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
            Menu {
                ForEach(conditions, id: \.self) { cond in
                    Button(cond) { condition = cond }
                }
            } label: {
                HStack {
                    Text(condition).font(Theme.Typography.body()).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").foregroundColor(.gray)
                }
                .padding(.horizontal, Theme.Spacing.medium)
                .frame(minHeight: 56)
                .background(Theme.Colors.inputBackground)
                .cornerRadius(Theme.Radius.small)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            }
        }
    }
    
    private var descriptionInput: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("DESCRIPTION").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
            TextEditor(text: $itemDescription)
                .focused($focusedField, equals: .description)
                .scrollContentBackground(.hidden)
                .font(Theme.Typography.body())
                .frame(height: 140)
                .padding(8)
                .background(Theme.Colors.inputBackground)
                .cornerRadius(Theme.Radius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .stroke(focusedField == .description ? Theme.Colors.actionPrimary : Color.primary.opacity(0.1), lineWidth: focusedField == .description ? 2 : 1)
                )
        }
    }
    
    // MARK: - Location & Footer Subcomponents
    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("Location").font(Theme.Typography.headingL())
            
            HStack {
                Image(systemName: "location.fill").foregroundColor(Theme.Colors.primary).font(.system(size: 18))
                Text(appState.selectedLocation).font(Theme.Typography.body(weight: .bold)).foregroundColor(.primary)
                Spacer()
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
    }
    
    @ViewBuilder
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)
            VStack {
                Button(action: publishListing) {
                    Text("Publish Listing")
                }
                .buttonStyle(MSPPrimaryButtonStyle(isEnabled: canProceed))
                .disabled(!canProceed)
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.top, Theme.Spacing.medium)
                .padding(.bottom, Theme.Spacing.medium)
            }
            .background(Color(.systemBackground).opacity(0.95).background(.ultraThinMaterial).ignoresSafeArea(edges: .bottom))
        }
    }
    
    private var canProceed: Bool {
        !selectedImages.isEmpty && !title.isEmpty && !price.isEmpty && selectedTopCategory != nil && !isPublishing
    }
    
    // MARK: - Actions
    private func removeImage(at index: Int) {
        withAnimation {
            _ = selectedImages.remove(at: index)
        }
    }
    
    private func loadSelectedPhotos(from items: [PhotosPickerItem]) {
        Task {
            var newImages: [UIImage] = []
            for item in items { if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { newImages.append(image) } }
            await MainActor.run { self.selectedImages.append(contentsOf: newImages) }
        }
    }
    
    private func generateDetailsWithOpenAI() {
        guard let image = selectedImages.first else { return }
        isGeneratingDetails = true
        
        let maxWidth: CGFloat = 800
        let scale = maxWidth / image.size.width
        let newHeight = image.size.height * scale
        
        UIGraphicsBeginImageContext(CGSize(width: maxWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y: 0, width: maxWidth, height: newHeight))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let finalImage = resizedImage ?? image
        guard let imageData = finalImage.jpegData(compressionQuality: 0.6) else {
            isGeneratingDetails = false
            return
        }
              
        let base64Image = imageData.base64EncodedString()
        let requestPayload = AIAnalyzeRequest(image: base64Image)
        
        Task {
            do {
                let suggestion: AIListingSuggestion = try await SupabaseManager.shared.client.functions.invoke(
                    "analyze-listing",
                    options: FunctionInvokeOptions(body: requestPayload)
                )
                
                await MainActor.run {
                    populateAIFields(with: suggestion)
                    isGeneratingDetails = false
                    hasGeneratedDetails = true
                }
            } catch {
                await MainActor.run {
                    appState.triggerToast(message: "AI Analysis failed. Please enter details manually.")
                    isGeneratingDetails = false
                }
            }
        }
    }
    
    private func populateAIFields(with data: AIListingSuggestion) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            title = data.title
            price = data.price
            itemDescription = data.description
            
            var matchedTop: String? = nil
            var matchedSub: String? = nil
            
            if appState.topCategories.contains(where: { $0.0 == data.category }) {
                matchedTop = data.category
            }
            
            for (top, subs) in appState.subCategories {
                if subs.contains(data.category) {
                    matchedTop = top
                    matchedSub = data.category
                }
                if subs.contains(data.subCategory) {
                    matchedTop = top
                    matchedSub = data.subCategory
                }
            }
            
            selectedTopCategory = matchedTop
            selectedSubCategory = matchedSub
            
            let validConditions = ["New", "Like New", "Excellent", "Good", "Fair", "Salvage"]
            if validConditions.contains(data.condition) {
                condition = data.condition
            } else {
                condition = "Good"
            }
        }
    }
    
    private func uploadImagesToSupabase() async throws -> [String] {
        var uploadedURLs: [String] = []
        let bucket = SupabaseManager.shared.client.storage.from("listing-images")
        
        for image in selectedImages {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            
            let fileName = "\(UUID().uuidString).jpg"
            let filePath = "\(appState.currentUserID?.uuidString ?? "unknown")/\(fileName)"
            
            try await bucket.upload(
                filePath,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )
            
            let publicURL = try bucket.getPublicURL(path: filePath)
            uploadedURLs.append(publicURL.absoluteString)
        }
        
        if uploadedURLs.isEmpty {
            uploadedURLs.append("https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?q=80&w=800")
        }
        return uploadedURLs
    }
    
    private func publishListing() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        isPublishing = true
        
        Task {
            do {
                let finalImageURLs = try await uploadImagesToSupabase()
                
                let newListing = LiveListing(
                    id: UUID(),
                    sellerId: appState.currentUserID ?? UUID(),
                    title: title.isEmpty ? "Untitled Listing" : title,
                    price: Int(price) ?? 0,
                    description: itemDescription.isEmpty ? nil : itemDescription,
                    category: selectedTopCategory ?? "For Sale",
                    subCategory: selectedSubCategory,
                    condition: condition,
                    neighborhood: appState.selectedLocation,
                    images: finalImageURLs,
                    tags: ["home", "search", selectedTopCategory ?? "", selectedSubCategory ?? ""].filter { !$0.isEmpty },
                    createdAt: Date()
                )
                
                let insertPayload = InsertListingPayload(
                    id: newListing.id,
                    sellerId: newListing.sellerId,
                    title: newListing.title,
                    price: newListing.price,
                    description: newListing.description,
                    category: newListing.category,
                    subCategory: newListing.subCategory,
                    condition: newListing.condition,
                    neighborhood: newListing.neighborhood,
                    // FIX: Explicitly assigning the SRID to ensure perfect PostGIS mapping
                    location: "SRID=4326;POINT(\(appState.savedLongitude) \(appState.savedLatitude))",
                    images: newListing.images,
                    tags: newListing.tags
                )
                
                try await SupabaseManager.shared.client
                    .from("listings")
                    .insert(insertPayload)
                    .execute()
                
                await MainActor.run {
                    withAnimation { appState.listings.insert(newListing, at: 0) }
                    resetForm()
                    UserDefaults.standard.set("My Listings", forKey: "favoritesTabSelection")
                    appState.selectedTab = 3
                    appState.triggerToast(message: "Listing Published Successfully")
                }
            } catch {
                await MainActor.run {
                    appState.triggerToast(message: "Failed to publish listing. Please try again.")
                    isPublishing = false
                }
            }
        }
    }
    
    private func resetForm() {
        title = ""
        price = ""
        itemDescription = ""
        condition = "Good"
        selectedTopCategory = nil
        selectedSubCategory = nil
        selectedPhotoItems.removeAll()
        selectedImages.removeAll()
        isGeneratingDetails = false
        hasGeneratedDetails = false
        focusedField = nil
        isPublishing = false
    }
}
