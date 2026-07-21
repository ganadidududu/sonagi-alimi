import Foundation

/// Reads the daily 3-source consensus (F3) the scheduler cached for a grid.
///
/// The app never calls Open-Meteo itself — the server already voted and cached
/// the result, so this is a single lightweight GET against the same
/// `getWidgetWeather` endpoint the widgets use. A `nil` return (offline, no
/// cache yet, decode failure) is expected and non-fatal: the caller falls back
/// to the KMA-only daily list it already built.
enum ConsensusClient {
    private static let endpoint =
        "https://asia-northeast3-weather-79c1e.cloudfunctions.net/getWidgetWeather"

    static func fetch(nx: Int, ny: Int) async -> [RemoteConsensusDay]? {
        guard var comps = URLComponents(string: endpoint) else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "nx", value: String(nx)),
            URLQueryItem(name: "ny", value: String(ny)),
        ]
        guard let url = comps.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return nil
            }
            return try JSONDecoder().decode(WidgetWeatherResponse.self, from: data).consensus
        } catch {
            return nil
        }
    }
}

/// Only the `consensus` slice of the endpoint's payload — the widget fields are
/// decoded elsewhere. `consensus` is absent until the scheduler first fills it.
private struct WidgetWeatherResponse: Decodable {
    let consensus: [RemoteConsensusDay]?
}

/// Wire shape mirroring `ConsensusDay` in `firebase/functions/src/consensus.ts`.
struct RemoteConsensusDay: Decodable {
    let date: String            // "YYYYMMDD" KST
    let willRain: Bool
    let level: String           // "unanimous" | "majority" | "single"
    let rainVotes: Int
    let voteCount: Int
    let tempMax: Double?
    let tempMin: Double?
    let precipProbability: Double?
    let sources: [RemoteSource]

    struct RemoteSource: Decodable {
        let source: String
        let saysRain: Bool
        let tempMax: Double?
        let precipProbability: Double?
    }

    /// Maps a server day onto the app's `DailyConsensus`, or nil if the level
    /// string is unrecognised (forward-compatibility guard).
    func toDailyConsensus() -> DailyConsensus? {
        guard let level = DailyConsensus.Level(rawValue: level) else { return nil }
        return DailyConsensus(
            level: level,
            rainVotes: rainVotes,
            voteCount: voteCount,
            sources: sources.map {
                DailyConsensus.SourceView(
                    source: $0.source,
                    saysRain: $0.saysRain,
                    tempMax: $0.tempMax.map { Int($0.rounded()) },
                    precipProbability: $0.precipProbability.map { Int($0.rounded()) }
                )
            }
        )
    }
}
