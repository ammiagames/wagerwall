import Foundation

enum Config {
    private static func value(for key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty else {
            fatalError("Missing config value for key: \(key). Check Secrets.xcconfig.")
        }
        return value
    }

    // MARK: - Supabase
    static var supabaseURL: String { value(for: "SUPABASE_URL") }
    static var supabaseAnonKey: String { value(for: "SUPABASE_ANON_KEY") }

    // MARK: - Google OAuth
    static var googleIOSClientID: String { value(for: "GOOGLE_IOS_CLIENT_ID") }
    static var googleWebClientID: String { value(for: "GOOGLE_WEB_CLIENT_ID") }

    // MARK: - Dev / Auth bypass
    // While auth is disabled, this UUID stands in for a signed-in user so views
    // can fetch data. Flip to nil to re-enable real auth gating.
    static var devUserId: UUID? {
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")
    }
}
