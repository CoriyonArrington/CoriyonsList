import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var isCheckingAuth = true
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack {
            if isCheckingAuth {
                // Splash / Loading Screen
                Color(.systemGroupedBackground).ignoresSafeArea()
                ProgressView().scaleEffect(1.5).tint(Color.craigslistPurple)
            } else if appState.isAuthenticated {
                mainTabView
            } else {
                AuthView()
            }
        }
        .environmentObject(appState)
        .task {
            await checkInitialSession()
        }
    }
    
    private func checkInitialSession() async {
        await appState.checkAuth()
        withAnimation {
            isCheckingAuth = false
        }
    }
    
    private var mainTabView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                HomeFeedView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)
                
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(1)
                
                PostView()
                    .tabItem { Label("Post", systemImage: "plus.circle.fill") }
                    .tag(2)
                
                FavoritesView()
                    .tabItem { Label("Favorites", systemImage: "heart.fill") }
                    .tag(3)
                
                ChatView()
                    .tabItem { Label("Chat", systemImage: "message.fill") }
                    .tag(4)
            }
            .tint(.craigslistPurple)
            
            if appState.showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text(appState.toastMessage)
                        .font(.custom("NunitoSans", size: 15).weight(.semibold))
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
    }
}
