import SwiftUI
import AuthenticationServices
import Supabase
import CryptoKit

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    
    enum AuthField: Hashable {
        case email, password
    }
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isGoogleLoading = false
    @State private var isAppleLoading = false
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    @FocusState private var focusedField: AuthField?
    
    @State private var webAuthSession: WebAuthSession?
    @State private var appleNonce: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Simplified background for cleaner contrast
                Color(.systemGroupedBackground).ignoresSafeArea()
                
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
                            // Google Sign In (Softened border to look like a button, not an input)
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
                                .background(Color(.systemBackground))
                                .cornerRadius(Theme.Radius.small)
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Color.primary.opacity(0.3), lineWidth: 1))
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
                            if let success = successMessage {
                                Text(success)
                                    .font(Theme.Typography.caption(weight: .bold))
                                    .foregroundColor(Color(.systemBackground))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                            
                            if let error = errorMessage {
                                Text(error)
                                    .font(Theme.Typography.caption(weight: .bold))
                                    .foregroundColor(Color(.systemBackground))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                            
                            // WCAG Compliant Inputs (Heavy border ONLY on active focus)
                            TextField("Email", text: $email)
                                .focused($focusedField, equals: .email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(.horizontal, Theme.Spacing.medium)
                                .frame(height: 56)
                                .background(Theme.Colors.inputBackground)
                                .cornerRadius(Theme.Radius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                                        .stroke(focusedField == .email ? Color.primary : Color.primary.opacity(0.4), lineWidth: focusedField == .email ? 2 : 1)
                                )
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                            
                            SecureField("Password", text: $password)
                                .focused($focusedField, equals: .password)
                                .padding(.horizontal, Theme.Spacing.medium)
                                .frame(height: 56)
                                .background(Theme.Colors.inputBackground)
                                .cornerRadius(Theme.Radius.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                                        .stroke(focusedField == .password ? Color.primary : Color.primary.opacity(0.4), lineWidth: focusedField == .password ? 2 : 1)
                                )
                                .submitLabel(.done)
                                .onSubmit {
                                    focusedField = nil
                                    handleEmailAuth()
                                }
                            
                            // WCAG AAA Compliant Submit Button (Absolute Black/White Contrast)
                            let isFormValid = !email.isEmpty && !password.isEmpty && !isGoogleLoading && !isAppleLoading
                            Button(action: {
                                focusedField = nil
                                handleEmailAuth()
                            }) {
                                if isLoading {
                                    ProgressView().tint(Color(.systemBackground))
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                }
                            }
                            .font(Theme.Typography.body(weight: .bold))
                            .foregroundColor(isFormValid ? Color(.systemBackground) : Color(.systemGray2))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isFormValid ? Color.primary : Color(.systemGray5))
                            .cornerRadius(Theme.Radius.small)
                            .disabled(!isFormValid)
                            .padding(.top, 8)
                            
                            // MARK: Forgot Password Button
                            if !isSignUp {
                                Button(action: {
                                    focusedField = nil
                                    handleResetPassword()
                                }) {
                                    Text("Forgot Password?")
                                        .font(Theme.Typography.body(weight: .bold))
                                        .foregroundColor(.primary)
                                        .underline()
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        
                        // MARK: - Toggle Mode & App Store EULA
                        VStack(spacing: 16) {
                            Button(action: {
                                withAnimation {
                                    isSignUp.toggle()
                                    errorMessage = nil
                                    successMessage = nil
                                    focusedField = nil
                                }
                            }) {
                                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                    .font(Theme.Typography.body(weight: .bold))
                                    .foregroundColor(.primary)
                                    .underline()
                            }
                            
                            if isSignUp {
                                Text("By creating an account, you agree to our [Terms of Service](https://www.coriyon.com/terms-of-service) and [Privacy Policy](https://www.coriyon.com/privacy). Objectionable content or abusive behavior is strictly prohibited and will result in immediate account termination.")
                                    .font(Theme.Typography.helper(weight: .semibold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .tint(.blue)
                                    .padding(.horizontal, Theme.Spacing.screenMargin)
                            }
                        }
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                }
                .onTapGesture {
                    focusedField = nil
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
        successMessage = nil
        
        Task {
            do {
                if isSignUp {
                    _ = try await SupabaseManager.shared.client.auth.signUp(
                        email: email,
                        password: password,
                        redirectTo: URL(string: "com.coriyon.craigslistmodern://login-callback")
                    )
                    
                    await MainActor.run {
                        self.isLoading = false
                        self.successMessage = "Account created! Please check your email to confirm."
                        self.email = ""
                        self.password = ""
                    }
                } else {
                    _ = try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
                    await appState.checkAuth()
                    
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = friendlyErrorMessage(from: error)
                    self.isLoading = false
                }
            }
        }
    }
    
    private func handleResetPassword() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email to reset your password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try await SupabaseManager.shared.client.auth.resetPasswordForEmail(
                    email,
                    redirectTo: URL(string: "com.coriyon.craigslistmodern://reset-callback")!
                )
                
                await MainActor.run {
                    self.isLoading = false
                    self.successMessage = "If an account exists, a password reset link has been sent to your email."
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = friendlyErrorMessage(from: error)
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
                self.errorMessage = friendlyErrorMessage(from: error)
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
                    self.errorMessage = friendlyErrorMessage(from: error)
                    self.isAppleLoading = false
                }
            }
            
        case .failure(let error):
            await MainActor.run {
                self.errorMessage = friendlyErrorMessage(from: error)
                self.isAppleLoading = false
            }
        }
    }
    
    // MARK: - Helpers
    
    private func friendlyErrorMessage(from error: Error) -> String {
        let desc = error.localizedDescription.lowercased()
        
        if desc.contains("invalid login credentials") {
            return "The email or password you entered is incorrect."
        } else if desc.contains("already registered") || desc.contains("already exists") {
            return "An account with this email already exists. Try signing in instead."
        } else if desc.contains("password should be at least") || desc.contains("weak password") {
            return "Your password is too weak. Please use at least 6 characters."
        } else if desc.contains("rate limit") || desc.contains("too many requests") {
            return "Please wait a moment before trying again."
        } else if desc.contains("network") || desc.contains("internet") || desc.contains("offline") || desc.contains("unreachable") {
            return "Please check your internet connection and try again."
        } else if desc.contains("canceled") || desc.contains("cancelled") {
            return "Sign in was canceled."
        }
        
        return "Something went wrong. Please try again."
    }
    
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
