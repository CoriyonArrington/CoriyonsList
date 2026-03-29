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
    
    let quickReplies = ["Is this still available?", "I'm interested!", "Can we meet today?", "Are you open to offers?"]
    
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
                        Text("$\(listing.price)").font(Theme.Typography.caption(weight: .bold)).foregroundColor(Theme.Colors.success)
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.screenMargin)
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
                                    .background(Theme.Colors.primary.opacity(0.1))
                                    .foregroundColor(Theme.Colors.primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenMargin)
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
                    .background(Theme.Colors.inputBackground)
                    .cornerRadius(20)
                
                Button(action: send) {
                    ZStack {
                        Circle()
                            .fill(draftMessage.isEmpty ? Theme.Colors.surfaceGray : Theme.Colors.primary)
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(draftMessage.isEmpty ? .gray : .white)
                    }
                }
                .disabled(draftMessage.isEmpty || activeThreadId == nil)
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar) // Hides bottom tabs for full-screen focus
        .toolbar {
            // Centers the Seller's Profile in the Nav Bar
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
            
            // Adds the clever "View Listing" button
            ToolbarItem(placement: .topBarTrailing) {
                Button("View Listing") {
                    if isModal {
                        // If opened from a Listing, just slide the chat away
                        dismiss()
                    } else {
                        // If opened from Inbox, bring up the Listing sheet
                        showListingSheet = true
                    }
                }
                .font(Theme.Typography.caption(weight: .bold))
                .foregroundColor(Theme.Colors.primary)
            }
            
            // Replaces back button with a close icon if it's a modal sheet
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
            // Wrapper to display just this listing cleanly
            ListingPagerView(
                listings: $appState.listings,
                filteredIDs: [listing.id],
                selectedListingID: .constant(listing.id)
            )
        }
        .task {
            // Figure out who the other participant is
            if let uid = appState.currentUserID {
                let targetId = (uid == listing.sellerId) ? thread?.buyerId : listing.sellerId
                if let targetId = targetId {
                    do {
                        self.otherUser = try await SupabaseManager.shared.client.from("profiles")
                            .select().eq("id", value: targetId).single().execute().value
                    } catch { print("Failed to fetch participant: \(error)") }
                }
                
                // Establish Thread
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
                .font(Theme.Typography.body())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isCurrentUser ? Theme.Colors.primary : Color(.systemBackground))
                .foregroundColor(isCurrentUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
            
            if !isCurrentUser { Spacer() }
        }
    }
}
