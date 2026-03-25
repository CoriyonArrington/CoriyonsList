import SwiftUI

// MARK: - Pager Wrapper
struct ListingPagerView: View {
    @EnvironmentObject var appState: AppState
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
                                appState.toggleHidden(id)
                                if let nextID = getNextID(after: id) {
                                    withAnimation { selectedListingID = nextID }
                                } else {
                                    dismiss()
                                }
                            }
                        )
                        .tag(id as UUID?)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color(.systemBackground))
            
            if appState.showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text(appState.toastMessage)
                        .font(.custom("NunitoSans", size: 15).weight(.semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                .padding(.bottom, 120)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
    }
    
    private func getNextID(after id: UUID) -> UUID? {
        guard let index = filteredIDs.firstIndex(of: id) else { return nil }
        if index < filteredIDs.count - 1 { return filteredIDs[index + 1] }
        if index > 0 { return filteredIDs[index - 1] }
        return nil
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
    
    @State private var showShareSheet = false
    
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
    
    private var displayedDotIndices: [Int] {
        let total = allIDs.count
        guard total > 0 else { return [] }
        if total <= 5 { return Array(0..<total) }
        
        let current = currentIndex ?? 0
        if current <= 2 { return Array(0..<5) }
        if current >= total - 3 { return Array((total - 5)..<total) }
        return Array((current - 2)...(current + 2))
    }
    
    private func getCategoryColor() -> Color {
        switch listing.category {
        case "Apts / Housing", "Rooms / Shared", "Sublets / Temporary", "Parking / Storage", "Office / Commercial":
            return Color(red: 0.75, green: 0.45, blue: 0.35)
        case "Tech / Software", "Hospitality", "Labor", "Education", "Creative", "Healthcare":
            return Color(red: 0.35, green: 0.60, blue: 0.45)
        case "Activities", "Events", "Volunteers", "Groups", "Lost & Found", "Childcare":
            return .blue
        case "Automotive", "Beauty", "Financial", "Labor / Move", "Real Estate":
            return Color(red: 0.75, green: 0.40, blue: 0.50)
        case "Computer", "Crew", "Domestic", "Event":
            return Color(red: 0.70, green: 0.55, blue: 0.30)
        default:
            return Color.craigslistPurple
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
                                CircularActionButton(
                                    icon: "hand.thumbsup.fill",
                                    iconColor: .blue,
                                    action: { appState.toggleVoted(listing.id) }
                                )
                                CircularActionButton(
                                    icon: "heart.fill",
                                    iconColor: .orange,
                                    action: { appState.toggleFavorite(listing.id) }
                                )
                                CircularActionButton(
                                    icon: "square.and.arrow.up.fill",
                                    iconColor: Color.craigslistGreen,
                                    action: { showShareSheet = true }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 16) {
                            Text(listing.title)
                                .font(.custom("Montserrat", size: 24).weight(.bold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("$\(listing.price)")
                                .font(.custom("Montserrat", size: 24).weight(.heavy))
                                .foregroundColor(Color.craigslistGreen)
                                .layoutPriority(1)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 24)
                    
                    HStack(alignment: .top) {
                        VStack(spacing: 10) {
                            Image(systemName: "tag").font(.system(size: 24, weight: .light)).foregroundColor(getCategoryColor())
                            Text(listing.category)
                                .font(.custom("NunitoSans", size: 12).weight(.bold))
                                .foregroundColor(getCategoryColor())
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(getCategoryColor().opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(getCategoryColor(), lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        
                        AttributeIconView(icon: "location", title: "\(listing.neighborhood)\n\(String(format: "%.1f", listing.distance)) mi")
                        
                        AttributeIconView(icon: "sparkles", title: listing.condition)
                        
                        AttributeIconView(icon: "clock", title: timeAgo(from: listing.datePosted))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 24)
                    
                    Divider().padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(listing.description).font(.custom("NunitoSans", size: 16).weight(.regular)).foregroundColor(.secondary).lineSpacing(6)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 24)
                    
                    Divider().padding(.horizontal, 20)
                    
                    HStack(alignment: .top, spacing: 16) {
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
                                Text(listing.sellerName).font(.custom("Montserrat", size: 17).weight(.semibold)).foregroundColor(.primary)
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.shield.fill")
                                    Text("Verified by ID.me")
                                }
                                .font(.custom("Montserrat", size: 10).weight(.bold)).foregroundColor(.green).padding(.horizontal, 6).padding(.vertical, 4).background(Color.green.opacity(0.15)).cornerRadius(6)
                            }
                            HStack(spacing: 4) {
                                HStack(spacing: 2) { ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.yellow) } }
                                Text(String(format: "%.1f", listing.sellerRating)).font(.custom("Montserrat", size: 13).weight(.bold)).foregroundColor(.primary)
                                Text("(\(listing.reviewCount) reviews)").font(.custom("NunitoSans", size: 13).weight(.regular)).foregroundColor(.secondary)
                            }
                            Text(listing.sellerType).font(.custom("NunitoSans", size: 14).weight(.regular)).foregroundColor(.secondary).padding(.top, 2)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 24)
                    
                    VStack(spacing: 12) {
                        GhostActionButton(
                            icon: "hand.thumbsup.fill",
                            title: appState.votedIDs.contains(listing.id) ? "Upvoted" : "Vote / Thumbs Up",
                            action: { appState.toggleVoted(listing.id) },
                            themeColor: .blue,
                            isActive: appState.votedIDs.contains(listing.id)
                        )
                        GhostActionButton(
                            icon: "heart.fill",
                            title: appState.isFavorited(listing.id) ? "Saved to Favorites" : "Save Listing",
                            action: { appState.toggleFavorite(listing.id) },
                            themeColor: .orange,
                            isActive: appState.isFavorited(listing.id)
                        )
                        GhostActionButton(
                            icon: "square.and.arrow.up.fill",
                            title: "Share Listing",
                            action: { showShareSheet = true },
                            themeColor: Color.craigslistGreen
                        )
                        GhostActionButton(
                            icon: "flag",
                            title: "Remove Listing",
                            action: onDelete,
                            themeColor: .gray
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    HStack {
                        Button(action: goPrev) { Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).frame(width: 56, height: 56).contentShape(Rectangle()) }
                        .disabled(!hasPrev).foregroundColor(hasPrev ? .primary : Color(.systemGray3))
                        Spacer()
                        Text("\(displayIndex) of \(allIDs.count) listings").font(.custom("Montserrat", size: 15).weight(.semibold)).foregroundColor(.primary)
                        Spacer()
                        Button(action: goNext) { Image(systemName: "chevron.right").font(.system(size: 20, weight: .semibold)).frame(width: 56, height: 56).contentShape(Rectangle()) }
                        .disabled(!hasNext).foregroundColor(hasNext ? .primary : Color(.systemGray3))
                    }
                    .frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemBackground))
            
            VStack(spacing: 12) {
                Button(action: {}) {
                    Text("Message Seller").font(.custom("Montserrat", size: 17).weight(.bold)).foregroundColor(Color(.systemBackground)).frame(maxWidth: .infinity).frame(height: 56).background(Color.primary).cornerRadius(16)
                }
                
                HStack(spacing: 6) {
                    ForEach(displayedDotIndices, id: \.self) { index in
                        let isActive = index == (currentIndex ?? 0)
                        Circle()
                            .fill(isActive ? Color.primary : Color(.systemGray4))
                            .frame(width: isActive ? 8 : 6, height: isActive ? 8 : 6)
                            .animation(.spring(), value: currentIndex)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .background(
                ZStack {
                    Color(.systemBackground)
                    CraigslistPattern()
                }
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
            )
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showShareSheet) {
            ListingShareSheet().presentationDetents([.height(340)])
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Buttons
struct CircularActionButton: View {
    let icon: String; var iconColor: Color = .primary; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

struct GhostActionButton: View {
    let icon: String; let title: String; let action: () -> Void;
    var isDestructive: Bool = false; var themeColor: Color? = nil
    var isActive: Bool = false
    
    var body: some View {
        let color = themeColor ?? (isDestructive ? .red : .primary)
        
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.custom("Montserrat", size: 16).weight(.bold))
            .foregroundColor(isActive ? Color(.systemBackground) : color)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(isActive ? color : color.opacity(0.1))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color, lineWidth: 1.5))
        }
    }
}

struct AttributeIconView: View {
    let icon: String; let title: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 24, weight: .light)).foregroundColor(.primary)
            Text(title).font(.custom("NunitoSans", size: 14).weight(.semibold)).foregroundColor(.secondary).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
