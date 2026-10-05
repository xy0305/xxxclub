import Foundation

/// Direct file URLs are distinct from transcoded HLS; never infer original from a quality label.
enum Pan115PlaybackRouting {
    static func directURL(_ value: String) -> URL? {
        guard let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              !url.path.lowercased().hasSuffix(".m3u8"), !url.path.lowercased().hasSuffix(".mpd") else { return nil }
        return url
    }

    static func originalURL(_ object: [String: Any]) -> URL? {
        if let state = object["state"] as? Bool, !state { return nil }
        let data = object["data"] as? [String: Any] ?? [:]
        // video_url can be a transcode. Only explicit download fields establish source-file provenance.
        for container in [object, data] {
            for key in ["download_url", "file_url"] {
                if let text = container[key] as? String, let url = directURL(text) { return url }
            }
            if let entry = container["url"] as? [String: Any], let text = entry["url"] as? String,
               let url = directURL(text) { return url }
        }
        return nil
    }

    static func headers(url: URL, common: [String: String]) -> [String: String] {
        var result = common
        let host = url.host?.lowercased() ?? ""
        // Signed CDN URLs do not need the account cookie. Do not leak it to arbitrary CDN hosts.
        if !(host == "115.com" || host.hasSuffix(".115.com") || host == "115vod.com" || host.hasSuffix(".115vod.com")) {
            result.removeValue(forKey: "Cookie")
        }
        return result
    }
}
