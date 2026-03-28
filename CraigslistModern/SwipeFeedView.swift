import SwiftUI

struct SwipeItem: Identifiable {
    let id: UUID
    let listing: LiveListing
    let zIndex: Double
    var undoneAction: SwipeAction? = nil
}

enum SwipeAction {
    case hide
    case vote
    case favorite
}

struct SwipeFeedView: View {
    @EnvironmentObject var appState: AppState
    var listings: [LiveListing]
    @Binding var selectedListingID: UUID?
    @Binding var isDetailPresented: Bool
    
    var proxy: ScrollViewProxy? = nil
    @State private var swipedIDs: Set<UUID> = []
    
    @State private var actionHistory: [(UUID, SwipeAction)] = []
    @State private var undoneItems: [UUID: SwipeAction] = [:]
    
    private var displayItems: [SwipeItem] {
        var active: [LiveListing] = []
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
    var listing: LiveListing
    var proxy: ScrollViewProxy?
    
    var canUndo: Bool = false
    var onUndo: () -> Void = {}
    var onRemove: (SwipeAction) -> Void
    
    @State private var offset: CGSize = .zero
    @State private var localVoteFill: Bool = false
    @State private var localFavFill: Bool = false
    
    var body: some View {
        
        let isVoted = appState.votedIDs.contains(listing.id) || localVoteFill
        let isFavorited = appState.favoriteIDs.contains(listing.id) || localFavFill
        
        ZStack(alignment: .bottom) {
            Color(.systemGray5)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images?.first, let url = URL(string: firstImageStr) {
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
                    if let createdAt = listing.createdAt, createdAt >= Date().addingTimeInterval(-86400) {
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
                        Text(listing.neighborhood ?? "Local Area").font(.custom("NunitoSans", size: 15).weight(.medium)).foregroundColor(.white.opacity(0.9)).lineLimit(1)
                    }
                }
                
                HStack(spacing: 8) {
                    Spacer()
                    
                    Button(action: { handleButtonTap(action: .hide) }) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: { handleButtonTap(action: .vote) }) {
                        Image(systemName: isVoted ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 56, height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: { handleButtonTap(action: .favorite) }) {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.orange)
                            .frame(width: 56, height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
                    ShareLink(item: URL(string: "https://coriyonslist.app/listing/\(listing.id)")!) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
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
    
    private func handleButtonTap(action: SwipeAction) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if action == .vote { localVoteFill = true }
        if action == .favorite { localFavFill = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            triggerSwipe(action: action)
        }
    }
    
    private func triggerSwipe(action: SwipeAction) {
        withAnimation(.easeOut(duration: 0.15)) {
            switch action {
            case .hide: offset.width = -500
            case .vote: offset.width = 500
            case .favorite: offset.width = 500
            }
        }
        
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
