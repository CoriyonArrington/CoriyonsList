import SwiftUI
import Supabase

// Lightweight model to pull the other user's identity
struct ChatParticipant: Codable, Equatable {
    let id: UUID
    let fullName: String?
    let avatarUrl: String?
    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }
}

struct ChatRoom: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var chatStore = ChatStore.shared
    @Environment(\.dismiss) var dismiss
    
    let listing: LiveListing
    let thread: ChatThread?
    let isModal: Bool
    var autoFocus: Bool
    
    @State private var draftMessage: String = ""
    @State private var activeThreadId: UUID?
    @State private var otherUser: ChatParticipant?
    @FocusState private var isFocused: Bool
    
    @State private var showListingSheet = false
    
    // Trust & Safety State
    @State private var showReportDialog = false
    @State private var showBlockAlert = false
    
    let quickReplies = ["Is this still available?", "I'm interested!", "Can we meet today?", "Are you open to offers?"]
    
    // Helper to identify the other user in the thread securely
    private var targetUserId: UUID? {
        guard let uid = appState.currentUserID else { return nil }
        return (uid == listing.sellerId) ? thread?.buyerId : listing.sellerId
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header (Listing Snippet Only - Seller Info moved to Nav Bar)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: listing.images?.first ?? "")) { phase in
                        if let img = phase.image { img.resizable().scaledToFill() }
                        else { Color(.systemGray5) }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(listing.title).font(Theme.Typography.body(weight: .bold)).lineLimit(1)
                        Text("$\(listing.price)").font(Theme.Typography.caption(weight: .bold)).foregroundColor(Color.craigslistGreen)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 4)
            .zIndex(1)
            
            // Message Feed
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatStore.currentMessages) { msg in
                            MessageBubble(message: msg, isCurrentUser: msg.senderId == appState.currentUserID)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .background(Color(.secondarySystemGroupedBackground))
                .onChange(of: chatStore.currentMessages) { _, _ in
                    if let last = chatStore.currentMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            // Quick Replies (Only show if no messages sent yet)
            if chatStore.currentMessages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickReplies, id: \.self) { reply in
                            Button(action: {
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                draftMessage = reply
                            }) {
                                Text(reply)
                                    .font(Theme.Typography.caption(weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.craigslistPurple.opacity(0.1))
                                    .foregroundColor(Color.craigslistPurple)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemBackground))
            }
            
            // Input Area
            HStack(spacing: 12) {
                TextField("Type a message...", text: $draftMessage)
                    .focused($isFocused)
                    .font(Theme.Typography.body())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: send) {
                    ZStack {
                        Circle()
                            .fill(draftMessage.isEmpty ? Color(.systemGray5) : Color.craigslistPurple)
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(draftMessage.isEmpty ? .gray : .white)
                    }
                }
                .disabled(draftMessage.isEmpty || activeThreadId == nil)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let user = otherUser {
                    HStack(spacing: 8) {
                        AsyncImage(url: URL(string: user.avatarUrl ?? "")) { phase in
                            if let img = phase.image { img.resizable().scaledToFill() }
                            else { Color(.systemGray4).overlay(Image(systemName: "person.fill").foregroundColor(.gray)) }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        Text(user.fullName ?? "User")
                            .font(Theme.Typography.body(weight: .bold))
                            .foregroundColor(.primary)
                    }
                } else {
                    ProgressView()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button("View Listing") {
                        if isModal {
                            dismiss()
                        } else {
                            showListingSheet = true
                        }
                    }
                    .font(Theme.Typography.caption(weight: .bold))
                    .foregroundColor(Color.craigslistPurple)
                    
                    // Trust & Safety Dropdown
                    Menu {
                        Button(role: .destructive, action: { showBlockAlert = true }) {
                            Label("Block User", systemImage: "nosign")
                        }
                        Button(role: .destructive, action: { showReportDialog = true }) {
                            Label("Report User", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(.systemGray3))
                    }
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                if isModal {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.systemGray3))
                            .font(.system(size: 24))
                    }
                }
            }
        }
        .sheet(isPresented: $showListingSheet) {
            ListingPagerView(
                listings: $appState.listings,
                filteredIDs: [listing.id],
                selectedListingID: .constant(listing.id)
            )
        }
        .task {
            // Identify participant and establish thread
            if let uid = appState.currentUserID {
                if let tId = targetUserId {
                    do {
                        self.otherUser = try await SupabaseManager.shared.client.from("profiles")
                            .select().eq("id", value: tId).single().execute().value
                    } catch { }
                }
                
                if let t = thread {
                    self.activeThreadId = t.id
                } else {
                    let newOrExisting = await chatStore.getOrCreateThread(listing: listing, currentUserId: uid)
                    self.activeThreadId = newOrExisting?.id
                }
            }
            
            if let tid = activeThreadId {
                await chatStore.fetchMessages(for: tid)
                await chatStore.subscribeToRealtime(threadId: tid)
            }
            
            if autoFocus { isFocused = true }
        }
        .onDisappear {
            chatStore.leaveRoom()
        }
        // Trust & Safety Overlays
        .confirmationDialog("Report User", isPresented: $showReportDialog, titleVisibility: .visible) {
            Button("Spam or Scam") { submitReport(reason: "Spam or Scam") }
            Button("Offensive Behavior") { submitReport(reason: "Offensive Behavior") }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Why are you reporting this user?")
        }
        .alert("Block User", isPresented: $showBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                if let targetId = targetUserId {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    appState.blockUser(targetId)
                    dismiss()
                }
            }
        } message: {
            Text("You will no longer receive messages or see listings from this user. This action cannot be undone.")
        }
    }
    
    private func submitReport(reason: String) {
        if let targetId = targetUserId {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            appState.reportItem(targetId: targetId, type: "user", reason: reason)
            dismiss()
        }
    }
    
    private func send() {
        guard let tid = activeThreadId, let uid = appState.currentUserID, !draftMessage.isEmpty else { return }
        let textToSend = draftMessage
        draftMessage = ""
        Task {
            await chatStore.sendMessage(text: textToSend, threadId: tid, senderId: uid)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            Text(message.text)
                .font(.custom("NunitoSans", size: 18).weight(.regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isCurrentUser ? Color.craigslistPurple : Color(.systemBackground))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(isCurrentUser ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
            
            if !isCurrentUser { Spacer() }
        }
    }
}
