import SwiftUI

struct SwipeItem: Identifiable {
    let id: UUID
    let listing: Listing
    let zIndex: Double
    var undoneAction: SwipeAction? = nil
}

enum SwipeAction {
    case hide       // Swipe Left
    case vote       // Swipe Right
    case favorite   // Swipe Right
}

struct SwipeFeedView: View {
    @EnvironmentObject var appState: AppState
    var listings: [Listing]
    @Binding var selectedListingID: UUID?
    @Binding var isDetailPresented: Bool
    
    var proxy: ScrollViewProxy? = nil
    @State private var swipedIDs: Set<UUID> = []
    
    // TRACKS HISTORY FOR UNDO AND ANIMATIONS
    @State private var actionHistory: [(UUID, SwipeAction)] = []
    @State private var undoneItems: [UUID: SwipeAction] = [:]
    
    private var displayItems: [SwipeItem] {
        var active: [Listing] = []
        
        for listing in listings {
            if !swipedIDs.contains(listing.id) && !appState.hiddenIDs.contains(listing.id) && !appState.votedIDs.contains(listing.id) && !appState.favoriteIDs.contains(listing.id) {
                active.append(listing)
            }
        }
        
        active.reverse()
        var result: [SwipeItem] = []
        let count = min(3, active.count)
        
        for i in 0..<count {
            let listing = active[i]
            let action = undoneItems[listing.id]
            let item = SwipeItem(id: listing.id, listing: listing, zIndex: Double(3 - i), undoneAction: action)
            result.append(item)
        }
        return result
    }
    
    var body: some View {
        ZStack {
            if displayItems.isEmpty {
                Color.clear
            } else {
                ForEach(displayItems, id: \.id) { item in
                    
                    let flyInOffset: CGFloat = {
                        guard let action = item.undoneAction else { return 0 }
                        return action == .hide ? -500 : 500
                    }()
                    
                    SwipeListingCard(
                        listing: item.listing,
                        proxy: proxy,
                        canUndo: !actionHistory.isEmpty,
                        onUndo: {
                            guard let last = actionHistory.popLast() else { return }
                            undoneItems[last.0] = last.1
                            
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                swipedIDs.remove(last.0)
                                switch last.1 {
                                case .hide: appState.toggleHidden(last.0)
                                case .vote: appState.toggleVoted(last.0)
                                case .favorite: appState.toggleFavorite(last.0)
                                }
                            }
                        },
                        onRemove: { action in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                _ = swipedIDs.insert(item.id)
                                actionHistory.append((item.id, action))
                                undoneItems.removeValue(forKey: item.id)
                            }
                        }
                    )
                    .transition(.asymmetric(insertion: .offset(x: flyInOffset, y: 0), removal: .identity))
                    .onTapGesture {
                        selectedListingID = item.id
                        isDetailPresented = true
                    }
                    .zIndex(item.zIndex)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

struct SwipeListingCard: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    var listing: Listing
    var proxy: ScrollViewProxy?
    
    var canUndo: Bool = false
    var onUndo: () -> Void = {}
    var onRemove: (SwipeAction) -> Void
    
    @State private var offset: CGSize = .zero
    @State private var showShareSheet = false
    
    // We add local fill state to instantly fill the buttons when tapped before the card flies away
    @State private var localVoteFill: Bool = false
    @State private var localFavFill: Bool = false
    
    var body: some View {
        
        let isVoted = appState.votedIDs.contains(listing.id) || localVoteFill
        let isFavorited = appState.favoriteIDs.contains(listing.id) || localFavFill
        
        ZStack(alignment: .bottom) {
            Color(.systemGray5)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Color.clear
                                }
                            }
                        }
                    }
                )
                .clipped()
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.5), .black]),
                        startPoint: UnitPoint(x: 0.5, y: 0.4),
                        endPoint: .bottom
                    )
                )
            
            VStack {
                HStack(spacing: 8) {
                    if listing.distance <= nearbyDistance {
                        Text("Nearby").font(.custom("NunitoSans", size: 12).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 10).padding(.vertical, 6).background(.ultraThickMaterial).clipShape(Capsule())
                    }
                    if listing.datePosted >= Date().addingTimeInterval(-86400) {
                        Text("Just Listed").font(.custom("NunitoSans", size: 12).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 10).padding(.vertical, 6).background(.ultraThickMaterial).clipShape(Capsule())
                    }
                    Spacer()
                }.padding(16)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .bottom) {
                        Text(listing.title).font(.custom("Montserrat", size: 24).weight(.bold)).foregroundColor(.white).lineLimit(2)
                        Spacer()
                        Text("$\(listing.price)").font(.custom("Montserrat", size: 24).weight(.heavy)).foregroundColor(Color.craigslistGreen)
                    }
                    HStack(alignment: .center, spacing: 8) {
                        if let url = URL(string: listing.sellerAvatar) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                                else { Color(.systemGray4) }
                            }.frame(width: 24, height: 24).clipShape(Circle())
                        } else {
                            Circle().fill(Color(.systemGray4)).frame(width: 24, height: 24)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").font(.system(size: 14)).foregroundColor(.yellow)
                            Text("\(String(format: "%.1f", listing.sellerRating)) (\(listing.reviewCount))").font(.custom("NunitoSans", size: 16).weight(.bold)).foregroundColor(.white)
                        }
                        
                        Text("• \(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)").font(.custom("NunitoSans", size: 15).weight(.medium)).foregroundColor(.white.opacity(0.9)).lineLimit(1)
                    }
                }
                
                HStack(spacing: 8) {
                    Spacer()
                    
                    // 1. Hide
                    Button(action: { handleButtonTap(action: .hide) }) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
                    // 2. Thumbs Up
                    Button(action: { handleButtonTap(action: .vote) }) {
                        Image(systemName: isVoted ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 56, height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
                    // 3. Favorite
                    Button(action: { handleButtonTap(action: .favorite) }) {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.orange)
                            .frame(width: 56, height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
                    // 4. Share - Now neutral to match ListingDetailView
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
                    // 5. Undo
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(canUndo ? .white : Color.white.opacity(0.3))
                            .frame(width: 56, height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .disabled(!canUndo)
                    
                    Spacer()
                }
            }
            .padding(16)
            .environment(\.colorScheme, .dark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .offset(x: offset.width, y: offset.height)
        .rotationEffect(.degrees(Double(offset.width / 30)))
        .sheet(isPresented: $showShareSheet) {
            ListingShareSheet().presentationDetents([.height(340)])
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    let trans = gesture.translation
                    if abs(trans.width) > abs(trans.height) {
                        offset = CGSize(width: trans.width, height: 0)
                    } else {
                        offset = CGSize(width: 0, height: trans.height * 0.15)
                    }
                }
                .onEnded { gesture in
                    let trans = gesture.translation
                    
                    if abs(trans.width) > abs(trans.height) {
                        if trans.width < -120 {
                            triggerSwipe(action: .hide)
                        } else if trans.width > 120 {
                            localVoteFill = true
                            triggerSwipe(action: .vote)
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { offset = .zero }
                        }
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { offset = .zero }
                        
                        if trans.height < -50 {
                            withAnimation { proxy?.scrollTo("RecentSection", anchor: .top) }
                        }
                        else if trans.height > 50 {
                            withAnimation { proxy?.scrollTo("TopMarker", anchor: .top) }
                        }
                    }
                }
        )
    }
    
    // Updates local state immediately, then delays the swipe so the user sees the fill
    private func handleButtonTap(action: SwipeAction) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if action == .vote { localVoteFill = true }
        if action == .favorite { localFavFill = true }
        
        // Increased delay to 0.4s to let the button stay visibly filled longer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            triggerSwipe(action: action)
        }
    }
    
    private func triggerSwipe(action: SwipeAction) {
        // Decreased duration to 0.15s so the card flies away much faster
        withAnimation(.easeOut(duration: 0.15)) {
            switch action {
            case .hide: offset.width = -500
            case .vote: offset.width = 500
            case .favorite: offset.width = 500
            }
        }
        
        // Matched the delay to the new faster swipe duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            switch action {
            case .hide: appState.toggleHidden(listing.id)
            case .vote: appState.toggleVoted(listing.id)
            case .favorite: appState.toggleFavorite(listing.id)
            }
            offset = .zero
            onRemove(action)
        }
    }
}

// MARK: - Share Sheet Environment
struct ListingShareSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 12)
                HStack {
                    Text("Share Listing").font(.custom("Montserrat", size: 17).weight(.bold))
                    Spacer()
                    Button("Done") { dismiss() }.font(.custom("Montserrat", size: 17).weight(.bold)).foregroundColor(.primary)
                }.padding(.horizontal, 16).padding(.bottom, 8)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ShareBubbleRow(icon: "message.fill", title: "Message", color: .green)
                    ShareBubbleRow(icon: "envelope.fill", title: "Mail", color: .blue)
                    ShareBubbleRow(icon: "link", title: "Copy", color: .gray)
                    ShareBubbleRow(icon: "airdrop", title: "AirDrop", color: .blue)
                    ShareBubbleRow(icon: "plus.bubble.fill", title: "More", color: .gray)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            
            Divider().padding(.horizontal, 16).padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 0) {
                ShareOptionRow(icon: "flag.fill", title: "Report Listing", color: .red)
                Divider().padding(.leading, 48)
                ShareOptionRow(icon: "eye.slash.fill", title: "Hide Listing", color: .gray)
            }
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

struct ShareBubbleRow: View {
    var icon: String; var title: String; var color: Color
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color(.systemGray5)).frame(width: 60, height: 60)
                    Image(systemName: icon).font(.system(size: 24)).foregroundColor(color)
                }
                Text(title).font(.custom("NunitoSans", size: 12).weight(.semibold)).foregroundColor(.primary)
            }
        }.buttonStyle(.plain)
    }
}

struct ShareOptionRow: View {
    var icon: String; var title: String; var color: Color
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                Image(systemName: icon).foregroundColor(color).font(.system(size: 20)).frame(width: 24)
                Text(title).font(.custom("NunitoSans", size: 16).weight(.semibold)).foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 16).padding(.horizontal, 16)
        }
    }
}
