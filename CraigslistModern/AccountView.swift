import SwiftUI

struct AccountView: View {
    @AppStorage("isAskAIEnabled") private var isAskAIEnabled = false
    @AppStorage("isSwipeViewEnabled") private var isSwipeViewEnabled = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Header
            VStack(spacing: 12) {
                HStack {
                    Text("Account").font(.custom("Montserrat", size: 17).weight(.bold))
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.custom("Montserrat", size: 17).weight(.bold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 12)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // MARK: - Standard Options
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
                    .padding(.top, 8)
                    
                    // MARK: - Experimental Features
                    VStack(alignment: .leading, spacing: 0) {
                        Text("EXPERIMENTAL FEATURES")
                            .font(.custom("Montserrat", size: 12).weight(.bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        
                        ToggleRow(title: "Enable Swipe View", icon: "rectangle.stack.fill", isOn: $isSwipeViewEnabled)
                        Divider().padding(.leading, 48)
                        ToggleRow(title: "Enable AskAI Chat", icon: "sparkles", isOn: $isAskAIEnabled)
                    }
                    
                    // MARK: - Log Out
                    VStack {
                        Button(action: {}) {
                            Text("Log Out")
                                .font(.custom("Montserrat", size: 16).weight(.bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemBackground))
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
                Text(title).font(.custom("NunitoSans", size: 16).weight(.semibold)).foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 16).padding(.horizontal, 16)
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
                Text(title).font(.custom("NunitoSans", size: 16).weight(.semibold)).foregroundColor(.primary)
            }
            .tint(Color.craigslistPurple)
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
    }
}
