//
//  Pan115Client.swift
//  XXXClub
//
//  从 AVDB 搬过来的 115 离线：Cookie + 目录 CID，磁力推送后按标题找视频，再取原画地址。
//  换链 UA 必须和播放器一致，否则 CDN 会 403。
//

import Foundation
import Combine

public enum Pan115PushResult: Equatable {
    case success
    case exists
    case failed(String)

    public var message: String {
        switch self {
        case .success: return "已推送到 115"
        case .exists: return "115 任务已存在"
        case .failed(let msg): return msg
        }
    }
}

public final class Pan115Settings: ObservableObject, @unchecked Sendable {
    public static let shared = Pan115Settings()

    @Published public var cookie: String {
        didSet { UserDefaults.standard.set(Self.normalizeCookie(cookie), forKey: Keys.cookie) }
    }
    @Published public var folderCID: String {
        didSet { UserDefaults.standard.set(folderCID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.folderCID) }
    }

    private enum Keys {
        static let cookie = "xxxclub.115.cookie"
        static let folderCID = "xxxclub.115.folderCID"
    }

    private init() {
        cookie = UserDefaults.standard.string(forKey: Keys.cookie) ?? ""
        folderCID = UserDefaults.standard.string(forKey: Keys.folderCID) ?? ""
    }

    public var isConfigured: Bool {
        let c = Self.normalizeCookie(cookie)
        return c.contains("UID=") && c.contains("CID=") && c.contains("SEID=")
            && !folderCID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var missingHint: String {
        let c = Self.normalizeCookie(cookie)
        var miss: [String] = []
        if !c.contains("UID=") { miss.append("UID") }
        if !c.contains("CID=") { miss.append("Cookie 里的 CID") }
        if !c.contains("SEID=") { miss.append("SEID") }
        if folderCID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { miss.append("离线目录 CID") }
        if miss.isEmpty { return "" }
        return "请先在「我的 → 115 离线」填写：" + miss.joined(separator: "、")
    }

    public static func normalizeCookie(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s*;\\s*", with: "; ", options: .regularExpression)
            .replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func extractUID(from cookie: String) -> String? {
        let c = normalizeCookie(cookie)
        guard let r = try? NSRegularExpression(pattern: "(?:^|;\\s*)UID=(\\d+)", options: .caseInsensitive),
              let m = r.firstMatch(in: c, range: NSRange(c.startIndex..., in: c)),
              let range = Range(m.range(at: 1), in: c) else { return nil }
        return String(c[range])
    }
}

public final class Pan115Client: @unchecked Sendable {
    public static let shared = Pan115Client()

    /// 必须与播放器 UA 一致。Safari iPhone UA 换到的 CDN 链不需要再带 Cookie。
    static let safariUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        session = URLSession(configuration: config)
    }

    public struct OfflineTask {
        public let name: String
        public let status: Int
        public let percent: Double
        public let infoHash: String
        public let fileID: String
        public let dirID: String
        public let url: String

        public var isDone: Bool { status == 2 }
        public var isFailed: Bool { status == -1 }
        public var isRunning: Bool { status == 0 || status == 1 }
    }

    public struct FileItem: Identifiable {
        public let name: String
        public let pickCode: String
        public let fileID: String
        public let cid: String
        public let isDir: Bool
        public let size: Int64

        public var id: String { fileID.isEmpty ? pickCode : fileID }

        public var isVideo: Bool {
            let n = name.lowercased()
            return [".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".ts", ".m2ts", ".webm", ".m4v"].contains { n.hasSuffix($0) }
        }
    }

    public struct PlayStream {
        public let name: String
        public let url: String
        public let bandwidth: Int
    }

    public func addOfflineTask(url magnet: String, cookie: String, folderCID: String) async throws -> Pan115PushResult {
        let cookie = Pan115Settings.normalizeCookie(cookie)
        let folder = folderCID.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = magnet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { throw Pan115Error.emptyLink }
        guard cookie.contains("UID="), cookie.contains("CID="), cookie.contains("SEID=") else {
            throw Pan115Error.cookieInvalid
        }
        guard !folder.isEmpty else { throw Pan115Error.missingFolder }

        let uid = Pan115Settings.extractUID(from: cookie) ?? ""
        var sign = ""
        var time = "\(Int(Date().timeIntervalSince1970 * 1000))"
        if let s = try? await fetchSign(cookie: cookie) {
            sign = s.sign
            time = s.time
        }

        var parts = [
            "url=\(link.formEncoded)",
            "wp_path_id=\(folder.formEncoded)",
        ]
        if !uid.isEmpty { parts.append("uid=\(uid.formEncoded)") }
        if !sign.isEmpty {
            parts.append("sign=\(sign.formEncoded)")
            parts.append("time=\(time.formEncoded)")
        }
        var req = URLRequest(url: URL(string: "https://115.com/web/lixian/?ct=lixian&ac=add_task_url")!)
        req.httpMethod = "POST"
        req.httpBody = parts.joined(separator: "&").data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        appendCommonHeaders(&req, cookie: cookie)
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw Pan115Error.http(http.statusCode)
        }
        return parseResult(data)
    }

    public func listOfflineTasks(cookie: String, page: Int = 1) async throws -> [OfflineTask] {
        let url = URL(string: "https://115.com/web/lixian/?ct=lixian&ac=task_lists&page=\(page)")!
        var req = URLRequest(url: url)
        appendCommonHeaders(&req, cookie: cookie)
        let obj = try await json(for: req)
        let raw = (obj["tasks"] as? [[String: Any]])
            ?? ((obj["data"] as? [String: Any])?["tasks"] as? [[String: Any]])
            ?? []
        return raw.map { item in
            OfflineTask(
                name: (item["name"] as? String) ?? "",
                status: intValue(item["status"]),
                percent: doubleValue(item["percentDone"] ?? item["percent"]),
                infoHash: (item["info_hash"] as? String) ?? (item["hash"] as? String) ?? "",
                fileID: stringValue(item["file_id"] ?? item["delete_file_id"]),
                dirID: stringValue(item["wp_path_id"] ?? item["file_id"]),
                url: (item["url"] as? String) ?? ""
            )
        }
    }

    public func listFiles(cid: String, cookie: String, limit: Int = 200) async throws -> [FileItem] {
        let q = "aid=1&cid=\(cid.formEncoded)&o=user_ptime&asc=0&offset=0&show_dir=1&limit=\(limit)&natsort=1&format=json"
        let urls = [
            "https://proapi.115.com/android/2.0/ufile/files?\(q)",
            "https://webapi.115.com/files?\(q)",
        ]
        var lastError: Error = Pan115Error.fileNotFound
        for u in urls {
            guard let url = URL(string: u) else { continue }
            var req = URLRequest(url: url)
            appendCommonHeaders(&req, cookie: cookie)
            do {
                let obj = try await json(for: req)
                let files = extractFileList(obj)
                if boolState(obj["state"]) || !files.isEmpty { return files }
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// 按标题关键词在 115 全盘找视频。xxxclub 没有番号，用厂牌和日期片段匹配。
    public func findMatchedVideos(keyword: String, cookie: String, limit: Int = 40) async throws -> [FileItem] {
        var result: [FileItem] = []
        var lastError: Error = Pan115Error.fileNotFound
        for variant in searchKeywords(from: keyword) {
            let files: [FileItem]
            do {
                files = try await searchFiles(keyword: variant, cookie: cookie, limit: limit)
            } catch {
                lastError = error
                continue
            }
            let hits = files.filter { file in
                !file.isDir && file.isVideo && !file.pickCode.isEmpty && nameMatches(file.name, keyword: keyword)
            }
            let known = Set(result.map(\.id))
            result.append(contentsOf: hits.filter { !known.contains($0.id) })
        }
        guard !result.isEmpty else { throw lastError }
        return result.sorted { $0.size > $1.size }
    }

    public func searchFiles(keyword: String, cookie: String, limit: Int = 30) async throws -> [FileItem] {
        let encoded = keyword.trimmingCharacters(in: .whitespacesAndNewlines).formEncoded
        let urls = [
            "https://proapi.115.com/android/2.0/ufile/search?search_value=\(encoded)&limit=\(limit)&offset=0&type=4&format=json",
            "https://webapi.115.com/files/search?search_value=\(encoded)&limit=\(limit)&offset=0&type=4&format=json",
        ]
        var lastError: Error = Pan115Error.fileNotFound
        for u in urls {
            guard let url = URL(string: u) else { continue }
            var req = URLRequest(url: url)
            appendCommonHeaders(&req, cookie: cookie)
            do {
                let obj = try await json(for: req)
                let files = extractFileList(obj)
                if !files.isEmpty { return files }
                if boolState(obj["state"]) { return [] }
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// 优先转码 m3u8；没有子流时用 webapi download 换原文件直链。
    public func streamsForVideo(pickCode: String, cookie: String, filename: String) async throws -> [PlayStream] {
        let m3u8URL = URL(string: "https://115.com/api/video/m3u8/\(pickCode.formEncoded).m3u8")!
        var req = URLRequest(url: m3u8URL)
        appendCommonHeaders(&req, cookie: cookie)
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        if let (data, _) = try? await session.data(for: req),
           let text = String(data: data, encoding: .utf8),
           text.contains("#EXTM3U") {
            let parsed = parseMaster(text)
            if !parsed.isEmpty { return parsed }
            if text.contains("#EXTINF") {
                return [PlayStream(name: "原画", url: m3u8URL.absoluteString, bandwidth: 0)]
            }
        }
        if let direct = try? await downloadURL(pickCode: pickCode, cookie: cookie) {
            return [PlayStream(name: "原文件", url: direct.absoluteString, bandwidth: 0)]
        }
        throw Pan115Error.playURLNotFound
    }

    /// webapi download 会 302 到 CDN。用播放器同一 UA 跟随，拿到不带 Cookie 也能播的直链。
    private func downloadURL(pickCode: String, cookie: String) async throws -> URL {
        let url = URL(string: "https://webapi.115.com/files/download?pickcode=\(pickCode.formEncoded)")!
        var req = URLRequest(url: url)
        appendCommonHeaders(&req, cookie: cookie)
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse,
           let location = http.value(forHTTPHeaderField: "Location"),
           let direct = URL(string: location), direct.scheme?.hasPrefix("http") == true {
            return direct
        }
        let obj = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let fileURL = stringValue(obj["file_url"] ?? (obj["data"] as? [String: Any])?["file_url"])
        guard fileURL.hasPrefix("http"), let direct = URL(string: fileURL) else {
            throw Pan115Error.playURLNotFound
        }
        return direct
    }

    private func fetchSign(cookie: String) async throws -> (sign: String, time: String) {
        var req = URLRequest(url: URL(string: "https://115.com/?ct=offline&ac=space")!)
        appendCommonHeaders(&req, cookie: cookie)
        let (data, _) = try await session.data(for: req)
        struct SignResp: Decodable {
            let sign: String?
            let time: FlexibleValue?
        }
        let decoded = try JSONDecoder().decode(SignResp.self, from: data)
        guard let sign = decoded.sign, !sign.isEmpty else { throw Pan115Error.signFailed }
        return (sign, decoded.time?.stringValue ?? "\(Int(Date().timeIntervalSince1970 * 1000))")
    }

    private func json(for req: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw Pan115Error.http(http.statusCode)
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Pan115Error.api("接口返回不是 JSON")
        }
        return obj
    }

    private func parseResult(_ data: Data) -> Pan115PushResult {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            return .failed("接口无返回")
        }
        if text.lowercased().contains("<html") || text.contains("登录") {
            return .failed("Cookie 无效或已过期")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failed("接口返回不是 JSON")
        }
        let state = obj["state"]
        let ok = (state as? Bool) == true || (state as? Int) == 1 || (state as? String) == "1" || (state as? String) == "true"
        if ok { return .success }
        let msg = (obj["error_msg"] as? String) ?? (obj["error"] as? String) ?? (obj["msg"] as? String) ?? ""
        let errcode = intValue(obj["errcode"] ?? obj["errno"])
        if errcode == 10008 || msg.contains("已存在") || msg.contains("重复") { return .exists }
        return .failed(msg.isEmpty ? "添加失败" : msg)
    }

    static func playHeaders(cookie: String) -> [String: String] {
        [
            "User-Agent": safariUA,
            "Accept": "*/*",
            "Origin": "https://115.com",
            "Referer": "https://115.com/",
            "Cookie": Pan115Settings.normalizeCookie(cookie),
        ]
    }

    private func appendCommonHeaders(_ req: inout URLRequest, cookie: String) {
        let h = Self.playHeaders(cookie: cookie)
        for (key, value) in h {
            req.setValue(value, forHTTPHeaderField: key)
        }
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
    }

    private func searchKeywords(from raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var variants: [String] = []
        let code = trimmed.range(of: #"[A-Za-z]{2,12}-?\d{2,6}"#, options: .regularExpression).map { String(trimmed[$0]) }
        if let code { variants.append(code) }
        let words = trimmed.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 4 }
        if let studio = words.first(where: { $0.first?.isLetter == true && $0.count >= 4 }) {
            let nums = words.filter { $0.allSatisfy(\.isNumber) && $0.count >= 2 }
            if nums.count >= 3 {
                variants.append("\(studio) \(nums.prefix(3).joined(separator: " "))")
            }
            variants.append(studio)
        }
        if let first = words.first, !variants.contains(first) { variants.append(first) }
        return Array(NSOrderedSet(array: variants)) as? [String] ?? variants
    }

    private func nameMatches(_ filename: String, keyword: String) -> Bool {
        let name = normalized(filename)
        let key = normalized(keyword)
        if !key.isEmpty, name.contains(key) { return true }
        let words = keyword.split { !$0.isLetter && !$0.isNumber }.map { normalized(String($0)) }.filter { $0.count >= 4 }
        guard let studio = words.first else { return false }
        return name.contains(studio)
    }

    private func normalized(_ raw: String) -> String {
        raw.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func extractFileList(_ obj: [String: Any]) -> [FileItem] {
        var raw: [[String: Any]] = []
        func collect(_ value: Any?) {
            guard let value else { return }
            if let arr = value as? [[String: Any]] { raw = arr; return }
            if let dict = value as? [String: Any] {
                for key in ["data", "list", "files", "items"] {
                    if let arr = dict[key] as? [[String: Any]] { raw = arr; return }
                }
            }
        }
        collect(obj["data"])
        if raw.isEmpty { collect(obj) }
        return raw.compactMap { item in
            let name = (item["n"] as? String) ?? (item["fn"] as? String) ?? (item["name"] as? String) ?? (item["file_name"] as? String) ?? ""
            guard !name.isEmpty else { return nil }
            let pc = (item["pc"] as? String) ?? (item["pick_code"] as? String) ?? (item["pickcode"] as? String) ?? ""
            let fid = stringValue(item["fid"] ?? item["file_id"] ?? item["id"])
            let cid = stringValue(item["cid"] ?? item["pid"])
            let isDir = pc.isEmpty && item["sha"] == nil && item["sha1"] == nil
            return FileItem(
                name: name, pickCode: pc, fileID: fid,
                cid: cid.isEmpty ? fid : cid, isDir: isDir,
                size: Int64(doubleValue(item["s"] ?? item["fs"] ?? item["size"]))
            )
        }
    }

    private func parseMaster(_ text: String) -> [PlayStream] {
        let lines = text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
        var streams: [PlayStream] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.contains("#EXT-X-STREAM-INF"), i + 1 < lines.count {
                let height = Int(capture(line, #"RESOLUTION=\d+x(\d+)"#) ?? "") ?? 0
                let bw = Int(capture(line, #"BANDWIDTH=(\d+)"#) ?? "") ?? 0
                var u = lines[i + 1]
                if !u.hasPrefix("http"), let abs = URL(string: u, relativeTo: URL(string: "https://115.com/")) {
                    u = abs.absoluteString
                }
                if u.hasPrefix("http") {
                    let label = height > 0 ? "\(height)p" : "原画"
                    streams.append(PlayStream(name: label, url: u, bandwidth: bw + height * 1_000_000))
                }
            }
            i += 1
        }
        return streams.sorted { $0.bandwidth > $1.bandwidth }
    }

    private func capture(_ line: String, _ pattern: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: pattern),
              let m = r.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              m.numberOfRanges > 1,
              let range = Range(m.range(at: 1), in: line) else { return nil }
        return String(line[range])
    }

    private func boolState(_ value: Any?) -> Bool {
        (value as? Bool) == true || (value as? Int) == 1 || (value as? String) == "1" || (value as? String) == "true"
    }

    private func intValue(_ value: Any?) -> Int {
        if let i = value as? Int { return i }
        if let s = value as? String, let i = Int(s) { return i }
        if let d = value as? Double { return Int(d) }
        return 0
    }

    private func doubleValue(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String, let d = Double(s) { return d }
        return 0
    }

    private func stringValue(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let i = value as? Int { return "\(i)" }
        if let d = value as? Double { return String(Int(d)) }
        return ""
    }
}

public enum Pan115Error: Error, LocalizedError {
    case emptyLink
    case cookieInvalid
    case missingFolder
    case signFailed
    case http(Int)
    case timeout
    case taskFailed(String)
    case fileNotFound
    case playURLNotFound
    case api(String)

    public var errorDescription: String? {
        switch self {
        case .emptyLink: return "磁力链接为空"
        case .cookieInvalid: return "115 Cookie 无效或已过期，请重新填写 UID/CID/SEID"
        case .missingFolder: return "请先填写 115 离线目录 CID"
        case .signFailed: return "获取 115 签名失败"
        case .http(let code): return "115 接口 HTTP \(code)"
        case .timeout: return "等待 115 离线完成超时，可稍后在详情页再点播放"
        case .taskFailed(let msg): return "115 离线失败：\(msg)"
        case .fileNotFound: return "115 里还没找到这部视频"
        case .playURLNotFound: return "无法获取 115 播放地址"
        case .api(let msg): return msg
        }
    }
}

private struct FlexibleValue: Decodable {
    let stringValue: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { stringValue = "\(i)"; return }
        if let s = try? c.decode(String.self) { stringValue = s; return }
        stringValue = ""
    }
}

private extension String {
    var formEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
