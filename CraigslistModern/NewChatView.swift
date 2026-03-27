import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var chatStore = ChatStore.shared
    @State private var searchText = ""
    
    // Dynamically crawl the existing threads to find active contacts
    var existingContacts: [(name: String, avatar: String?)] {
        chatStore.threads
            .map { ($0.contactName, $0.contactAvatar) }
            .sorted { $0.name < $1.name }
    }
    
    var filteredContacts: [(name: String, avatar: String?)] {
        if searchText.isEmpty { return existingContacts }
        return existingContacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar Header
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(Theme.Colors.textSecondary)
                        TextField("Search contacts...", text: $searchText)
                            .font(Theme.Typography.body())
                    }
                    .padding(.horizontal, Theme.Spacing.medium)
                    .frame(height: 44)
                    .background(Theme.Colors.inputBackground)
                    .cornerRadius(Theme.Radius.small)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    .padding(.vertical, Theme.Spacing.medium)
                    
                    Divider().opacity(0.3)
                }
                .background(Color(.systemBackground))
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filteredContacts.isEmpty {
                            Text("No existing contacts found.")
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredContacts, id: \.name) { contact in
                                NavigationLink(destination: ChatRoom(contactName: contact.name, contactAvatar: contact.avatar, autoFocus: true)) {
                                    HStack(spacing: Theme.Spacing.medium) {
                                        ChatAvatarView(avatarUrl: contact.avatar, name: contact.name, size: 48)
                                        
                                        Text(contact.name)
                                            .font(Theme.Typography.body(weight: .bold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, Theme.Spacing.screenMargin)
                                    .padding(.vertical, Theme.Spacing.medium)
                                }
                                Divider().opacity(0.3).padding(.leading, 80)
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Message")
                        .font(Theme.Typography.headingM())
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.Typography.body(weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
    }
}
