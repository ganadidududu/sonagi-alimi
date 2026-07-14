import Foundation

struct RadarFrame: Identifiable, Equatable {
    let id: String  // the image URL string, stable across refreshes
    let url: URL
    let timestamp: Date

    var timeLabel: String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        df.timeZone = TimeZone(identifier: "Asia/Seoul")
        return df.string(from: timestamp)
    }
}

/// `RadarImgInfoService` isn't fully documented in JSON mode (the spec only
/// shows an XML sample), so instead of guessing an exact key path we scan the
/// decoded JSON tree for any string that looks like a KMA radar image URL.
/// This is resilient to whichever key name (`rdr-img-file`, `image`, ...) the
/// gateway actually uses.
enum RadarFramesParser {
    static func parse(_ data: Data) -> [RadarFrame] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var urls: [String] = []
        collectImageURLStrings(json, into: &urls)

        let df = DateFormatter()
        df.dateFormat = "yyyyMMddHHmm"
        df.timeZone = TimeZone(identifier: "Asia/Seoul")

        let frames: [RadarFrame] = urls.compactMap { string in
            guard let url = URL(string: string) else { return nil }
            guard let timestamp = timestamp(fromFilename: string, formatter: df) else { return nil }
            return RadarFrame(id: string, url: url, timestamp: timestamp)
        }
        return frames.sorted { $0.timestamp < $1.timestamp }
    }

    private static func collectImageURLStrings(_ node: Any, into result: inout [String]) {
        if let dict = node as? [String: Any] {
            for value in dict.values { collectImageURLStrings(value, into: &result) }
        } else if let array = node as? [Any] {
            for value in array { collectImageURLStrings(value, into: &result) }
        } else if let string = node as? String,
                  string.lowercased().hasPrefix("http"),
                  string.lowercased().hasSuffix(".png") {
            result.append(string)
        }
    }

    /// Filenames look like `RDR_CMP_WRC_202607081500.png` — pull the trailing
    /// 12-digit `yyyyMMddHHmm` run right before the extension.
    private static func timestamp(fromFilename urlString: String, formatter: DateFormatter) -> Date? {
        let name = (urlString as NSString).lastPathComponent
        let digits = name.filter(\.isNumber)
        guard digits.count >= 12 else { return nil }
        return formatter.date(from: String(digits.suffix(12)))
    }
}
