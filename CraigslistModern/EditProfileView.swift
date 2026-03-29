import SwiftUI
import PhotosUI // REQUIRED

struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    // Form State
    @State private var fullName: String = ""
    
    // Native Image Picking State
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    // UI state for image conversion loading
    @State private var isProcessingImage = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // MARK: - Native Avatar Editor
                        // Wrap BOTH the image and the text inside the PhotosPicker so the whole area is tappable
                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            VStack(spacing: 12) {
                                ZStack {
                                    // 1. Show newly picked image
                                    if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                    }
                                    // 2. Fallback to existing cloud avatar
                                    else if let existingUrlStr = appState.displayAvatarURL, let url = URL(string: existingUrlStr) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Color.gray.opacity(0.1)
                                        }
                                    }
                                    // 3. Fallback to generic icon
                                    else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundColor(Theme.Colors.textSecondary)
                                            .background(Circle().fill(Theme.Colors.surfaceCard))
                                    }
                                    
                                    if isProcessingImage {
                                        ProgressView().tint(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.4))
                                            .clipShape(Circle())
                                    }
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                                
                                // Native interaction hint now acts as part of the button
                                Text("Tap to change photo")
                                    .font(Theme.Typography.helper(weight: .bold))
                                    .foregroundColor(Theme.Colors.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Theme.Colors.primary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .disabled(isProcessingImage)
                        .padding(.top, 24)
                        
                        // MARK: - Input Form
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("DISPLAY NAME")
                                    .font(Theme.Typography.helper(weight: .bold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                
                                TextField("e.g. Jane Doe", text: $fullName)
                                    .font(Theme.Typography.body())
                                    .padding(.horizontal, 16)
                                    .frame(height: 56)
                                    .background(Theme.Colors.surfaceCard)
                                    .cornerRadius(Theme.Radius.small)
                                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                    .submitLabel(.done)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenMargin)
                        
                        if appState.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Saving profile & uploading image...")
                                    .font(Theme.Typography.caption())
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding(.top, 40)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                        .disabled(appState.isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let success = await appState.updateProfile(
                                fullName: fullName,
                                avatarImageData: selectedImageData
                            )
                            if success { dismiss() }
                        }
                    }
                    .font(.headline)
                    .foregroundColor(Theme.Colors.primary)
                    .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty || appState.isLoading || isProcessingImage)
                }
            }
            .onAppear {
                self.fullName = appState.currentUserProfile?["full_name"] as? String ?? ""
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    isProcessingImage = true
                    selectedImageData = nil
                    
                    if let newItem = newItem {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        } else {
                            appState.triggerToast(message: "Failed to process image.")
                        }
                    }
                    isProcessingImage = false
                }
            }
        }
    }
}
