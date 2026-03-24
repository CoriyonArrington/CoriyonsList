import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let name: String
    let message: String
    let time: String
    let color: Color
}

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var chatStatus = "Active"
    
    let mockChats: [ChatMessage] = [
        ChatMessage(name: "Creed Bratton", message: "You are not real man!", time: "1m ago", color: .yellow),
        ChatMessage(name: "Michael Scott", message: "That's what she said.", time: "10m ago", color: .teal),
        ChatMessage(name: "Dwight Schrute", message: "Why pay for something that I ...", time: "1h ago", color: .red),
        ChatMessage(name: "Beesly", message: "What are u doing?", time: "1h ago", color: .blue),
        ChatMessage(name: "Kevin", message: "Really? Are you sure?", time: "2h ago", color: .gray),
        ChatMessage(name: "Oscar", message: ":)", time: "5h ago", color: .gray)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    StatusActionBar(options: ["Active", "Hidden"], selection: $chatStatus)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(mockChats) { chat in
                            ChatRow(chat: chat)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                GlassHeader(searchText: $searchText, placeholder: "Search chat")
            }
        }
    }
}

struct ChatRow: View {
    var chat: ChatMessage
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(chat.color)
                Image(systemName: "person.fill").foregroundColor(.white)
            }
            .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.name).font(.custom("Montserrat", size: 16).weight(.bold))
                Text(chat.message).font(.custom("NunitoSans", size: 14).weight(.regular)).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Text(chat.time).font(.custom("NunitoSans", size: 12).weight(.regular)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
        Divider().padding(.leading, 80)
    }
}

struct StatusActionBar: View {
    var options: [String]
    @Binding var selection: String
    
    var body: some View {
        HStack {
            HStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button(action: { withAnimation { selection = option } }) {
                        Text(option)
                            .font(.custom("Montserrat", size: 14).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selection == option ? Color(.systemBackground) : Color.clear)
                            .cornerRadius(12)
                            .shadow(color: selection == option ? Color.black.opacity(0.1) : Color.clear, radius: 2, x: 0, y: 1)
                    }
                    .foregroundColor(selection == option ? .primary : .secondary)
                }
            }
            .padding(3)
            .background(Color(.systemGray5).opacity(0.6))
            .cornerRadius(14)
            .frame(maxWidth: 240)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}
