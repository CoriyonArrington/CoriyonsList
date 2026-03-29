import SwiftUI

struct AccountView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("isSwipeViewEnabled") private var isSwipeViewEnabled = true
    @AppStorage("appTheme") private var appTheme = "System"
    @Environment(\.dismiss) var dismiss
    
    @State private var showDeleteConfirmation = false
    @State private var showEditProfile = false
    
    var currentTheme: ColorScheme? {
        switch appTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    
                    // MARK: - Header
                    VStack(spacing: Theme.Spacing.small) {
                        HStack {
                            Text("Account").font(Theme.Typography.headingM())
                            Spacer()
                            Button("Done") { dismiss() }
                                .font(Theme.Typography.body(weight: .bold))
                                .foregroundColor(Theme.Colors.primary)
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        .padding(.top, Theme.Spacing.large)
                    }
                    
                    // MARK: - Actionable User Profile Card
                    Button(action: { showEditProfile = true }) {
                        UserProfileCard(canEdit: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    
                    // MARK: - Settings List
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            UserDefaults.standard.set("My Listings", forKey: "favoritesTabSelection")
                            appState.selectedTab = 3
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "tag.fill").foregroundColor(.primary).frame(width: 24, alignment: .leading)
                                Text("My Listings").font(Theme.Typography.body(weight: .semibold)).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, Theme.Spacing.screenMargin)
                        }
                        
                        Divider().padding(.leading, 40)
                        
                        ToggleRow(title: "Swipe Feed Mode", icon: "hand.draw.fill", isOn: $isSwipeViewEnabled)
                            .padding(.vertical, 4)
                        
                        Divider().padding(.leading, 40)
                        
                        HStack {
                            Image(systemName: "circle.lefthalf.filled").foregroundColor(.primary).frame(width: 24, alignment: .leading)
                            Text("Theme").font(Theme.Typography.body(weight: .semibold)).foregroundColor(.primary)
                            Spacer()
                            Picker("", selection: $appTheme) {
                                Text("System").tag("System")
                                Text("Light").tag("Light")
                                Text("Dark").tag("Dark")
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.Colors.textSecondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                    }
                    .background(Theme.Colors.surfaceCard)
                    .cornerRadius(Theme.Radius.medium)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    
                    // MARK: - Destructive Actions
                    VStack(spacing: 8) {
                        
                        if let errorMsg = appState.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(errorMsg)
                                    .font(Theme.Typography.caption(weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(Theme.Radius.small)
                            .padding(.horizontal, Theme.Spacing.screenMargin)
                            .padding(.bottom, 8)
                        }
                        
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Text("Delete Account")
                                .font(Theme.Typography.body(weight: .bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Theme.Spacing.screenMargin)
                                .padding(.vertical, 16)
                        }
                        .background(Theme.Colors.surfaceCard)
                        .cornerRadius(Theme.Radius.medium)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        
                        Text("This will permanently delete your account, listings, and messages. This action cannot be undone.")
                            .font(Theme.Typography.caption())
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.screenMargin + 16)
                    }
                    
                    Spacer().frame(height: 20)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button(action: {
                        Task {
                            await appState.signOut()
                            dismiss()
                        }
                    }) {
                        Text("Sign Out")
                            .font(Theme.Typography.body(weight: .bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(.systemGray5))
                            .cornerRadius(Theme.Radius.medium)
                    }
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea(edges: .bottom))
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        appState.errorMessage = nil
                        let success = await appState.deleteAccount()
                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to permanently delete your account? All your data will be lost.")
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
        }
        .preferredColorScheme(currentTheme)
        .onDisappear {
            appState.errorMessage = nil
        }
    }
}

// MARK: - User Profile Card Component
struct UserProfileCard: View {
    @EnvironmentObject var appState: AppState
    var canEdit: Bool = false
    
    var body: some View {
        let name = appState.currentUserProfile?["full_name"] as? String ?? "New User"
        let email = appState.currentUserEmail
        let avatarUrl = appState.displayAvatarURL
        let rating = appState.currentUserProfile?["rating"] as? Double ?? 0.0
        let reviewCount = appState.currentUserProfile?["review_count"] as? Int ?? 0
        
        HStack(spacing: 16) {
            // MARK: Avatar Image
            if let urlString = avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.1)
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Theme.Colors.surfaceCard))
            }
            
            // MARK: Details
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(Theme.Typography.headingS())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7) // Prevents wrapping by scaling down
                
                if let userEmail = email {
                    Text(userEmail)
                        .font(Theme.Typography.caption())
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5) // Aggressive scaling to ensure long emails fit
                }
                
                if reviewCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < Int(rating) ? "star.fill" : "star")
                                .foregroundColor(Color.craigslistPurple)
                                .font(.system(size: 10)) // Reduced star size to prevent wrapping
                        }
                        Text("(\(reviewCount))")
                            .font(Theme.Typography.caption())
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .fixedSize(horizontal: true, vertical: false) // Forces the HStack to never wrap
                    .padding(.top, 4)
                }
            }
            
            Spacer(minLength: 8)
            
            // MARK: Edit Indicator
            if canEdit {
                HStack(spacing: 6) {
                    Text("Edit Profile")
                        .font(Theme.Typography.caption(weight: .bold))
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(Theme.Colors.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.Colors.primary.opacity(0.1))
                .clipShape(Capsule())
                .layoutPriority(1) // Ensures the edit button never gets squished
            }
        }
        .padding()
        .background(Theme.Colors.surfaceCard)
        .cornerRadius(Theme.Radius.medium)
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
    }
}

// MARK: - Toggle Row Helper
struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.primary).frame(width: 24, alignment: .leading)
            Toggle(isOn: $isOn) {
                Text(title).font(Theme.Typography.body(weight: .semibold)).foregroundColor(.primary)
            }
            .tint(Theme.Colors.primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, Theme.Spacing.screenMargin)
    }
}
