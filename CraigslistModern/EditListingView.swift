import SwiftUI
import MapKit

struct EditListingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var listing: Listing
    
    @State private var title: String = ""
    @State private var price: String = ""
    @State private var itemDescription: String = ""
    @State private var condition: String = ""
    
    @FocusState private var isInputFocused: Bool
    
    let conditions = ["New", "Like New", "Excellent", "Good", "Fair", "Salvage"]
    
    init(listing: Listing) {
        self.listing = listing
        // Initialize state variables with the existing listing data
        _title = State(initialValue: listing.title)
        _price = State(initialValue: String(listing.price))
        _itemDescription = State(initialValue: listing.description)
        _condition = State(initialValue: listing.condition)
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
                    .padding(.bottom, 100) // Padding for sticky bottom button
                }
                
                // Sticky Save Button
                VStack(spacing: 0) {
                    Divider().opacity(0.3)
                    VStack {
                        Button(action: saveUpdates) {
                            Text("Save Changes")
                        }
                        .buttonStyle(MSPPrimaryButtonStyle(isEnabled: isValid))
                        .disabled(!isValid)
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
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Find the listing in the global state and replace it entirely to bypass 'let' constant restrictions
        if let index = appState.listings.firstIndex(where: { $0.id == listing.id }) {
            let oldListing = appState.listings[index]
            
            let updatedListing = Listing(
                id: oldListing.id,
                title: title,
                price: Int(price) ?? 0,
                coordinate: oldListing.coordinate,
                neighborhood: oldListing.neighborhood,
                distance: oldListing.distance,
                description: itemDescription,
                category: oldListing.category,
                datePosted: oldListing.datePosted,
                condition: condition,
                images: oldListing.images,
                sellerName: oldListing.sellerName,
                sellerType: oldListing.sellerType,
                sellerAvatar: oldListing.sellerAvatar,
                sellerRating: oldListing.sellerRating,
                reviewCount: oldListing.reviewCount,
                tags: oldListing.tags
            )
            
            appState.listings[index] = updatedListing
            appState.triggerToast(message: "Changes Saved")
            dismiss()
        }
    }
}
