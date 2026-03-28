import SwiftUI
import Supabase

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    
    // Empty by default for production
    @State private var email = ""
    @State private var password = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                CraigslistPattern()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Logo / Header
                    VStack(spacing: 16) {
                        Image("CraigslistIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                        
                        Text("Welcome to CoriyonsList")
                            .font(Theme.Typography.headingL())
                        
                        Text("Sign in to buy, sell, and chat locally.")
                            .font(Theme.Typography.body())
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    
                    // Form
                    VStack(spacing: 16) {
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(Theme.Typography.caption(weight: .bold))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(.horizontal)
                            .frame(height: 56) // XL Input
                            .background(Theme.Colors.inputBackground)
                            .cornerRadius(Theme.Radius.medium)
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        
                        SecureField("Password", text: $password)
                            .padding(.horizontal)
                            .frame(height: 56) // XL Input
                            .background(Theme.Colors.inputBackground)
                            .cornerRadius(Theme.Radius.medium)
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        
                        Button(action: signIn) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In")
                                }
                            }
                            .font(Theme.Typography.body(weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56) // XL Button
                            .background(Theme.Colors.primary)
                            .cornerRadius(Theme.Radius.medium)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    
                    Spacer()
                    Spacer()
                }
            }
        }
    }
    
    private func signIn() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
                await appState.checkAuth()
            } catch {
                errorMessage = "Invalid email or password. Please try again."
            }
            
            isLoading = false
        }
    }
}
