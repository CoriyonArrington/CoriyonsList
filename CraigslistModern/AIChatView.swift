import SwiftUI

struct AIChatSuggestion: Hashable {
    let text: String
    let count: Int
}

struct AIChatView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var query: String = ""

    // Updated to include mock listing counts
    let suggestions = [
        AIChatSuggestion(text: "Find me a cheap TV nearby", count: 3),
        AIChatSuggestion(text: "Vintage furniture under $100", count: 8),
        AIChatSuggestion(text: "Reliable cars for commuting", count: 12),
        AIChatSuggestion(text: "Apartments allowing pets", count: 5)
    ]
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            CraigslistPattern()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(.systemGray3))
                    }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        Text("Hi, Coriyon\nHow can I help you?")
                            .font(.custom("Montserrat", size: 30).weight(.bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(action: { query = suggestion.text }) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(suggestion.text)
                                            .font(.custom("NunitoSans", size: 18).weight(.semibold))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        
                                        Spacer()
                                        
                                        // Dynamic Listing Count
                                        Text("\(suggestion.count) listings")
                                            .font(.custom("Montserrat", size: 22).weight(.bold))
                                            .foregroundColor(.yellow)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .padding(20)
                                    .background(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                    .cornerRadius(20)
                                }
                                .frame(height: 160)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }

                // Chat Input Bar
                VStack(spacing: 0) {
                    Divider().opacity(0.5)
                    HStack(spacing: 12) {
                        TextField("Ask a question", text: $query)
                            .font(.custom("NunitoSans", size: 16))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                            .cornerRadius(30)

                        if query.isEmpty {
                            Button(action: {}) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.primary)
                            }
                            .padding(.trailing, 8)
                        } else {
                            Button(action: { query = "" }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(Color.craigslistPurple)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
    }
}
