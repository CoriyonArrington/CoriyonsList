import SwiftUI

struct ChatRoom: View {
    @EnvironmentObject var appState: AppState
    
    var contactName: String
    var contactAvatar: String? = nil
    var initialListingId: UUID? = nil
    var autoFocus: Bool = false
    
    @Environment(\.dismiss) var dismiss
    @State private var messageText = ""
    @State private var editingMessageId: UUID? = nil
    @State private var showListingDetail = false
    
    @FocusState private var isInputFocused: Bool
    @ObservedObject var chatStore = ChatStore.shared
    
    var thread: ChatThread? {
        chatStore.threads.first(where: { $0.contactName == contactName })
    }
    
    var messages: [ChatMessageBubble] {
        thread?.messages ?? []
    }
    
    var targetListing: LiveListing? {
        let idToFind = thread?.listingId ?? initialListingId
        return appState.listings.first(where: { $0.id == idToFind })
    }
    
    let quickResponses = [
        "Is this still available?",
        "Are you open to offers?",
        "When can I pick this up?",
        "What's the condition?"
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            CraigslistPattern()
            
            ScrollView {
                VStack(spacing: 12) {
                    
                    // Contextual Listing Header
                    if let listing = targetListing {
                        HStack(spacing: Theme.Spacing.medium) {
                            if let firstImg = listing.images?.first, let url = URL(string: firstImg) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                                    else { Color(.systemGray5) }
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(listing.title).font(Theme.Typography.body(weight: .bold)).lineLimit(1)
                                Text("$\(listing.price)").font(Theme.Typography.caption(weight: .bold)).foregroundColor(Theme.Colors.success)
                            }
                            Spacer()
                        }
                        .padding(Theme.Spacing.small)
                        .background(Theme.Colors.surfaceCard)
                        .cornerRadius(Theme.Radius.small)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Color.primary.opacity(0.1)))
                        .padding(.bottom, Theme.Spacing.small)
                    }
                    
                    ForEach(messages) { msg in
                        VStack(alignment: msg.isCurrentUser ? .trailing : .leading, spacing: 4) {
                            ChatBubbleView(message: msg)
                                .contextMenu {
                                    if msg.isCurrentUser {
                                        Button {
                                            messageText = msg.text
                                            editingMessageId = msg.id
                                            isInputFocused = true
                                        } label: { Label("Edit", systemImage: "pencil") }
                                    }
                                    Button(role: .destructive) {
                                        chatStore.deleteMessage(in: contactName, messageId: msg.id)
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            
                            HStack(spacing: 4) {
                                if msg.isEdited {
                                    Text("(Edited)").font(Theme.Typography.helper()).foregroundColor(Theme.Colors.textSecondary)
                                }
                                Text(timeAgoStatic(from: msg.timestamp))
                                    .font(Theme.Typography.helper())
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding(.horizontal, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: msg.isCurrentUser ? .trailing : .leading)
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.vertical, Theme.Spacing.medium)
                .padding(.bottom, messages.isEmpty ? 160 : 100)
            }
            
            // Chat Input Area
            VStack(spacing: 0) {
                // Editing State Header
                if let _ = editingMessageId {
                    HStack {
                        Text("Editing message...").font(Theme.Typography.caption(weight: .bold)).foregroundColor(Theme.Colors.primary)
                        Spacer()
                        Button(action: {
                            editingMessageId = nil
                            messageText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))
                }
                
                // Quick Responses
                if messages.isEmpty && editingMessageId == nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.small) {
                            ForEach(quickResponses, id: \.self) { response in
                                Button(action: { sendMessage(response) }) {
                                    Text(response)
                                        .font(Theme.Typography.caption(weight: .semibold))
                                        .padding(.horizontal, Theme.Spacing.medium)
                                        .padding(.vertical, 8)
                                        .background(Theme.Colors.primary.opacity(0.1))
                                        .foregroundColor(Theme.Colors.primary)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemBackground).opacity(0.95))
                }
                
                Divider().opacity(0.3)
                HStack(spacing: Theme.Spacing.medium) {
                    TextField("Message...", text: $messageText)
                        .focused($isInputFocused)
                        .font(Theme.Typography.body())
                        .padding(.horizontal, Theme.Spacing.medium)
                        .frame(height: 44)
                        .background(Theme.Colors.inputBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    
                    Button(action: { sendMessage(messageText) }) {
                        Image(systemName: editingMessageId != nil ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.primary)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    ChatAvatarView(avatarUrl: contactAvatar ?? thread?.contactAvatar, name: contactName, size: 28)
                    Text(contactName)
                        .font(Theme.Typography.body(weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(Theme.Typography.body(weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if let _ = targetListing {
                    Button("View Listing") {
                        showListingDetail = true
                    }
                    .font(Theme.Typography.body(weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showListingDetail) {
            if let listing = targetListing {
                ListingPagerView(listings: $appState.listings, filteredIDs: [listing.id], selectedListingID: .constant(listing.id))
            }
        }
        .onAppear {
            if autoFocus {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isInputFocused = true }
            }
        }
    }
    
    private func sendMessage(_ text: String) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        if let editId = editingMessageId {
            chatStore.editMessage(in: contactName, messageId: editId, newText: text)
            editingMessageId = nil
        } else {
            chatStore.addMessage(to: contactName, contactAvatar: contactAvatar, message: text, listingId: initialListingId)
        }
        messageText = ""
    }
    
    private func timeAgoStatic(from date: Date) -> String {
        let seconds = -date.timeIntervalSinceNow
        if seconds < 60 { return "Just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = Int(seconds / 3600)
        if hours < 24 { return "\(hours)h ago" }
        let days = Int(seconds / 86400)
        return "\(days)d ago"
    }
}

struct ChatBubbleView: View {
    var message: ChatMessageBubble
    var body: some View {
        HStack {
            if message.isCurrentUser { Spacer() }
            
            Text(message.text)
                .font(Theme.Typography.body())
                .foregroundColor(message.isCurrentUser ? .white : .primary)
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.vertical, 12)
                .background(message.isCurrentUser ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(message.isCurrentUser ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                )
            
            if !message.isCurrentUser { Spacer() }
        }
    }
}
