import SwiftUI

struct AccountView: View {
    @AppStorage("isSwipeViewEnabled") private var isSwipeViewEnabled = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header (Adjusted Padding)
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
                    // Main Scroll Content (Reduced spacing to medium for tighter layout)
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        
                        // User Content Link
                        VStack(alignment: .leading, spacing: 0) {
                            NavigationLink(destination: MyListingsView()) {
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
                        }
                        .background(Theme.Colors.surfaceCard)
                        .cornerRadius(Theme.Radius.medium)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        // Removed extra top padding here to fix the gap issue
                        
                        // Standard Options
                        VStack(alignment: .leading, spacing: 0) {
                            AccountActionRow(icon: "gearshape", title: "Settings")
                            Divider().padding(.leading, 48)
                            AccountActionRow(icon: "envelope", title: "Feedback")
                            Divider().padding(.leading, 48)
                            AccountActionRow(icon: "hand.raised", title: "Privacy")
                            Divider().padding(.leading, 48)
                            AccountActionRow(icon: "info.circle", title: "About")
                            Divider().padding(.leading, 48)
                            AccountActionRow(icon: "questionmark.circle", title: "Help")
                        }
                        
                        // Experimental Features
                        VStack(alignment: .leading, spacing: 0) {
                            Text("EXPERIMENTAL FEATURES")
                                .font(Theme.Typography.helper(weight: .bold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.horizontal, Theme.Spacing.screenMargin)
                                .padding(.bottom, Theme.Spacing.small)
                            
                            ToggleRow(title: "Enable Swipe View", icon: "rectangle.stack.fill", isOn: $isSwipeViewEnabled)
                        }
                        
                        // Log Out
                        VStack {
                            Button(action: {}) {
                                Text("Log Out")
                                    .font(Theme.Typography.body(weight: .bold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.Spacing.medium)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(Theme.Radius.small)
                            }
                            .padding(.horizontal, Theme.Spacing.screenMargin)
                        }
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
struct AccountActionRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon).foregroundColor(.primary).frame(width: 24, alignment: .leading)
                Text(title).font(Theme.Typography.body(weight: .semibold)).foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, Theme.Spacing.screenMargin)
        }
    }
}

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
