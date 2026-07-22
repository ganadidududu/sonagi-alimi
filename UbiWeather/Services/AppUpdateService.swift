import Foundation

/// Checks the server's remote update policy on launch and decides whether to
/// nag ("소프트"), block ("하드"), or do nothing.
///
/// The thresholds live on the server (`getAppConfig`), never baked into the
/// build — a kill-switch has to be able to gate versions already installed,
/// which it can't do if the rule ships inside those same versions. Any failure
/// (offline, bad payload) resolves to `.none`: we never lock someone out of the
/// weather because a config fetch hiccuped.
enum AppUpdateService {
    private static let endpoint =
        "https://asia-northeast3-weather-79c1e.cloudfunctions.net/getAppConfig"

    enum Decision: Equatable {
        case none                       // up to date, or check failed → don't nag
        case soft(latest: String, storeURL: String)   // newer exists; dismissible banner
        case hard(storeURL: String)     // below minSupported; full-screen gate
    }

    struct Config: Decodable {
        let minSupported: String
        let latest: String
        let storeUrl: String
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Default App Store deep link if the server didn't supply one.
    private static let fallbackStoreURL = "https://apps.apple.com/kr/app/id6790794687"

    static func check(current: String = currentVersion) async -> Decision {
        guard let url = URL(string: endpoint) else { return .none }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return .none
            }
            let config = try JSONDecoder().decode(Config.self, from: data)
            let store = config.storeUrl.isEmpty ? fallbackStoreURL : config.storeUrl

            if isVersion(current, lessThan: config.minSupported) {
                return .hard(storeURL: store)
            }
            if isVersion(current, lessThan: config.latest) {
                return .soft(latest: config.latest, storeURL: store)
            }
            return .none
        } catch {
            return .none
        }
    }

    /// Numeric, component-wise "a < b" for dotted versions ("1.9.0" < "1.10.0").
    /// String comparison would get that pair wrong; padding makes uneven lengths
    /// ("1.1" vs "1.1.0") compare equal.
    static func isVersion(_ a: String, lessThan b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(pa.count, pb.count)
        for i in 0..<n {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y }
        }
        return false
    }
}
