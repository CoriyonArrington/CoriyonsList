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

struct PostView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var currentStep = 1
    @State private var title = ""
    @State private var price = ""
    @State private var itemDescription = ""
    @State private var condition = "Like New"
    @State private var selectedTopCategory: String? = nil
    @State private var selectedSubCategory: String? = nil
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    @State private var isScanningImage = false
    @State private var showAIInsights = false
    @State private var isGeneratingDetails = false
    @State private var hasGeneratedDetails = false
    
    @State private var isPublishing = false
    
    @FocusState private var isInputFocused: Bool
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Step \(currentStep) of 3").font(Theme.Typography.caption(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.Colors.surfaceGray).frame(height: 4)
                                Capsule()
                                    .fill(Theme.Colors.primary)
                                    .frame(width: geo.size.width * (CGFloat(currentStep) / 3.0), height: 4)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                            }
                        }.frame(width: 70, height: 4)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep == 1 {
                        Button("Cancel") { resetForm() }.font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.primary)
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
            .onTapGesture { isInputFocused = false }
            .sheet(isPresented: $showLocationSheet) { LocationSelectionSheet().presentationDetents([.medium, .large]) }
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
            }
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
                            Text("Analyzing image...").font(Theme.Typography.caption(weight: .semibold)).foregroundColor(Theme.Colors.textSecondary)
                        }.padding(.top, Theme.Spacing.small).transition(.opacity)
                    } else if showAIInsights {
                        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                            HStack { Image(systemName: "sparkles"); Text("AI Insights").font(Theme.Typography.caption(weight: .bold)) }.foregroundColor(Theme.Colors.primary)
                            Text("Looks like a **Standing Desk**!").font(Theme.Typography.caption()).foregroundColor(.primary)
                        }
                        .padding(Theme.Spacing.large).background(Theme.Colors.surfaceCard).cornerRadius(Theme.Radius.medium)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1))
                        .padding(.top, Theme.Spacing.small).transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                // Updated iOS 17 Modifier
                .onChange(of: selectedPhotoItems) { _, newItems in loadSelectedPhotos(from: newItems) }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("TITLE").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    TextField("e.g. Vintage Leather Sofa", text: $title).focused($isInputFocused).mspInput(isFocused: isInputFocused)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("PRICE").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    HStack {
                        Text("$").font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                        TextField("0", text: $price).focused($isInputFocused).keyboardType(.numberPad)
                    }.mspInput(isFocused: isInputFocused)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin).padding(.bottom, Theme.Spacing.section)
        }
    }
    
    private var stepTwoDetails: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                Text("Add some details").font(Theme.Typography.headingL()).padding(.top, Theme.Spacing.large)
                if isGeneratingDetails {
                    VStack(spacing: Theme.Spacing.medium) {
                        ProgressView().scaleEffect(1.5).tint(Theme.Colors.primary)
                        Text("Drafting description...").font(Theme.Typography.body(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    }.frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("DESCRIPTION").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                        TextEditor(text: $itemDescription)
                            .focused($isInputFocused).scrollContentBackground(.hidden).font(Theme.Typography.body())
                            .frame(height: 140).padding(8).background(Theme.Colors.inputBackground).cornerRadius(Theme.Radius.small)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin).padding(.bottom, Theme.Spacing.section)
        }
    }
    
    private var stepThreeReview: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                Text("Review & Post").font(Theme.Typography.headingL()).padding(.top, Theme.Spacing.large)
                
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("LISTING PREVIEW").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                    
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
            }.padding(.horizontal, Theme.Spacing.screenMargin)
        }
    }
    
    private var canProceed: Bool { currentStep == 1 ? (!title.isEmpty && !price.isEmpty) : true }
    
    private func advanceStep() {
        if currentStep == 1 {
            withAnimation { currentStep += 1 }
            if !hasGeneratedDetails {
                isGeneratingDetails = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { isGeneratingDetails = false; hasGeneratedDetails = true }
                }
            }
        } else if currentStep == 2 {
            withAnimation { currentStep += 1 }
        }
    }
    
    private func goBackStep() { withAnimation { currentStep -= 1 } }
    
    private func loadSelectedPhotos(from items: [PhotosPickerItem]) {
        Task {
            var newImages: [UIImage] = []
            for item in items { if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { newImages.append(image) } }
            DispatchQueue.main.async { self.selectedImages = newImages }
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
            
            // Updated SDK parameter mapping `file:` to `data:`
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
        isPublishing = false
    }
}
