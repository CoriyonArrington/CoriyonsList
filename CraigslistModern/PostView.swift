import SwiftUI
import MapKit
import PhotosUI
import Supabase

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

// 1. PRODUCTION FIX: Custom Decoder safely handles OpenAI returning either Ints or Strings for price
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
        self.subCategory = try container.decodeIfPresent(String.self, forKey: .subCategory) ?? "Other"
        self.condition = try container.decodeIfPresent(String.self, forKey: .condition) ?? "Good"
        
        // Safely parse price whether it's 100 or "100"
        if let intPrice = try? container.decodeIfPresent(Int.self, forKey: .price) {
            self.price = String(intPrice)
        } else if let strPrice = try? container.decodeIfPresent(String.self, forKey: .price) {
            self.price = strPrice.replacingOccurrences(of: "$", with: "")
        } else {
            self.price = "0"
        }
    }
}

// Payload for the Edge Function
struct AIAnalyzeRequest: Encodable {
    let image: String
}

enum PostField: Hashable {
    case title, price, description
}

struct PostView: View {
    @EnvironmentObject var appState: AppState
    
    // MARK: - Form State
    @State private var currentStep = 1
    @State private var title = ""
    @State private var price = ""
    @State private var itemDescription = ""
    @State private var condition = "Good"
    @State private var selectedTopCategory: String? = nil
    @State private var selectedSubCategory: String? = nil
    
    // PhotosUI & AI State
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    @State private var isScanningImage = false
    @State private var showAIInsights = false
    @State private var isGeneratingDetails = false
    @State private var hasGeneratedDetails = false
    
    @State private var isPublishing = false
    
    // Overlays & Focus
    @FocusState private var focusedField: PostField?
    @State private var showLocationSheet = false
    @State private var showPreviewDetail = false
    
    let conditions = ["New", "Like New", "Excellent", "Good", "Fair", "Salvage"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                CraigslistPattern()
                
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
                ToolbarItem(placement: .principal) {
                    Text("Create Post").font(Theme.Typography.body(weight: .bold)).foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Step \(currentStep) of 3")
                            .font(Theme.Typography.caption(weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.Colors.surfaceGray).frame(height: 4)
                                Capsule()
                                    .fill(Theme.Colors.primary)
                                    .frame(width: geo.size.width * (CGFloat(currentStep) / 3.0), height: 4)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                            }
                        }
                        .frame(width: 70, height: 4)
                    }
                    .padding(.trailing, 8)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    if currentStep == 1 {
                        Button("Cancel") {
                            resetForm()
                            appState.selectedTab = appState.previousTab
                        }.font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.primary)
                    } else {
                        Button(action: { goBackStep() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }.font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.primary)
                        }
                    }
                }
            }
            .toolbarBackground(Color(.systemBackground).opacity(0.95), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { footerView }
        }
        // 2. PRODUCTION FIX: Presentation Modifiers attached to NavigationStack safely
        .sheet(isPresented: $showLocationSheet) {
            LocationSelectionSheet()
                .presentationDetents([.medium, .large])
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showPreviewDetail) {
            let previewListing = LiveListing(
                id: UUID(),
                sellerId: appState.currentUserID ?? UUID(),
                title: title.isEmpty ? "Untitled Listing" : title,
                price: Int(price) ?? 0,
                description: itemDescription.isEmpty ? "No description provided." : itemDescription,
                category: selectedSubCategory ?? selectedTopCategory ?? "For Sale",
                subCategory: selectedSubCategory,
                condition: condition,
                neighborhood: appState.selectedLocation,
                images: generateTempPreviewURLs(),
                tags: ["preview"],
                createdAt: Date()
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
            .environmentObject(appState)
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)
            VStack {
                Button(action: {
                    if currentStep < 3 { advanceStep() }
                    else { publishListing() }
                }) {
                    if isPublishing {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Publishing...")
                        }
                    } else {
                        Text(currentStep < 3 ? "Next" : "Post")
                    }
                }
                .buttonStyle(MSPPrimaryButtonStyle(isEnabled: canProceed && !isPublishing))
                .disabled(!canProceed || isPublishing)
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.top, Theme.Spacing.medium)
                .padding(.bottom, Theme.Spacing.medium)
            }
            .background(Color(.systemBackground).opacity(0.95).background(.ultraThinMaterial).ignoresSafeArea(edges: .bottom))
        }
    }
    
    private var stepOneBasics: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                Text("What are you selling?").font(Theme.Typography.headingL()).padding(.top, Theme.Spacing.large)
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    if selectedImages.isEmpty {
                        PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                            VStack(spacing: Theme.Spacing.medium) {
                                Image(systemName: "camera.fill").font(.system(size: 40))
                                Text("Add Photos").font(Theme.Typography.body(weight: .bold))
                            }
                            .frame(maxWidth: .infinity).frame(height: 160)
                            .background(Theme.Colors.surfaceCard).foregroundColor(Theme.Colors.primary).cornerRadius(Theme.Radius.medium)
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6])))
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.small) {
                                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                                    VStack(spacing: Theme.Spacing.small) {
                                        Image(systemName: "camera.fill").font(.system(size: 28))
                                        Text("Add More").font(Theme.Typography.helper(weight: .bold))
                                    }
                                    .frame(width: 110, height: 110).background(Theme.Colors.surfaceCard).foregroundColor(Theme.Colors.primary)
                                    .cornerRadius(Theme.Radius.medium).overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5])))
                                }
                                ForEach(selectedImages, id: \.self) { image in
                                    Image(uiImage: image).resizable().scaledToFill().frame(width: 110, height: 110).clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
                                }
                            }
                        }
                    }
                    
                    if isScanningImage {
                        HStack(spacing: Theme.Spacing.small) {
                            ProgressView().tint(Theme.Colors.primary)
                            Text("Analyzing image with AI...").font(Theme.Typography.caption(weight: .semibold)).foregroundColor(Theme.Colors.textSecondary)
                        }.padding(.top, Theme.Spacing.small).transition(.opacity)
                    } else if showAIInsights {
                        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                            HStack { Image(systemName: "sparkles"); Text("AI Insights Applied").font(Theme.Typography.caption(weight: .bold)) }.foregroundColor(Theme.Colors.primary)
                            Text("We've auto-populated the fields below based on your image. Feel free to adjust them!").font(Theme.Typography.caption()).foregroundColor(.primary)
                        }
                        .padding(Theme.Spacing.large).background(Theme.Colors.surfaceCard).cornerRadius(Theme.Radius.medium)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1))
                        .padding(.top, Theme.Spacing.small).transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .onChange(of: selectedPhotoItems) { _, newItems in loadSelectedPhotos(from: newItems) }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("TITLE").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    TextField("e.g. Vintage Leather Sofa", text: $title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .price }
                        .mspInput(isFocused: focusedField == .title)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("PRICE").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    HStack {
                        Text("$").font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                        TextField("0", text: $price)
                            .focused($focusedField, equals: .price)
                            .keyboardType(.numberPad)
                    }.mspInput(isFocused: focusedField == .price)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin).padding(.bottom, Theme.Spacing.section)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private var stepTwoDetails: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                Text("Add some details").font(Theme.Typography.headingL()).padding(.top, Theme.Spacing.large)
                
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
                                    Text(cond).font(Theme.Typography.caption(weight: condition == cond ? .bold : .semibold)).frame(minHeight: 44).padding(.horizontal, Theme.Spacing.medium)
                                        .background(condition == cond ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                                        .foregroundColor(condition == cond ? Color(.systemBackground) : .primary)
                                        .clipShape(Capsule()).overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    HStack {
                        Text("DESCRIPTION").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        if showAIInsights {
                            HStack(spacing: 4) { Image(systemName: "sparkles"); Text("AI Generated").font(Theme.Typography.helper(weight: .bold)) }.foregroundColor(Theme.Colors.primary)
                        }
                    }
                    TextEditor(text: $itemDescription)
                        .focused($focusedField, equals: .description)
                        .scrollContentBackground(.hidden).font(Theme.Typography.body())
                        .frame(height: 140).padding(8).background(Theme.Colors.inputBackground).cornerRadius(Theme.Radius.small)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(focusedField == .description ? Theme.Colors.actionPrimary : Color.primary.opacity(0.1), lineWidth: focusedField == .description ? 2 : 1))
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin).padding(.bottom, Theme.Spacing.section)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private var stepThreeReview: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                Text("Review & Post").font(Theme.Typography.headingL()).padding(.top, Theme.Spacing.large)
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("MEETUP LOCATION").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
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
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("LISTING PREVIEW").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    
                    Button(action: { showPreviewDetail = true }) {
                        VStack(alignment: .leading, spacing: 0) {
                            if let firstImg = selectedImages.first {
                                Image(uiImage: firstImg)
                                    .resizable().scaledToFill().frame(height: 200).clipped()
                            } else {
                                Color(.systemGray4).frame(height: 200)
                                    .overlay(Image(systemName: "photo").font(.system(size: 40)).foregroundColor(.gray))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    Text(title.isEmpty ? "Untitled Listing" : title)
                                        .font(.custom("Montserrat", size: 21).weight(.bold)).foregroundColor(.primary).lineLimit(1)
                                    Spacer()
                                    Text("$\(price.isEmpty ? "0" : price)")
                                        .font(.custom("Montserrat", size: 21).weight(.heavy)).foregroundColor(Theme.Colors.success)
                                }
                                
                                HStack(alignment: .center, spacing: 6) {
                                    Text(selectedSubCategory ?? selectedTopCategory ?? "For Sale").font(.custom("NunitoSans", size: 14).weight(.bold)).foregroundColor(.secondary).lineLimit(1)
                                    Text("•").foregroundColor(.gray)
                                    Text(condition).font(.custom("NunitoSans", size: 14).weight(.bold)).foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                        }
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }.padding(.horizontal, Theme.Spacing.screenMargin)
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private var canProceed: Bool { currentStep == 1 ? (!title.isEmpty && !price.isEmpty) : true }
    
    private func advanceStep() {
        withAnimation { currentStep += 1 }
    }
    
    private func goBackStep() { withAnimation { currentStep -= 1 } }
    
    private func loadSelectedPhotos(from items: [PhotosPickerItem]) {
        Task {
            var newImages: [UIImage] = []
            for item in items { if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { newImages.append(image) } }
            DispatchQueue.main.async {
                self.selectedImages = newImages
                
                if !self.selectedImages.isEmpty && !self.showAIInsights {
                    self.analyzeImageWithAI(image: self.selectedImages.first!)
                }
            }
        }
    }
    
    // 3. PRODUCTION FIX: Using the Native Supabase SDK with our safe generic decoder
    private func analyzeImageWithAI(image: UIImage) {
        let maxWidth: CGFloat = 800
        let scale = maxWidth / image.size.width
        let newHeight = image.size.height * scale
        
        UIGraphicsBeginImageContext(CGSize(width: maxWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y: 0, width: maxWidth, height: newHeight))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let finalImage = resizedImage ?? image
        guard let imageData = finalImage.jpegData(compressionQuality: 0.6) else { return }
              
        let base64Image = imageData.base64EncodedString()
        
        isScanningImage = true
        
        Task {
            defer {
                Task { @MainActor in
                    self.isScanningImage = false
                }
            }
            
            do {
                let requestPayload = AIAnalyzeRequest(image: base64Image)
                
                let suggestion: AIListingSuggestion = try await SupabaseManager.shared.client.functions.invoke(
                    "analyze-listing",
                    options: FunctionInvokeOptions(body: requestPayload)
                )
                
                await MainActor.run {
                    withAnimation {
                        self.title = suggestion.title
                        self.price = suggestion.price
                        self.itemDescription = suggestion.description
                        self.selectedTopCategory = suggestion.category
                        self.selectedSubCategory = suggestion.subCategory
                        self.condition = suggestion.condition
                        self.showAIInsights = true
                    }
                }
                
            } catch {
                print("Supabase Edge Function Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func generateTempPreviewURLs() -> [String] {
        var urls: [String] = []
        for image in selectedImages {
            if let data = image.jpegData(compressionQuality: 0.8) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                try? data.write(to: url); urls.append(url.absoluteString)
            }
        }
        if urls.isEmpty { urls.append("https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?q=80&w=800") }
        return urls
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
                    category: selectedSubCategory ?? selectedTopCategory ?? "For Sale",
                    subCategory: selectedSubCategory,
                    condition: condition,
                    neighborhood: appState.selectedLocation,
                    images: finalImageURLs,
                    tags: ["home", "search"],
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
                    location: "POINT(-93.2650 44.9778)",
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
                print("Publish Error: \(error)")
                await MainActor.run {
                    appState.triggerToast(message: "Failed to publish listing. Please try again.")
                    isPublishing = false
                }
            }
        }
    }
    
    private func resetForm() {
        currentStep = 1
        title = ""
        price = ""
        itemDescription = ""
        condition = "Good"
        selectedTopCategory = nil
        selectedSubCategory = nil
        selectedPhotoItems.removeAll()
        selectedImages.removeAll()
        isScanningImage = false
        showAIInsights = false
        isGeneratingDetails = false
        hasGeneratedDetails = false
        focusedField = nil
        isPublishing = false
    }
}
