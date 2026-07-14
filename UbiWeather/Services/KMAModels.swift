import Foundation

// MARK: - Raw response envelope (shared shape across all VilageFcstInfoService_2.0 endpoints)

struct KMAResponse: Decodable {
    struct ResponseBody: Decodable {
        let header: Header
        let body: Body?
    }
    struct Header: Decodable {
        let resultCode: String
        let resultMsg: String
    }
    struct Body: Decodable {
        let items: Items?
    }
    struct Items: Decodable {
        let item: [KMAItem]
    }
    let response: ResponseBody
}

/// One observation/forecast row. `obsrValue` is populated by `getUltraSrtNcst`;
/// `fcstDate`/`fcstTime`/`fcstValue` by the two forecast endpoints. Values are
/// decoded as strings — KMA emits numeric fields as JSON strings.
struct KMAItem: Decodable {
    let category: String
    let baseDate: String
    let baseTime: String
    let fcstDate: String?
    let fcstTime: String?
    let fcstValue: String?
    let obsrValue: String?

    var value: String? { fcstValue ?? obsrValue }
    var doubleValue: Double? { value.flatMap(Double.init) }
    var intValue: Int? { value.flatMap { Int(Double($0) ?? .nan) } }
}

/// KMA `resultCode` → friendly message (spec §10.1).
enum KMAResultCode {
    static func message(for code: String) -> String? {
        guard code != "00" else { return nil }
        switch code {
        case "01": return "일시적인 서버 오류가 발생했어요."
        case "02", "04", "05": return "기상청 서버에 연결할 수 없어요."
        case "03": return "해당 지역의 예보 데이터가 아직 없어요."
        case "10", "11": return "요청 정보에 문제가 있어요."
        case "12": return "지원이 종료된 API예요."
        case "20", "30", "31", "32", "33": return "API 인증에 문제가 있어요. 서비스 키를 확인해 주세요."
        case "21": return "일시적으로 사용할 수 없는 서비스 키예요."
        case "22": return "요청 한도를 초과했어요. 잠시 후 다시 시도해 주세요."
        default: return "날씨 정보를 불러오지 못했어요."
        }
    }
}

struct KMAError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Category codes (spec §2.5, §3.5, §4.5)

enum PTY: Int {
    case none = 0, rain = 1, rainSnow = 2, snow = 3, shower = 4, drizzle = 5, drizzleSnow = 6, snowFlurry = 7

    var condition: WeatherCondition {
        switch self {
        case .none: return .sunny
        case .shower: return .shower
        case .rain, .rainSnow, .drizzle, .drizzleSnow, .snowFlurry, .snow: return .rain
        }
    }

    var isPrecipitating: Bool { self != .none }
}

enum SKY: Int {
    case clear = 1, partlyCloudy = 3, cloudy = 4

    var condition: WeatherCondition {
        switch self {
        case .clear: return .sunny
        case .partlyCloudy: return .partly
        case .cloudy: return .cloudy
        }
    }
}

/// Combines PTY (precipitation type) and SKY (sky state) the way the handoff
/// spec's icon-mapping table does: precipitation always wins over sky state.
func weatherCondition(pty: Int, sky: Int?) -> WeatherCondition {
    if let ptyCase = PTY(rawValue: pty), ptyCase.isPrecipitating {
        return ptyCase.condition
    }
    if let skyCase = SKY(rawValue: sky ?? 1) {
        return skyCase.condition
    }
    return .cloudy
}

func conditionLabel(pty: Int, sky: Int?) -> String {
    if let ptyCase = PTY(rawValue: pty), ptyCase.isPrecipitating {
        switch ptyCase {
        case .shower: return "소나기"
        case .rain: return "비"
        case .rainSnow: return "비/눈"
        case .snow: return "눈"
        case .drizzle: return "빗방울"
        case .drizzleSnow: return "빗방울눈날림"
        case .snowFlurry: return "눈날림"
        case .none: break
        }
    }
    switch SKY(rawValue: sky ?? 1) ?? .clear {
    case .clear: return "맑음"
    case .partlyCloudy: return "구름 많음"
    case .cloudy: return "흐림"
    }
}

/// RN1 display rule (spec §3.8): `-`/`null`/`0` → no precipitation label needed.
func isNoPrecip(rn1Raw: String?) -> Bool {
    guard let raw = rn1Raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return true }
    return raw == "-" || raw == "0" || raw == "0.0" || raw.lowercased() == "null"
}
