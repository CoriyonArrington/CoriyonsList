import SwiftUI

// MARK: - Pager Wrapper
struct ListingPagerView: View {
    @EnvironmentObject var appState: AppState // Added to access Toast state
    @Binding var listings: [Listing]
    var filteredIDs: [UUID]
    @Binding var selectedListingID: UUID?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedListingID) {
                ForEach(filteredIDs, id: \.self) { id in
                    if let index = listings.firstIndex(where: { $0.id == id }) {
                        ListingDetailView(
                            listing: listings[index],
                            allIDs: filteredIDs,
                            selectedListingID: $selectedListingID,
                            onDismiss: { dismiss() },
                            onDelete: {
                                listings.remove(at: index)
                                if listings.isEmpty { dismiss() }
                            }
                        )
                        .tag(id as UUID?)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color(.systemBackground))
            
            // Local Toast Overlay inside the Sheet
            if appState.showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text(appState.toastMessage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                .padding(.bottom, 120) // Hovers safely above the message bar
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
    }
}

// MARK: - Main Detail View
struct ListingDetailView: View {
    @EnvironmentObject var appState: AppState
    
    let listing: Listing
    let allIDs: [UUID]
    @Binding var selectedListingID: UUID?
    
    var onDismiss: () -> Void
    var onDelete: () -> Void
    
    private var currentIndex: Int? { allIDs.firstIndex(of: listing.id) }
    private var displayIndex: Int { (currentIndex ?? 0) + 1 }
    private var hasPrev: Bool { (currentIndex ?? 0) > 0 }
    private var hasNext: Bool { (currentIndex ?? 0) < allIDs.count - 1 }
    
    private func goPrev() {
        if let index = currentIndex, hasPrev {
            withAnimation { selectedListingID = allIDs[index - 1] }
        }
    }
    private func goNext() {
        if let index = currentIndex, hasNext {
            withAnimation { selectedListingID = allIDs[index + 1] }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    ZStack(alignment: .top) {
                        TabView {
                            ForEach(listing.images, id: \.self) { imageUrlStr in
                                if let url = URL(string: imageUrlStr) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color(.systemGray5)
                                        }
                                    }
                                    .frame(width: UIScreen.main.bounds.width, height: 400)
                                    .clipped()
                                }
                            }
                        }
                        .frame(height: 400)
                        .tabViewStyle(.page)
                        
                        HStack(alignment: .top) {
                            CircularActionButton(icon: "xmark", action: onDismiss)
                            Spacer()
                            HStack(spacing: 12) {
                                CircularActionButton(icon: "hand.thumbsup", action: {})
                                CircularActionButton(
                                    icon: appState.isFavorited(listing.id) ? "heart.fill" : "heart",
                                    iconColor: appState.isFavorited(listing.id) ? .red : .primary,
                                    action: { appState.toggleFavorite(listing.id) }
                                )
                                CircularActionButton(icon: "square.and.arrow.up", action: {})
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(listing.title).font(.system(size: 28, weight: .bold)).foregroundColor(.primary).frame(maxWidth: .infinity, alignment: .leading)
                        HStack(alignment: .firstTextBaseline) {
                            Text("$\(listing.price)").font(.system(size: 24, weight: .heavy)).foregroundColor(.primary)
                            Text("• \(listing.neighborhood)").font(.body).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 24)
                    
                    HStack(alignment: .top) {
                        AttributeIconView(icon: "clock", title: timeAgo(from: listing.datePosted))
                        AttributeIconView(icon: "sparkles", title: listing.condition)
                        AttributeIconView(icon: "tag", title: listing.category)
                        AttributeIconView(icon: "location", title: "\(String(format: "%.1f", listing.distance)) mi")
                    }
                    .padding(.horizontal, 10).padding(.vertical, 24)
                    
                    Divider().padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(listing.description).font(.body).foregroundColor(.secondary).lineSpacing(6)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 24)
                    
                    Divider().padding(.horizontal, 20)
                    
                    HStack(alignment: .top, spacing: 16) {
                        
                        // Updated to load Avatar Image URL
                        if let url = URL(string: listing.sellerAvatar) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Color(.systemGray5)
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Color(.systemGray5).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center, spacing: 8) {
                                Text(listing.sellerName).font(.headline).foregroundColor(.primary)
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.shield.fill")
                                    Text("Verified by ID.me")
                                }
                                .font(.system(size: 10, weight: .bold)).foregroundColor(.green).padding(.horizontal, 6).padding(.vertical, 4).background(Color.green.opacity(0.15)).cornerRadius(6)
                            }
                            HStack(spacing: 4) {
                                HStack(spacing: 2) { ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.yellow) } }
                                Text("5.0").font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                                Text("(14 reviews)").font(.system(size: 13)).foregroundColor(.secondary)
                            }
                            Text(listing.sellerType).font(.subheadline).foregroundColor(.secondary).padding(.top, 2)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 24)
                    
                    VStack(spacing: 12) {
                        GhostActionButton(icon: "hand.thumbsup", title: "Vote / Thumbs Up", action: {})
                        GhostActionButton(
                            icon: appState.isFavorited(listing.id) ? "heart.fill" : "heart",
                            title: appState.isFavorited(listing.id) ? "Saved to Favorites" : "Save Listing",
                            action: { appState.toggleFavorite(listing.id) },
                            iconColor: appState.isFavorited(listing.id) ? .red : .primary
                        )
                        GhostActionButton(icon: "square.and.arrow.up", title: "Share Listing", action: {})
                        GhostActionButton(icon: "flag", title: "Remove Listing", action: onDelete, isDestructive: true)
                    }
                    .padding(.horizontal, 20)
                    
                    HStack {
                        Button(action: goPrev) { Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).frame(width: 56, height: 56).contentShape(Rectangle()) }
                        .disabled(!hasPrev).foregroundColor(hasPrev ? .primary : Color(.systemGray3))
                        Spacer()
                        Text("\(displayIndex) of \(allIDs.count) listings").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                        Spacer()
                        Button(action: goNext) { Image(systemName: "chevron.right").font(.system(size: 20, weight: .semibold)).frame(width: 56, height: 56).contentShape(Rectangle()) }
                        .disabled(!hasNext).foregroundColor(hasNext ? .primary : Color(.systemGray3))
                    }
                    .frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            VStack(spacing: 12) {
                Button(action: {}) {
                    Text("Message Seller").font(.headline).fontWeight(.bold).foregroundColor(Color(.systemBackground)).frame(maxWidth: .infinity).frame(height: 56).background(Color.primary).cornerRadius(16)
                }
                HStack(spacing: 6) {
                    ForEach(0..<allIDs.count, id: \.self) { index in
                        Circle().fill(index == (currentIndex ?? 0) ? Color.primary : Color(.systemGray4)).frame(width: index == (currentIndex ?? 0) ? 8 : 6, height: index == (currentIndex ?? 0) ? 8 : 6).animation(.spring(), value: currentIndex)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 32).background(Color(.systemBackground).shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5))
        }
        .background(Color(.systemBackground))
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Reusable UI Components
struct CircularActionButton: View {
    let icon: String; var iconColor: Color = .primary; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(iconColor).frame(width: 44, height: 44).background(Color(.systemBackground)).clipShape(Circle()).shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

struct GhostActionButton: View {
    let icon: String; let title: String; let action: () -> Void; var isDestructive: Bool = false; var iconColor: Color? = nil
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(iconColor ?? (isDestructive ? .red : .primary))
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold)).foregroundColor(isDestructive ? .red : .primary).frame(maxWidth: .infinity).frame(height: 56)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isDestructive ? Color.red.opacity(0.3) : Color(.systemGray4), lineWidth: 1.5))
        }
    }
}

struct AttributeIconView: View {
    let icon: String; let title: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 24, weight: .light)).foregroundColor(.primary)
            Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(.secondary).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
