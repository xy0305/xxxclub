import Foundation

/// Pure identity policy shared by production playback and Swift CI regressions.
enum Pan115Identity {
    static func hash(_ value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.range(of: "^[a-f0-9]{40}$", options: .regularExpression) != nil { return raw }
        guard let components = URLComponents(string: value), components.scheme?.lowercased() == "magnet" else { return "" }
        let hashes = (components.queryItems ?? []).filter { $0.name.lowercased() == "xt" }
            .compactMap { item -> String? in
                guard let text = item.value?.lowercased(), text.hasPrefix("urn:btih:") else { return nil }
                let h = String(text.dropFirst(9))
                return h.range(of: "^[a-f0-9]{40}$", options: .regularExpression) != nil ? h : nil
            }
        return Set(hashes).count == 1 ? hashes[0] : ""
    }

    static func tokens(_ raw: String) -> [String] {
        raw.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    static func strictName(_ filename: String, title: String) -> Bool {
        let base = (filename as NSString).lastPathComponent
        let name = tokens((base as NSString).deletingPathExtension)
        let key = tokens(title)
        // A studio, date, or short generic label is not an identity.
        let letters = key.filter { $0.contains(where: \.isLetter) }
        let code = key.count == 2 && letters.count == 1 && key[1].allSatisfy(\.isNumber) && key[1].count >= 3
        guard code || (key.count >= 4 && letters.count >= 2), name.count >= key.count,
              Array(name.prefix(key.count)) == key else { return false }
        let suffix = name.dropFirst(key.count)
        let allowed: Set<String> = ["mp4", "mkv", "avi", "mov", "wmv", "1080p", "720p", "2160p", "4k", "h264", "h265", "x264", "x265", "hevc", "aac", "web", "dl", "c", "restored"]
        return suffix.allSatisfy { allowed.contains($0) }
    }

    static func manifestMatch(_ filename: String, manifest: [String]) -> Bool {
        let base = (filename as NSString).lastPathComponent.lowercased()
        let matches = manifest.filter { ($0 as NSString).lastPathComponent.lowercased() == base }
        return matches.count == 1
    }

    static func taskMatches(hash expected: String, taskHash: String, taskURL: String) -> Bool {
        let wanted = hash(expected)
        guard !wanted.isEmpty else { return false }
        let explicit = hash(taskHash)
        let linked = hash(taskURL)
        if !explicit.isEmpty && !linked.isEmpty && explicit != linked { return false }
        return explicit == wanted || linked == wanted
    }
}
