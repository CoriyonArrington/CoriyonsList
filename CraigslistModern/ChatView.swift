import SwiftUI

// MARK: - Global Chat State
class ChatStore: ObservableObject {
    static let shared = ChatStore()
    @Published var threads: [ChatThread] = []
    
    func addMessage(to contact: String, contactAvatar: String? = nil, message: String, listingId: UUID? = nil) {
        let newBubble = ChatMessageBubble(text: message, isCurrentUser: true, timestamp: Date())
        if let index = threads.firstIndex(where: { $0.contactName == contact }) {
            threads[index].messages.append(newBubble)
            threads[index].lastUpdated = Date()
            if let avatar = contactAvatar, threads[index].contactAvatar == nil {
                threads[index].contactAvatar = avatar
            }
            if let lId = listingId, threads[index].listingId == nil {
                threads[index].listingId = lId
            }
        } else {
            let newThread = ChatThread(contactName: contact, contactAvatar: contactAvatar, messages: [newBubble], lastUpdated: Date(), listingId: listingId)
            threads.append(newThread)
        }
        threads.sort { $0.lastUpdated > $1.lastUpdated }
    }
    
    func toggleHidden(for contact: String) {
        if let index = threads.firstIndex(where: { $0.contactName == contact }) {
            threads[index].isHidden.toggle()
        }
    }
    
    func deleteThread(for contact: String) {
        threads.removeAll { $0.contactName == contact }
    }
    
    func deleteMessage(in contact: String, messageId: UUID) {
        guard let tIndex = threads.firstIndex(where: { $0.contactName == contact }) else { return }
        threads[tIndex].messages.removeAll { $0.id == messageId }
        // If thread is empty after deletion, remove the thread
        if threads[tIndex].messages.isEmpty {
            deleteThread(for: contact)
        }
    }
    
    func editMessage(in contact: String, messageId: UUID, newText: String) {
        guard let tIndex = threads.firstIndex(where: { $0.contactName == contact }),
              let mIndex = threads[tIndex].messages.firstIndex(where: { $0.id == messageId }) else { return }
        threads[tIndex].messages[mIndex].text = newText
        threads[tIndex].messages[mIndex].isEdited = true
    }
}

struct ChatThread: Identifiable {
    let id = UUID()
    let contactName: String
    var contactAvatar: String?
    var messages: [ChatMessageBubble]
    var lastUpdated: Date
    var listingId: UUID?
    var isHidden: Bool = false
}

struct ChatMessageBubble: Identifiable {
    let id = UUID()
    var text: String
    let isCurrentUser: Bool
    let timestamp: Date
    var isEdited: Bool = false
}

// MARK: - Shared Avatar Helper
struct ChatAvatarView: View {
    var avatarUrl: String?
    var name: String
    var size: CGFloat = 48
    
    var body: some View {
        if let urlStr = avatarUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    fallback
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallback
        }
    }
    
    var fallback: some View {
        ZStack {
            Circle().fill(Theme.Colors.surfaceGray)
            Text(String(name.prefix(1)))
                .font(Theme.Typography.body(weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Main View
struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var chatStore = ChatStore.shared
    
    @State private var searchText = ""
    @State private var chatStatus = "Active"
    @State private var showNewChat = false
    
    let options = ["Active", "Hidden"]
    
    var filteredThreads: [ChatThread] {
        let statusFiltered = chatStore.threads.filter { thread in
            chatStatus == "Hidden" ? thread.isHidden : !thread.isHidden
        }
        if searchText.isEmpty {
            return statusFiltered
        } else {
            return statusFiltered.filter { $0.contactName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                CraigslistPattern() // Pattern applied to inbox
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Segmented Control
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.small) {
                                ForEach(options, id: \.self) { option in
                                    Button(action: {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            chatStatus = option
                                        }
                                    }) {
                                        Text(option)
                                            .font(Theme.Typography.caption(weight: chatStatus == option ? .bold : .semibold))
                                            .padding(.horizontal, Theme.Spacing.medium)
                                            .frame(minHeight: 38)
                                            .background(chatStatus == option ? Theme.Colors.primary : Theme.Colors.surfaceCard)
                                            .foregroundColor(chatStatus == option ? Color(.systemBackground) : .primary)
                                            .cornerRadius(Theme.Radius.small)
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.screenMargin)
                        }
                        .padding(.top, Theme.Spacing.medium)
                        .padding(.bottom, Theme.Spacing.large)
                        
                        // Threads List
                        if filteredThreads.isEmpty {
                            VStack(spacing: Theme.Spacing.medium) {
                                Image(systemName: chatStatus == "Hidden" ? "eye.slash.fill" : "message.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("No \(chatStatus.lowercased()) messages.")
                                    .font(Theme.Typography.body())
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredThreads) { thread in
                                    NavigationLink(destination: ChatRoom(contactName: thread.contactName, contactAvatar: thread.contactAvatar)) {
                                        ChatRow(thread: thread, chatStore: chatStore)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Spacer(minLength: 80)
                    }
                }
                .safeAreaInset(edge: .top) {
                    GlassHeader(searchText: $searchText, placeholder: "Search messages")
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showNewChat = true }) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Theme.Colors.primary)
                                .clipShape(Circle())
                                .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, Theme.Spacing.screenMargin)
                        .padding(.bottom, Theme.Spacing.large)
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
            }
        }
    }
}

struct ChatRow: View {
    var thread: ChatThread
    var chatStore: ChatStore
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.medium) {
                
                ChatAvatarView(avatarUrl: thread.contactAvatar, name: thread.contactName, size: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(thread.contactName).font(Theme.Typography.body(weight: .bold)).foregroundColor(.primary)
                    if let lastMsg = thread.messages.last {
                        Text(lastMsg.text).font(Theme.Typography.caption()).foregroundColor(Theme.Colors.textSecondary).lineLimit(1)
                    }
                }
                Spacer()
                
                Text(formatInboxDate(thread.lastUpdated))
                    .font(Theme.Typography.helper(weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.vertical, Theme.Spacing.medium)
            
            Divider().opacity(0.3).padding(.leading, 88)
        }
        .background(Color(.systemGroupedBackground).opacity(0.95))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { chatStore.deleteThread(for: thread.contactName) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                withAnimation { chatStore.toggleHidden(for: thread.contactName) }
            } label: {
                Label(thread.isHidden ? "Unhide" : "Hide", systemImage: thread.isHidden ? "eye" : "eye.slash")
            }
            .tint(Theme.Colors.surfaceGray)
        }
    }
    
    // Formats timestamps like the native iOS Messages inbox
    private func formatInboxDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: date)
        }
    }
}
