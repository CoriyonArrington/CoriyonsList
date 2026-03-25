import SwiftUI

struct PostView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                CraigslistPattern()
                
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.craigslistPurple)
                    
                    Text("Create a new listing")
                        .font(.custom("Montserrat", size: 22).weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text("Take photos, add a description, and post your item to the community in seconds.")
                        .font(.custom("NunitoSans", size: 16).weight(.regular))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                    
                    Button(action: {}) {
                        Text("Start Posting")
                            .font(.custom("Montserrat", size: 16).weight(.bold))
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
}
