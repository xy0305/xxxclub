import Foundation

/// Pure identity policy shared by production playback and Swift CI regressions.
enum Pan115Identity {
    static func sameFileName(_ found: String, _ wanted: String) -> Bool {
        let a = (found as NSString).lastPathComponent.lowercased()
        let b = (wanted as NSString).lastPathComponent.lowercased()
        if a == b { return true }
        let foundStem = (a as NSString).deletingPathExtension
        let wantedStem = (b as NSString).deletingPathExtension
        return !foundStem.isEmpty && !wantedStem.isEmpty && foundStem == wantedStem
    }

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

    /// Strip only recognized trailing release metadata; never remove actor/scene words.
    static func semanticTokens(_ raw: String) -> [String] {
        var result = tokens((raw as NSString).lastPathComponent)
        let technical: Set<String> = ["mp4", "mkv", "avi", "mov", "wmv", "480p", "576p", "720p", "1080p", "1440p", "2160p", "4320p", "4k", "8k", "uhd", "fhd", "h264", "h265", "x264", "x265", "hevc", "aac", "web", "dl", "c", "restored", "p2p", "xc", "xxx"]
        while let last = result.last {
            if technical.contains(last) { result.removeLast(); continue }
            // WRB is release metadata only in the explicit MP4-WRB suffix.
            // Do not globally remove possible actor or scene words.
            if last == "wrb", result.dropLast().last == "mp4" {
                result.removeLast(2); continue
            }
            break
        }
        return result
    }

    static func strictName(_ filename: String, title: String) -> Bool {
        let name = semanticTokens(filename)
        let key = semanticTokens(title)
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

    // RELEASE date is parsed only from the resource title; no site added-date input exists.
    struct Release {
        let studio: String
        let date: String
        let tail: [String]
    }

    private static let aliases: [String: [String]] = [
        // Verified release label Bang YNGR / BangYNGR uses BYNGR filenames.
        // Explicit aliases only: never infer arbitrary studio initials.
        "byngr": ["byngr", "bangyngr", "bang.yngr"],
        "brazzers": ["brazzers", "braz", "bz"],
        "pornmegaload": ["pornmegaload", "pml"],
        "naughtyamerica": ["naughtyamerica", "na"],
        "realitykings": ["realitykings", "rk"],
        "teamskeet": ["teamskeet", "ts"],
        "blacked": ["blacked", "blk"],
        "blackedraw": ["blackedraw", "br"],
        "tushy": ["tushy"], "tushyraw": ["tushyraw", "tr"],
        "vixen": ["vixen", "vx"], "deeper": ["deeper"]
    ]

    static func release(_ title: String) -> Release? {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\d)(\d{4}|\d{2})[.\s_/-](\d{2})[.\s_/-](\d{2})(?!\d)"#),
              let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let range = Range(match.range, in: title) else { return nil }
        let values = (1...3).compactMap { index -> Int? in
            guard let r = Range(match.range(at: index), in: title) else { return nil }
            return Int(title[r])
        }
        guard values.count == 3 else { return nil }
        let year = values[0] < 100 ? 2000 + values[0] : values[0]
        guard (2000...2099).contains(year) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = DateComponents(year: year, month: values[1], day: values[2])
        guard let date = calendar.date(from: parts),
              calendar.component(.month, from: date) == values[1],
              calendar.component(.day, from: date) == values[2] else { return nil }
        let prefix = tokens(String(title[..<range.lowerBound])).joined()
        guard !prefix.isEmpty, prefix.allSatisfy(\.isLetter) else { return nil }
        let studio = aliases.first { $0.value.contains(prefix) }?.key ?? prefix
        return Release(studio: studio, date: String(format: "%02d.%02d.%02d", year % 100, values[1], values[2]),
                       tail: tokens(String(title[range.upperBound...])))
    }

    static func studioDateQueries(_ title: String) -> [String] {
        guard let item = release(title) else { return [] }
        let names = aliases[item.studio] ?? [item.studio]
        // Studio-only queries cover punctuation and four-digit-year naming variants;
        // every response is subsequently filtered by the normalized RELEASE date.
        return names.map { "\($0).\(item.date)" } + names
    }

    static func studioDateCandidate(_ filename: String, title: String) -> Bool {
        guard let a = release(title), let b = release(filename) else { return false }
        return a.studio == b.studio && a.date == b.date
    }

    static func distinguishedName(_ filename: String, title: String) -> Bool {
        if strictName(filename, title: title) { return true }
        guard studioDateCandidate(filename, title: title), let a = release(title),
              let b = release(filename) else { return false }
        let key = semanticTokens(a.tail.joined(separator: "."))
        let name = semanticTokens(b.tail.joined(separator: "."))
        guard key.filter({ $0.contains(where: \.isLetter) }).count >= 2 else { return false }
        return name == key
    }

    static func safeStudioHit(_ filename: String, title: String, manifest: [String]) -> Bool {
        guard studioDateCandidate(filename, title: title) else { return false }
        return distinguishedName(filename, title: title)
            || (manifestMatch(filename, manifest: manifest) && manifest.contains {
                ($0 as NSString).lastPathComponent.lowercased() == (filename as NSString).lastPathComponent.lowercased()
                    && distinguishedName($0, title: title)
            })
    }

    /// Exact full scene folders only; no studio-only or catch-all queries.
    static func folderQueries(_ title: String) -> [String] {
        guard let item = release(title) else { return [] }
        let tail = semanticTokens(item.tail.joined(separator: "."))
        guard tail.filter({ $0.contains(where: \.isLetter) }).count >= 2 else { return [] }
        let original = semanticTokens(title).joined(separator: ".")
        let canonical = ([item.studio, item.date] + tail).joined(separator: ".")
        var seen = Set<String>()
        return [original, canonical].filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Conservative pagination proof: reported totals are not unique row counts.
    struct FolderSearchState {
        private(set) var complete = false
        private(set) var inconsistent = false
        private var total: Int?
        private var seen = Set<String>()
        mutating func page(index: Int, reportedTotal: Int, rowKeys: [String]) -> Bool {
            if let previous = total, previous != reportedTotal { inconsistent = true }
            total = reportedTotal
            for key in rowKeys {
                if key.isEmpty || !seen.insert(key).inserted { inconsistent = true }
            }
            // Short pages can occur before count is exhausted. Do not use row count
            // as an end condition when the server reports a positive total.
            let ended = reportedTotal > 0 ? (index + 1) * 100 >= reportedTotal : rowKeys.count < 100
            if ended && !inconsistent && (reportedTotal <= 0 || seen.count == reportedTotal) { complete = true }
            return !ended && index < 2
        }
        static func disposition(folderCount: Int, videoCount: Int, complete: Bool) -> (fallback: Bool, manual: Bool) {
            (folderCount == 0 || folderCount > 8 || videoCount == 0, !complete || folderCount > 1)
        }
    }

    static func folderVideo(_ filename: String, title: String) -> Bool {
        let words = semanticTokens(filename)
        guard !tokens(filename).contains("sample"), !words.isEmpty else { return false }
        if let file = release(filename) {
            if distinguishedName(filename, title: title) { return true }
            // A unique trusted folder supplies the plot. Its video may keep only
            // studio, release date, and actor, but those fields cannot conflict.
            guard let item = release(title) else { return false }
            let actors = semanticTokens(item.tail.joined(separator: ".")).prefix { !$0.contains(where: \.isNumber) }
            let fileTail = semanticTokens(file.tail.joined(separator: "."))
            return file.studio == item.studio && file.date == item.date
                && !actors.isEmpty && fileTail == Array(actors)
        }
        // A trusted scene folder may support actor-only or generic main filenames,
        // but unknown scene/studio/date information must never be discarded.
        guard let item = release(title) else { return false }
        let tail = semanticTokens(item.tail.joined(separator: "."))
        return words == tail || ["movie", "video", "main"].contains(words.joined())
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
