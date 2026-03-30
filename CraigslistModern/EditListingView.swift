import SwiftUI
import MapKit
import Supabase

// A dedicated Encodable struct to securely send only the edited fields to Supabase
struct UpdateListingPayload: Encodable {
    let title: String
    let price: Int
    let description: String?
    let category: String?
    let subCategory: String?
    let condition: String?
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case title
        case price
        case description
        case category
        case subCategory = "sub_category"
        case condition
        case tags
    }
}

enum EditField: Hashable {
    case title, price, description
}

struct EditListingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var listing: LiveListing
    
    @State private var title: String = ""
    @State private var price: String = ""
    @State private var itemDescription: String = ""
    @State private var condition: String = "Good"
    @State private var selectedTopCategory: String? = nil
    @State private var selectedSubCategory: String? = nil
    
    @State private var isSaving = false
    @FocusState private var focusedField: EditField?
    
    let conditions = ["New", "Like New", "Excellent", "Good", "Fair", "Salvage"]
    
    init(listing: LiveListing) {
        self.listing = listing
        _title = State(initialValue: listing.title)
        _price = State(initialValue: String(listing.price))
        _itemDescription = State(initialValue: listing.description ?? "")
        _condition = State(initialValue: listing.condition ?? "Good")
        _selectedTopCategory = State(initialValue: listing.category)
        _selectedSubCategory = State(initialValue: listing.subCategory)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                        detailsSection
                            .padding(.top, Theme.Spacing.large)
                        
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                }
                .scrollDismissesKeyboard(.interactively)
                
                footerView
            }
            .navigationTitle("Edit Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 24) {
                            ProgressView().scaleEffect(1.5).tint(.white)
                            Text("Saving Changes...").font(Theme.Typography.headingS()).foregroundColor(.white)
                        }
                        .padding(40).background(.ultraThinMaterial).cornerRadius(24).colorScheme(.dark)
                    }
                }
            }
        }
    }
    
    // MARK: - Subcomponents
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
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
            }.mspInput(isFocused: focusedField == .price)
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
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)
            VStack {
                Button(action: saveChanges) {
                    Text("Save Changes")
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
        !title.isEmpty && !price.isEmpty && selectedTopCategory != nil && !isSaving
    }
    
    private func saveChanges() {
        guard canProceed else { return }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        isSaving = true
        
        Task {
            do {
                // Ensure tags array updates to reflect the new category mappings for proper searching
                let updatedTags = ["home", "search", selectedTopCategory ?? "", selectedSubCategory ?? ""].filter { !$0.isEmpty }
                
                let payload = UpdateListingPayload(
                    title: title,
                    price: Int(price) ?? 0,
                    description: itemDescription.isEmpty ? nil : itemDescription,
                    category: selectedTopCategory,
                    subCategory: selectedSubCategory,
                    condition: condition,
                    tags: updatedTags
                )
                
                try await SupabaseManager.shared.client
                    .from("listings")
                    .update(payload)
                    .eq("id", value: listing.id)
                    .execute()
                
                await MainActor.run {
                    // Update local arrays instantly so UI doesn't require a fetch
                    if let index = appState.listings.firstIndex(where: { $0.id == listing.id }) {
                        let oldListing = appState.listings[index]
                        let updatedListing = LiveListing(
                            id: oldListing.id,
                            sellerId: oldListing.sellerId,
                            title: title,
                            price: Int(price) ?? 0,
                            description: itemDescription.isEmpty ? nil : itemDescription,
                            category: selectedTopCategory,
                            subCategory: selectedSubCategory,
                            condition: condition,
                            neighborhood: oldListing.neighborhood,
                            images: oldListing.images,
                            tags: updatedTags,
                            createdAt: oldListing.createdAt
                        )
                        appState.listings[index] = updatedListing
                    }
                    
                    if let searchIndex = appState.searchResults.firstIndex(where: { $0.id == listing.id }) {
                        let oldListing = appState.searchResults[searchIndex]
                        let updatedListing = LiveListing(
                            id: oldListing.id,
                            sellerId: oldListing.sellerId,
                            title: title,
                            price: Int(price) ?? 0,
                            description: itemDescription.isEmpty ? nil : itemDescription,
                            category: selectedTopCategory,
                            subCategory: selectedSubCategory,
                            condition: condition,
                            neighborhood: oldListing.neighborhood,
                            images: oldListing.images,
                            tags: updatedTags,
                            createdAt: oldListing.createdAt
                        )
                        appState.searchResults[searchIndex] = updatedListing
                    }
                    
                    appState.triggerToast(message: "Changes Saved")
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("Supabase Edit Error: \(error.localizedDescription)")
                    appState.triggerToast(message: "Failed to save changes. Please try again.")
                    isSaving = false
                }
            }
        }
    }
}
