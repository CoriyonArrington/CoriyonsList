import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()
    
    // Initialized with your live CoriyonsList project credentials
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: "https://osuvlvkpmkbvqoselqaw.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9zdXZsdmtwbWtidnFvc2VscWF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3MDgwNzAsImV4cCI6MjA5MDI4NDA3MH0.Eh3HMZLLL9DTywa8uiCzWet-aVBhf6Gvt9dTtwx2IRc"
        )
    }
}
