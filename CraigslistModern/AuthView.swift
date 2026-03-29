import SwiftUI
import AuthenticationServices
import Supabase
import CryptoKit

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isGoogleLoading = false
    @State private var isAppleLoading = false
    @State private var isSignUp = false
    @State private var errorMessage: String?
    
    @State private var webAuthSession: WebAuthSession?
    @State private var appleNonce: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                CraigslistPattern()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.large) {
                        
                        // MARK: - Header
                        VStack(spacing: Theme.Spacing.small) {
                            Image("CraigslistIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.1), radius: 10, y: 4)
                            
                            Text(isSignUp ? "Create Account" : "Welcome Back")
                                .font(Theme.Typography.headingL())
                                .foregroundColor(.primary)
                            
                            Text("Sign in to message sellers and save items.")
                                .font(Theme.Typography.body())
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 40)
                        
                        // MARK: - OAuth Providers
                        VStack(spacing: Theme.Spacing.medium) {
                            // Google Sign In
                            Button(action: {
                                Task { await handleGoogleSignIn() }
                            }) {
                                HStack(spacing: 12) {
                                    if isGoogleLoading {
                                        ProgressView().tint(.primary)
                                    } else {
                                        Image(systemName: "g.circle.fill")
                                            .font(.system(size: 20))
                                        Text("Continue with Google")
                                            .font(Theme.Typography.body(weight: .bold))
                                    }
                                }
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Theme.Colors.surfaceCard)
                                .cornerRadius(Theme.Radius.small)
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                            }
                            .disabled(isGoogleLoading || isLoading || isAppleLoading)
                            
                            // Apple Sign In
                            SignInWithAppleButton(.continue) { request in
                                let nonce = randomNonceString()
                                appleNonce = nonce
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = sha256(nonce)
                            } onCompletion: { result in
                                Task { await handleAppleSignIn(result: result) }
                            }
                            .signInWithAppleButtonStyle(UITraitCollection.current.userInterfaceStyle == .dark ? .white : .black)
                            .frame(height: 56)
                            .cornerRadius(Theme.Radius.small)
                            .disabled(isGoogleLoading || isLoading || isAppleLoading)
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        
                        // MARK: - Divider
                        HStack {
                            VStack { Divider() }
                            Text("or").font(Theme.Typography.caption()).foregroundColor(Theme.Colors.textSecondary)
                            VStack { Divider() }
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        
                        // MARK: - Email / Password Form
                        VStack(spacing: Theme.Spacing.medium) {
                            if let error = errorMessage {
                                Text(error)
                                    .font(Theme.Typography.caption(weight: .semibold))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(.horizontal, Theme.Spacing.medium)
                                .frame(height: 56)
                                .background(Theme.Colors.inputBackground)
                                .cornerRadius(Theme.Radius.small)
                            
                            SecureField("Password", text: $password)
                                .padding(.horizontal, Theme.Spacing.medium)
                                .frame(height: 56)
                                .background(Theme.Colors.inputBackground)
                                .cornerRadius(Theme.Radius.small)
                            
                            Button(action: handleEmailAuth) {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                }
                            }
                            .buttonStyle(MSPPrimaryButtonStyle(isEnabled: !email.isEmpty && !password.isEmpty && !isGoogleLoading && !isAppleLoading))
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        
                        // MARK: - Toggle Mode
                        Button(action: {
                            withAnimation {
                                isSignUp.toggle()
                                errorMessage = nil
                            }
                        }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(Theme.Typography.body(weight: .semibold))
                                .foregroundColor(Theme.Colors.primary)
                        }
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Auth Logic
    
    private func handleEmailAuth() {
        guard !email.isEmpty, !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isSignUp {
                    _ = try await SupabaseManager.shared.client.auth.signUp(email: email, password: password)
                } else {
                    _ = try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
                }
                await appState.checkAuth()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func handleGoogleSignIn() async {
        await MainActor.run {
            isGoogleLoading = true
            errorMessage = nil
        }
        
        do {
            let url = try await SupabaseManager.shared.client.auth.getOAuthSignInURL(
                provider: .google,
                redirectTo: URL(string: "com.coriyon.craigslistmodern://login-callback")!
            )
            
            let sessionProvider = WebAuthSession()
            await MainActor.run { self.webAuthSession = sessionProvider }
            
            let callbackURL = try await sessionProvider.start(url: url, callbackURLScheme: "com.coriyon.craigslistmodern")
            _ = try await SupabaseManager.shared.client.auth.session(from: callbackURL)
            
            await appState.checkAuth()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isGoogleLoading = false
            }
        }
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        await MainActor.run {
            isAppleLoading = true
            errorMessage = nil
        }
        
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = appleNonce,
                  let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                
                await MainActor.run {
                    self.errorMessage = "Unable to fetch identity token."
                    self.isAppleLoading = false
                }
                return
            }
            
            do {
                _ = try await SupabaseManager.shared.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: identityToken, nonce: nonce)
                )
                await appState.checkAuth()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAppleLoading = false
                }
            }
            
        case .failure(let error):
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isAppleLoading = false
            }
        }
    }
    
    // MARK: - Helpers (Apple Sign-In)
    
    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - WebAuthSession Helper
class WebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var authSession: ASWebAuthenticationSession?
    
    @MainActor
    func start(url: URL, callbackURLScheme: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { [weak self] callbackURL, error in
                self?.authSession = nil
                if let error = error { continuation.resume(throwing: error); return }
                if let callbackURL = callbackURL { continuation.resume(returning: callbackURL); return }
                continuation.resume(throwing: URLError(.badURL))
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }
    }
    
    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        return windowScene?.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}
