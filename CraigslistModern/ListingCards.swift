import SwiftUI

struct GalleryListingCard: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    var listing: Listing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(.systemGray5)
                .frame(height: 300)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            }
                        }
                    }
                )
                .clipped()
                .overlay(
                    LinearGradient(gradient: Gradient(colors: [.black.opacity(0.3), .clear]), startPoint: .top, endPoint: .center)
                )
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 8) {
                        if listing.distance <= nearbyDistance {
                            Text("Nearby").font(.custom("NunitoSans", size: 11).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 10).padding(.vertical, 6).background(.ultraThickMaterial).clipShape(Capsule())
                        }
                        if listing.datePosted >= Date().addingTimeInterval(-86400) {
                            Text("Just Listed").font(.custom("NunitoSans", size: 11).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 10).padding(.vertical, 6).background(.ultraThickMaterial).clipShape(Capsule())
                        }
                    }.padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: appState.isFavorited(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange) // Always retains the orange stroke outline
                        .frame(width: 36, height: 36)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .padding(12)
                        .onTapGesture { appState.toggleFavorite(listing.id) }
                }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(listing.title).font(.custom("Montserrat", size: 21).weight(.bold)).foregroundColor(.primary).lineLimit(1)
                    Spacer()
                    Text("$\(listing.price)").font(.custom("Montserrat", size: 21).weight(.heavy)).foregroundColor(Color.craigslistGreen)
                }
                
                HStack(alignment: .center, spacing: 6) {
                    if let url = URL(string: listing.sellerAvatar) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            else { Color(.systemGray4) }
                        }.frame(width: 20, height: 20).clipShape(Circle())
                    } else {
                        Circle().fill(Color(.systemGray4)).frame(width: 20, height: 20)
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.yellow)
                        Text("\(String(format: "%.1f", listing.sellerRating)) (\(listing.reviewCount))").font(.custom("NunitoSans", size: 14).weight(.bold)).foregroundColor(.secondary)
                    }
                    Text("• \(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)").font(.custom("NunitoSans", size: 14).weight(.medium)).foregroundColor(.secondary).lineLimit(1)
                    Spacer()
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

struct SquareListingCard: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    var listing: Listing; var size: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(.systemGray5)
                .frame(width: size, height: size)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            }
                        }
                    }
                )
                .clipped()
                .overlay(
                    LinearGradient(gradient: Gradient(colors: [.black.opacity(0.3), .clear]), startPoint: .top, endPoint: .center)
                )
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        if listing.distance <= nearbyDistance {
                            Text("Nearby").font(.custom("NunitoSans", size: 10).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThickMaterial).clipShape(Capsule())
                        }
                        if listing.datePosted >= Date().addingTimeInterval(-86400) {
                            Text("New").font(.custom("NunitoSans", size: 10).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThickMaterial).clipShape(Capsule())
                        }
                    }.padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: appState.isFavorited(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange) // Always retains the orange stroke outline
                        .frame(width: 28, height: 28)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .padding(8)
                        .onTapGesture { appState.toggleFavorite(listing.id) }
                }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(listing.title).font(.custom("Montserrat", size: 14).weight(.bold)).foregroundColor(.primary).lineLimit(1)
                    Spacer()
                    Text("$\(listing.price)").font(.custom("Montserrat", size: 15).weight(.heavy)).foregroundColor(Color.craigslistGreen)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    if let url = URL(string: listing.sellerAvatar) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            else { Color(.systemGray4) }
                        }.frame(width: 14, height: 14).clipShape(Circle())
                    } else {
                        Circle().fill(Color(.systemGray4)).frame(width: 14, height: 14)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.yellow)
                        Text("\(String(format: "%.1f", listing.sellerRating))").font(.custom("NunitoSans", size: 11).weight(.bold)).foregroundColor(.secondary)
                    }
                    Text("• \(String(format: "%.1f", listing.distance)) mi").font(.custom("NunitoSans", size: 11).weight(.medium)).foregroundColor(.secondary).lineLimit(1)
                }
            }
            .padding(10)
            .frame(width: size, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

struct MapFeedCard: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    var listing: Listing
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(.systemGray5)
                .frame(width: 200, height: 220)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            }
                        }
                    }
                )
                .clipped()
            
            LinearGradient(gradient: Gradient(colors: [.black.opacity(0.7), .clear, .black.opacity(0.9)]), startPoint: .top, endPoint: .bottom)
            
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        if listing.distance <= nearbyDistance {
                            Text("Nearby").font(.custom("NunitoSans", size: 10).weight(.bold)).foregroundColor(.black).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.9)).clipShape(Capsule())
                        }
                        if listing.datePosted >= Date().addingTimeInterval(-86400) {
                            Text("New").font(.custom("NunitoSans", size: 10).weight(.bold)).foregroundColor(.black).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.9)).clipShape(Capsule())
                        }
                    }
                    Spacer()
                    Image(systemName: appState.isFavorited(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange) // Always retains the orange stroke outline
                        .frame(width: 28, height: 28)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .onTapGesture { appState.toggleFavorite(listing.id) }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        Text(listing.title).font(.custom("Montserrat", size: 16).weight(.bold)).foregroundColor(.white).lineLimit(1)
                        Spacer()
                        Text("$\(listing.price)").font(.custom("Montserrat", size: 20).weight(.heavy)).foregroundColor(Color.craigslistGreen)
                    }
                    HStack(spacing: 4) {
                        if let url = URL(string: listing.sellerAvatar) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                                else { Color(.systemGray4) }
                            }.frame(width: 16, height: 16).clipShape(Circle())
                        } else {
                            Circle().fill(Color(.systemGray4)).frame(width: 16, height: 16)
                        }
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow)
                            Text("\(String(format: "%.1f", listing.sellerRating)) (\(listing.reviewCount))").font(.custom("NunitoSans", size: 11).weight(.bold)).foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 200, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct GridListingCard: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    var listing: Listing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(.systemGray5)
                .frame(height: 160)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            }
                        }
                    }
                )
                .clipped()
                .overlay(
                    LinearGradient(gradient: Gradient(colors: [.black.opacity(0.3), .clear]), startPoint: .top, endPoint: .center)
                )
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        if listing.distance <= nearbyDistance {
                            Text("Nearby").font(.custom("NunitoSans", size: 10).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThickMaterial).clipShape(Capsule())
                        }
                        if listing.datePosted >= Date().addingTimeInterval(-86400) {
                            Text("New").font(.custom("NunitoSans", size: 10).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThickMaterial).clipShape(Capsule())
                        }
                    }.padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: appState.isFavorited(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange) // Always retains the orange stroke outline
                        .frame(width: 28, height: 28)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .padding(8)
                        .onTapGesture { appState.toggleFavorite(listing.id) }
                }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(listing.title).font(.custom("Montserrat", size: 15).weight(.bold)).foregroundColor(.primary).lineLimit(1)
                    Spacer()
                    Text("$\(listing.price)").font(.custom("Montserrat", size: 16).weight(.heavy)).foregroundColor(Color.craigslistGreen)
                }
                
                HStack(alignment: .center, spacing: 4) {
                    if let url = URL(string: listing.sellerAvatar) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            else { Color(.systemGray4) }
                        }.frame(width: 14, height: 14).clipShape(Circle())
                    } else {
                        Circle().fill(Color(.systemGray4)).frame(width: 14, height: 14)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow)
                        Text("\(String(format: "%.1f", listing.sellerRating))").font(.custom("NunitoSans", size: 11).weight(.bold)).foregroundColor(.secondary)
                    }
                    Text("• \(String(format: "%.1f", listing.distance)) mi").font(.custom("NunitoSans", size: 11).weight(.medium)).foregroundColor(.secondary).lineLimit(1)
                }
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

struct ListListingCard: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("nearbyDistance") private var nearbyDistance: Double = 3.0
    var listing: Listing
    
    var body: some View {
        HStack(spacing: 16) {
            Color(.systemGray5)
                .frame(width: 110, height: 110)
                .overlay(
                    Group {
                        if let firstImageStr = listing.images.first, let url = URL(string: firstImageStr) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            }
                        }
                    }
                )
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: appState.isFavorited(listing.id) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange) // Always retains the orange stroke outline
                        .frame(width: 28, height: 28)
                        .background(.ultraThickMaterial)
                        .clipShape(Circle())
                        .padding(6)
                        .onTapGesture { appState.toggleFavorite(listing.id) }
                }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(listing.title).font(.custom("Montserrat", size: 17).weight(.bold)).foregroundColor(.primary).lineLimit(1)
                    Spacer()
                    Text("$\(listing.price)").font(.custom("Montserrat", size: 18).weight(.heavy)).foregroundColor(Color.craigslistGreen)
                }
                
                HStack(spacing: 6) {
                    if listing.distance <= nearbyDistance {
                        Text("Nearby").font(.custom("NunitoSans", size: 10).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 6).padding(.vertical, 4).background(Color(.systemGray6)).clipShape(Capsule())
                    }
                    if listing.datePosted >= Date().addingTimeInterval(-86400) {
                        Text("New").font(.custom("NunitoSans", size: 10).weight(.bold)).foregroundColor(.primary).padding(.horizontal, 6).padding(.vertical, 4).background(Color(.systemGray6)).clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                HStack(alignment: .center, spacing: 6) {
                    if let url = URL(string: listing.sellerAvatar) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                            else { Color(.systemGray4) }
                        }.frame(width: 16, height: 16).clipShape(Circle())
                    } else {
                        Circle().fill(Color(.systemGray4)).frame(width: 16, height: 16)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow)
                        Text("\(String(format: "%.1f", listing.sellerRating))").font(.custom("NunitoSans", size: 12).weight(.bold)).foregroundColor(.secondary)
                    }
                    Text("• \(String(format: "%.1f", listing.distance)) mi • \(listing.neighborhood)").font(.custom("NunitoSans", size: 12).weight(.medium)).foregroundColor(.secondary).lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
