import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                HomeFeedView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)
                
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(1)
                
                PostPlaceholderView()
                    .tabItem { Label("Post", systemImage: "plus.circle.fill") }
                    .tag(2)
                
                FavoritesView()
                    .tabItem { Label("Favorites", systemImage: "heart.fill") }
                    .tag(3)
                
                ChatView()
                    .tabItem { Label("Chat", systemImage: "message.fill") }
                    .tag(4)
            }
            .tint(.craigslistPurple) // Deep Craigslist Purple Global Tint
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.regularMaterial, for: .tabBar)
            
            // Global Toast Notification
            if appState.showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text(appState.toastMessage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .environmentObject(appState)
    }
}

// MARK: - New Post Placeholder
struct PostPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.craigslistPurple)
                
                Text("Create a new listing")
                    .font(.title2.bold())
                
                Text("Take photos, add a description, and post your item to the community in seconds.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                
                Button(action: {}) {
                    Text("Start Posting")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.craigslistPurple)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
            }
        }
    }
}
