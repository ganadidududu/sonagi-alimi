import Foundation

/// Client for `RadarImgInfoService`'s `getCmpImg` (nationwide composite radar
/// image). Updates every 5 minutes; only covers the last ~2 days (spec §7.1).
struct RadarAPIClient {
    private let baseURL = "https://apis.data.go.kr/1360000/RadarImgInfoService"
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

    /// - Parameter date: `YYYYMMDD`, KST.
    func compositeFrames(date: String, numOfRows: Int = 50) async throws -> [RadarFrame] {
        let encodedKey = serviceKey.addingPercentEncoding(withAllowedCharacters: Self.encodedKeyAllowedCharacters) ?? serviceKey
        let query = "serviceKey=\(encodedKey)&dataType=JSON&data=CMP_WRC&time=\(date)&numOfRows=\(numOfRows)&pageNo=1"
        guard let url = URL(string: "\(baseURL)/getCmpImg?\(query)") else {
            throw KMAError(message: "레이더 요청 URL을 만들지 못했어요.")
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw KMAError(message: "레이더 서버 응답이 올바르지 않아요.")
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responseDict = json["response"] as? [String: Any],
           let header = responseDict["header"] as? [String: Any],
           let resultCode = header["resultCode"] as? String,
           let message = KMAResultCode.message(for: resultCode) {
            throw KMAError(message: message)
        }

        return RadarFramesParser.parse(data)
    }
}
