import SwiftUI
import Supabase

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var chatStore = ChatStore.shared
    
    @State private var searchText = ""
    @State private var statusSelection = "Buying"
    
    let options = ["Buying", "Selling"]
    
    // Live computed property for search and tabs
    var filteredInbox: [InboxThread] {
        guard let uid = appState.currentUserID else { return [] }
        let filtered = chatStore.inbox.filter { item in
            statusSelection == "Buying" ? item.thread.buyerId == uid : item.thread.sellerId == uid
        }
        if searchText.isEmpty { return filtered }
        return filtered.filter { $0.listing.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                CraigslistPattern()
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    // MARK: - Custom Scrollable Segmented Bar (Matches FavoritesView)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.small) {
                            ForEach(options, id: \.self) { option in
                                Button(action: {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        statusSelection = option
                                    }
                                }) {
                                    Text(option)
                                        .font(Theme.Typography.caption(weight: statusSelection == option ? .bold : .semibold))
                                        .padding(.horizontal, Theme.Spacing.medium)
                                        .frame(minHeight: 38)
                                        .background(statusSelection == option ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                                        .foregroundColor(statusSelection == option ? Color(.systemBackground) : .primary)
                                        .cornerRadius(Theme.Radius.small)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                    }
                    .padding(.top, Theme.Spacing.medium)
                    .padding(.bottom, Theme.Spacing.large)
                    
                    Text("Inbox")
                        .font(Theme.Typography.headingM())
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        .padding(.bottom, Theme.Spacing.medium)
                    
                    // MARK: - Inbox Content
                    if chatStore.isLoadingInbox {
                        Spacer()
                        ProgressView().tint(Theme.Colors.primary)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    } else if filteredInbox.isEmpty {
                        Spacer()
                        VStack(spacing: Theme.Spacing.medium) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text(statusSelection == "Buying" ? "No buying messages yet." : "No selling messages yet.")
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredInbox) { item in
                                ZStack {
                                    InboxRow(item: item)
                                    // Hides the double arrow by burying the link in a ZStack
                                    NavigationLink(destination: ChatRoom(listing: item.listing, thread: item.thread, isModal: false, autoFocus: false)) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: Theme.Spacing.screenMargin, bottom: 6, trailing: Theme.Spacing.screenMargin))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { deleteThread(item: item) } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .safeAreaInset(edge: .top) {
                    // Injects the global Header View with the Search Bar
                    GlassHeader(searchText: $searchText, placeholder: "Search messages")
                }
            }
            .navigationBarHidden(true)
            .task {
                if let uid = appState.currentUserID {
                    await chatStore.fetchInbox(currentUserId: uid)
                }
            }
        }
    }
    
    private func deleteThread(item: InboxThread) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation { chatStore.inbox.removeAll { $0.id == item.id } }
        
        Task {
            do {
                try await SupabaseManager.shared.client.from("chat_threads").delete().eq("id", value: item.thread.id).execute()
            } catch { print("Failed to delete thread: \(error)") }
        }
    }
}

struct InboxRow: View {
    let item: InboxThread
    
    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: item.listing.images?.first ?? "")) { phase in
                if let img = phase.image { img.resizable().scaledToFill() }
                else { Color(.systemGray5).overlay(Image(systemName: "photo").foregroundColor(.gray)) }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.listing.title)
                    .font(Theme.Typography.body(weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("$\(item.listing.price)")
                    .font(Theme.Typography.caption(weight: .bold))
                    .foregroundColor(Theme.Colors.success)
                
                Text("Tap to view conversation")
                    .font(Theme.Typography.caption())
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Color(.systemGray3))
                .font(.system(size: 14, weight: .bold))
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}
