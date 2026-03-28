import SwiftUI
import Supabase

// MARK: - Pager Wrapper
struct ListingPagerView: View {
    @EnvironmentObject var appState: AppState
    @Binding var listings: [LiveListing]
    
    @State private var localIDs: [UUID]
    @Binding var selectedListingID: UUID?
    @Environment(\.dismiss) var dismiss
    
    init(listings: Binding<[LiveListing]>, filteredIDs: [UUID], selectedListingID: Binding<UUID?>) {
        self._listings = listings
        self._localIDs = State(initialValue: filteredIDs)
        self._selectedListingID = selectedListingID
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedListingID) {
                ForEach(localIDs, id: \.self) { id in
                    if let index = listings.firstIndex(where: { $0.id == id }) {
                        ListingDetailView(
                            listing: listings[index],
                            allIDs: localIDs,
                            selectedListingID: $selectedListingID,
                            onDismiss: { dismiss() },
                            onDelete: {
                                appState.toggleHidden(id)
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
}

// MARK: - Main Detail View
struct ListingDetailView: View {
    @EnvironmentObject var appState: AppState
    
    let listing: LiveListing
    let allIDs: [UUID]
    @Binding var selectedListingID: UUID?
    
    var onDismiss: () -> Void
    var onDelete: () -> Void
    
    @State private var showAllActions = false
    @State private var showChatRoom = false
    @State private var showEditSheet = false
    
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
    
    private func handleAction(_ action: @escaping () -> Void) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        action()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if hasNext {
                goNext()
            } else {
                onDismiss()
            }
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
                            if let images = listing.images, !images.isEmpty {
                                ForEach(images, id: \.self) { imageUrlStr in
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
                            } else {
                                Color(.systemGray5).frame(width: UIScreen.main.bounds.width, height: 400)
                            }
                        }
                        .frame(height: 400)
                        .tabViewStyle(.page)
                        
                        HStack(alignment: .top) {
                            CircularActionButton(icon: "xmark", action: onDismiss)
                            Spacer()
                            HStack(spacing: 12) {
                                CircularActionButton(
                                    icon: appState.votedIDs.contains(listing.id) ? "hand.thumbsup.fill" : "hand.thumbsup",
                                    iconColor: .blue,
                                    action: { handleAction { appState.toggleVoted(listing.id) } }
                                )
                                CircularActionButton(
                                    icon: appState.isFavorited(listing.id) ? "heart.fill" : "heart",
                                    iconColor: .orange,
                                    action: { handleAction { appState.toggleFavorite(listing.id) } }
                                )
                                
                                ShareLink(
                                    item: URL(string: "https://coriyonslist.app/listing/\(listing.id)")!,
                                    preview: SharePreview(listing.title)
                                ) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)
                                        .frame(width: 44, height: 44)
                                        .background(Color(.systemBackground))
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                                }
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
                            Text(listing.category ?? "For Sale")
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
                        
                        AttributeIconView(icon: "location", title: listing.neighborhood ?? "Local Area")
                        
                        AttributeIconView(icon: "sparkles", title: listing.condition ?? "Good")
                        
                        AttributeIconView(icon: "clock", title: timeAgo(from: listing.createdAt ?? Date()))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 24)
                    
                    Divider().padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(listing.description ?? "No description provided.")
                            .font(.custom("NunitoSans", size: 16).weight(.regular))
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 24)
                    
                    Divider().padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        GhostActionButton(
                            icon: appState.votedIDs.contains(listing.id) ? "hand.thumbsup.fill" : "hand.thumbsup",
                            title: appState.votedIDs.contains(listing.id) ? "Upvoted" : "Vote / Thumbs Up",
                            action: { handleAction { appState.toggleVoted(listing.id) } },
                            themeColor: .blue,
                            isActive: appState.votedIDs.contains(listing.id)
                        )
                        GhostActionButton(
                            icon: appState.isFavorited(listing.id) ? "heart.fill" : "heart",
                            title: appState.isFavorited(listing.id) ? "Saved to Favorites" : "Save Listing",
                            action: { handleAction { appState.toggleFavorite(listing.id) } },
                            themeColor: .orange,
                            isActive: appState.isFavorited(listing.id)
                        )
                        
                        ShareLink(
                            item: URL(string: "https://coriyonslist.app/listing/\(listing.id)")!,
                            preview: SharePreview(listing.title)
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Listing")
                            }
                            .font(.custom("Montserrat", size: 16).weight(.bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color.primary.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary, lineWidth: 1.5))
                        }
                        
                        if showAllActions {
                            GhostActionButton(
                                icon: "eye.slash",
                                title: "Hide",
                                action: { handleAction { onDelete() } },
                                themeColor: .primary
                            )
                            GhostActionButton(
                                icon: "arrow.uturn.backward",
                                title: "Undo Last Action",
                                action: { appState.triggerToast(message: "Action Undone") },
                                themeColor: .primary
                            )
                            GhostActionButton(
                                icon: "flag",
                                title: "Report Listing",
                                action: { appState.triggerToast(message: "Listing Reported to Admin") },
                                isDestructive: true
                            )
                        }
                        
                        Button(action: { withAnimation { showAllActions.toggle() } }) {
                            Text(showAllActions ? "Show Less" : "Show More Options")
                                .font(.custom("Montserrat", size: 14).weight(.semibold))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
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
            
            // Bottom Sticky Navigation Row
            VStack(spacing: 12) {
                if listing.sellerId == SupabaseManager.shared.client.auth.currentUser?.id {
                    HStack(spacing: 16) {
                        Button(action: { showEditSheet = true }) {
                            Text("Edit Post")
                                .font(.custom("Montserrat", size: 17).weight(.bold))
                                .foregroundColor(Theme.Colors.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(.systemBackground))
                                .overlay(RoundedRectangle(cornerRadius: 16).fill(Theme.Colors.primary.opacity(0.1)))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.primary, lineWidth: 1.5))
                                .cornerRadius(16)
                        }
                        
                        Button(action: {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            withAnimation { appState.listings.removeAll { $0.id == listing.id } }
                            appState.triggerToast(message: "Listing Deleted")
                            onDismiss()
                        }) {
                            Text("Delete")
                                .font(.custom("Montserrat", size: 17).weight(.bold))
                                .foregroundColor(Color(.systemBackground))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.red)
                                .cornerRadius(16)
                        }
                    }
                } else {
                    Button(action: { showChatRoom = true }) {
                        Text("Message Seller")
                            .font(.custom("Montserrat", size: 17).weight(.bold))
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Theme.Colors.primary)
                            .cornerRadius(16)
                    }
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
        .sheet(isPresented: $showEditSheet) {
            EditListingView(listing: listing)
        }
        .fullScreenCover(isPresented: $showChatRoom) {
            NavigationStack {
                ChatRoom(
                    contactName: "Supabase User",
                    contactAvatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200",
                    initialListingId: listing.id,
                    autoFocus: true
                )
            }
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
            Text(title).font(.custom("NunitoSans", size: 14).weight(.semibold)).foregroundColor(Color(UIColor.secondaryLabel)).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
