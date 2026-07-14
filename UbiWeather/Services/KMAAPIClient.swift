import Foundation

/// Thin client for the `VilageFcstInfoService_2.0` endpoints described in
/// `kma_weather_api_spec.md`. Builds the query string by hand (rather than
/// via `URLComponents.queryItems`) because data.go.kr service keys commonly
/// contain `+`/`/`/`=`, which `URLComponents` does not reliably re-encode.
struct KMAAPIClient {
    private let baseURL = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0"
    private let serviceKey: String
    private let session: URLSession

    init(serviceKey: String, session: URLSession = .shared) {
        self.serviceKey = serviceKey
        self.session = session
    }

    private static let encodedKeyAllowedCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    private func makeURL(endpoint: String, extra: [String: String]) -> URL {
        let encodedKey = serviceKey.addingPercentEncoding(withAllowedCharacters: Self.encodedKeyAllowedCharacters) ?? serviceKey
        var query = "serviceKey=\(encodedKey)&dataType=JSON"
        for (key, value) in extra {
            query += "&\(key)=\(value)"
        }
        guard let url = URL(string: "\(baseURL)/\(endpoint)?\(query)") else {
            preconditionFailure("Malformed KMA URL for \(endpoint)")
        }
        return url
    }

    private func fetch(endpoint: String, extra: [String: String]) async throws -> [KMAItem] {
        let url = makeURL(endpoint: endpoint, extra: extra)
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw KMAError(message: "기상청 서버 응답이 올바르지 않아요.")
        }
        let decoded: KMAResponse
        do {
            decoded = try JSONDecoder().decode(KMAResponse.self, from: data)
        } catch {
            throw KMAError(message: "날씨 데이터를 해석하지 못했어요.")
        }
        if let message = KMAResultCode.message(for: decoded.response.header.resultCode) {
            throw KMAError(message: message)
        }
        return decoded.response.body?.items?.item ?? []
    }

    /// `getUltraSrtNcst` — current-conditions observation.
    func ultraSrtNcst(nx: Int, ny: Int, now: Date = Date()) async throws -> [KMAItem] {
        let bt = KMABaseTime.ultraSrtNcst(now: now)
        return try await fetch(endpoint: "getUltraSrtNcst", extra: [
            "numOfRows": "100", "pageNo": "1",
            "base_date": bt.date, "base_time": bt.time,
            "nx": "\(nx)", "ny": "\(ny)",
        ])
    }

    /// `getUltraSrtFcst` — 0~6h forecast (the shower-alert data source).
    func ultraSrtFcst(nx: Int, ny: Int, now: Date = Date()) async throws -> [KMAItem] {
        let bt = KMABaseTime.ultraSrtFcst(now: now)
        return try await fetch(endpoint: "getUltraSrtFcst", extra: [
            "numOfRows": "1000", "pageNo": "1",
            "base_date": bt.date, "base_time": bt.time,
            "nx": "\(nx)", "ny": "\(ny)",
        ])
    }

    /// `getVilageFcst` — multi-day forecast (today + ~2-3 more days).
    func vilageFcst(nx: Int, ny: Int, now: Date = Date()) async throws -> [KMAItem] {
        let bt = KMABaseTime.vilageFcst(now: now)
        return try await fetch(endpoint: "getVilageFcst", extra: [
            "numOfRows": "1000", "pageNo": "1",
            "base_date": bt.date, "base_time": bt.time,
            "nx": "\(nx)", "ny": "\(ny)",
        ])
    }
}
