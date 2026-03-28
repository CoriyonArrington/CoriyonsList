import SwiftUI

struct AccountView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("isSwipeViewEnabled") private var isSwipeViewEnabled = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
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
                    .padding(.bottom, Theme.Spacing.medium)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                        
                        // My Listings Direct Route
                        Button(action: {
                            UserDefaults.standard.set("My Listings", forKey: "favoritesTabSelection")
                            appState.selectedTab = 3
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "list.bullet.rectangle.portrait")
                                    .foregroundColor(Theme.Colors.primary)
                                    .frame(width: 24, alignment: .leading)
                                Text("My Listings")
                                    .font(Theme.Typography.body(weight: .bold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, Theme.Spacing.screenMargin)
                        }
                        .background(Theme.Colors.surfaceCard)
                        .cornerRadius(Theme.Radius.medium)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        
                        // Experimental Features
                        VStack(alignment: .leading, spacing: 0) {
                            Text("EXPERIMENTAL FEATURES")
                                .font(Theme.Typography.helper(weight: .bold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.horizontal, Theme.Spacing.screenMargin)
                                .padding(.bottom, Theme.Spacing.small)
                            
                            ToggleRow(title: "Enable Swipe View", icon: "rectangle.stack.fill", isOn: $isSwipeViewEnabled)
                        }
                        
                        // Sign Out Button
                        Button(action: {
                            Task {
                                await appState.signOut()
                                dismiss()
                            }
                        }) {
                            Text("Sign Out")
                                .font(Theme.Typography.body(weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.red)
                                .cornerRadius(Theme.Radius.medium)
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        .padding(.top, Theme.Spacing.large)
                    }
                    .padding(.bottom, 40)
                    .padding(.top, Theme.Spacing.small)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Subcomponents
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
