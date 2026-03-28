import SwiftUI
import MapKit
import Supabase

// A dedicated Encodable struct to securely send only the edited fields to Supabase
struct UpdateListingPayload: Encodable {
    let title: String
    let price: Int
    let description: String?
    let condition: String?
}

struct EditListingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var listing: LiveListing
    
    @State private var title: String = ""
    @State private var price: String = ""
    @State private var itemDescription: String = ""
    @State private var condition: String = ""
    
    @State private var isSaving = false
    @FocusState private var isInputFocused: Bool
    
    let conditions = ["New", "Like New", "Excellent", "Good", "Fair", "Salvage"]
    
    init(listing: LiveListing) {
        self.listing = listing
        _title = State(initialValue: listing.title)
        _price = State(initialValue: String(listing.price))
        _itemDescription = State(initialValue: listing.description ?? "")
        _condition = State(initialValue: listing.condition ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                        
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
                            Text("DESCRIPTION").font(Theme.Typography.helper(weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                            
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
                    .padding(Theme.Spacing.screenMargin)
                    .padding(.bottom, 100)
                }
                
                // Sticky Save Button
                VStack(spacing: 0) {
                    Divider().opacity(0.3)
                    VStack {
                        Button(action: saveUpdates) {
                            if isSaving {
                                HStack(spacing: 8) {
                                    ProgressView().tint(.white)
                                    Text("Saving...")
                                }
                            } else {
                                Text("Save Changes")
                            }
                        }
                        .buttonStyle(MSPPrimaryButtonStyle(isEnabled: isValid && !isSaving))
                        .disabled(!isValid || isSaving)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Post")
                        .font(Theme.Typography.headingM())
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.Typography.body(weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .toolbarBackground(Color(.systemBackground).opacity(0.95), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onTapGesture {
                isInputFocused = false
            }
        }
    }
    
    private var isValid: Bool {
        !title.isEmpty && !price.isEmpty
    }
    
    private func saveUpdates() {
        isSaving = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        Task {
            do {
                let payload = UpdateListingPayload(
                    title: title,
                    price: Int(price) ?? 0,
                    description: itemDescription.isEmpty ? nil : itemDescription,
                    condition: condition.isEmpty ? nil : condition
                )
                
                // Push edits to the live database
                try await SupabaseManager.shared.client
                    .from("listings")
                    .update(payload)
                    .eq("id", value: listing.id)
                    .execute()
                
                await MainActor.run {
                    // Update global UI state
                    if let index = appState.listings.firstIndex(where: { $0.id == listing.id }) {
                        let oldListing = appState.listings[index]
                        let updatedListing = LiveListing(
                            id: oldListing.id,
                            sellerId: oldListing.sellerId,
                            title: title,
                            price: Int(price) ?? 0,
                            description: itemDescription.isEmpty ? nil : itemDescription,
                            category: oldListing.category,
                            subCategory: oldListing.subCategory,
                            condition: condition.isEmpty ? nil : condition,
                            neighborhood: oldListing.neighborhood,
                            images: oldListing.images,
                            tags: oldListing.tags,
                            createdAt: oldListing.createdAt
                        )
                        appState.listings[index] = updatedListing
                    }
                    appState.triggerToast(message: "Changes Saved")
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("Supabase Edit Error: \(error.localizedDescription)")
                    appState.triggerToast(message: "Failed to save changes.")
                    isSaving = false
                }
            }
        }
    }
}
