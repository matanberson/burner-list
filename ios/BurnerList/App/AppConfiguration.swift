import Foundation

struct AppConfiguration: Sendable {
    let supabaseURL: URL
    let anonymousKey: String

    static func load(bundle: Bundle = .main) -> AppConfiguration {
        guard
            let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: rawURL),
            let key = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty
        else {
            fatalError("Missing Supabase configuration")
        }
        return AppConfiguration(supabaseURL: url, anonymousKey: key)
    }
}
