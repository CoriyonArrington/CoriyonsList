import SwiftUI
import CoreText
import Clarity // Added Clarity import

@main
struct CraigslistModernApp: App {
    
    // 1. Initialize your global live AppState
    @StateObject private var appState = AppState()
    
    // NEW: Global theme preference (Defaults to System)
    @AppStorage("appTheme") private var appTheme = "System"
    
    var colorScheme: ColorScheme? {
        switch appTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
    
    init() {
        registerCustomFonts()
        
        // Initialize Microsoft Clarity for interaction tracking
        let clarityConfig = ClarityConfig(projectId: "w1lmxm28wt")
        ClaritySDK.initialize(config: clarityConfig)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 2. Inject it into the environment so all sub-views can access Supabase data
                .environmentObject(appState)
                .preferredColorScheme(colorScheme) // Applies the selected theme globally
        }
    }
    
    private func registerCustomFonts() {
        let fonts = [
            "Montserrat-VariableFont_wght",
            "Montserrat-Italic-VariableFont_wght",
            "NunitoSans-VariableFont_YTLC,opsz,wdth,wght",
            "NunitoSans-Italic-VariableFont_YTLC,opsz,wdth,wght"
        ]
        
        for font in fonts {
            guard let url = Bundle.main.url(forResource: font, withExtension: "ttf") else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
