import Foundation
import Supabase
import SwiftUI

// MARK: - Models
struct ChatThread: Identifiable, Codable, Hashable {
    let id: UUID
    let listingId: UUID
    let buyerId: UUID
    let sellerId: UUID
    let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case lastUpdated = "last_updated"
    }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let threadId: UUID
    let senderId: UUID
    let text: String
    let isEdited: Bool?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case senderId = "sender_id"
        case text
        case isEdited = "is_edited"
        case createdAt = "created_at"
    }
}

struct InboxThread: Identifiable {
    let id: UUID
    let thread: ChatThread
    let listing: LiveListing
}

// MARK: - Live Store
@MainActor
class ChatStore: ObservableObject {
    static let shared = ChatStore()
    
    @Published var inbox: [InboxThread] = []
    @Published var currentMessages: [ChatMessage] = []
    @Published var isLoadingInbox = false
    
    private var realtimeTask: Task<Void, Never>?
    
    // MARK: - Inbox Management
    func fetchInbox(currentUserId: UUID) async {
        isLoadingInbox = true
        defer { isLoadingInbox = false }
        
        do {
            let threads: [ChatThread] = try await SupabaseManager.shared.client.from("chat_threads")
                .select()
                .or("buyer_id.eq.\(currentUserId),seller_id.eq.\(currentUserId)")
                .order("last_updated", ascending: false)
                .execute().value
            
            let listingIds = Array(Set(threads.map { $0.listingId }))
            guard !listingIds.isEmpty else {
                self.inbox = []
                return
            }
            
            let listings: [LiveListing] = try await SupabaseManager.shared.client.from("listings")
                .select()
                .in("id", values: listingIds)
                .execute().value
            
            self.inbox = threads.compactMap { thread in
                guard let listing = listings.first(where: { $0.id == thread.listingId }) else { return nil }
                return InboxThread(id: thread.id, thread: thread, listing: listing)
            }
            
        } catch {
            print("Failed to fetch inbox: \(error)")
        }
    }
    
    // MARK: - Room Management
    func getOrCreateThread(listing: LiveListing, currentUserId: UUID) async -> ChatThread? {
        do {
            let existing: [ChatThread] = try await SupabaseManager.shared.client.from("chat_threads")
                .select()
                .eq("listing_id", value: listing.id)
                .eq("buyer_id", value: currentUserId)
                .execute().value
            
            if let thread = existing.first { return thread }
            
            if listing.sellerId == currentUserId { return nil }
            
            let newThread = ChatThread(
                id: UUID(),
                listingId: listing.id,
                buyerId: currentUserId,
                sellerId: listing.sellerId,
                lastUpdated: Date()
            )
            
            try await SupabaseManager.shared.client.from("chat_threads")
                .insert(newThread)
                .execute()
            
            return newThread
        } catch {
            print("Failed to create thread: \(error)")
            return nil
        }
    }
    
    func fetchMessages(for threadId: UUID) async {
        do {
            let msgs: [ChatMessage] = try await SupabaseManager.shared.client.from("chat_messages")
                .select()
                .eq("thread_id", value: threadId)
                .order("created_at", ascending: true)
                .execute().value
            
            self.currentMessages = msgs
        } catch {
            print("Failed to fetch messages: \(error)")
        }
    }
    
    func sendMessage(text: String, threadId: UUID, senderId: UUID) async {
        let tempMsg = ChatMessage(id: UUID(), threadId: threadId, senderId: senderId, text: text, isEdited: false, createdAt: Date())
        self.currentMessages.append(tempMsg)
        
        do {
            try await SupabaseManager.shared.client.from("chat_messages")
                .insert(tempMsg)
                .execute()
            
            struct UpdateThread: Encodable { let last_updated: Date }
            try await SupabaseManager.shared.client.from("chat_threads")
                .update(UpdateThread(last_updated: Date()))
                .eq("id", value: threadId)
                .execute()
            
        } catch {
            print("Failed to send message: \(error)")
        }
    }
    
    // MARK: - Supabase Realtime
    func subscribeToRealtime(threadId: UUID) async {
        realtimeTask?.cancel()
        
        realtimeTask = Task {
            let channel = SupabaseManager.shared.client.channel("chat-\(threadId)")
            
            let insertions = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "chat_messages",
                filter: "thread_id=eq.\(threadId)"
            )
            
            await channel.subscribe()
            
            for await _ in insertions {
                guard !Task.isCancelled else { break }
                await fetchMessages(for: threadId)
            }
        }
    }
    
    func leaveRoom() {
        realtimeTask?.cancel()
        currentMessages = []
    }
}
