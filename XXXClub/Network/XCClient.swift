//
//  XCClient.swift
//  XXXClub
//
//  用系统 URLSession 拉 HTML。站点对短词搜索会直接返回错误页。
//

import Foundation

enum XCError: LocalizedError {
    case badURL
    case http(Int)
    case empty
    case tooShort
    case message(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "地址无效"
        case .http(let code): return "站点返回 \(code)"
        case .empty: return "没有内容"
        case .tooShort: return "至少要有一个超过两个字母的词"
        case .message(let text): return text
        }
    }
}

final class XCClient {
    static let shared = XCClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    func get(_ path: String) async throws -> String {
        let raw = path.hasPrefix("http") ? path : Site.origin + (path.hasPrefix("/") ? path : "/" + path)
        guard let url = URL(string: raw) else { throw XCError.badURL }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue(Site.origin + "/", forHTTPHeaderField: "Referer")
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<400).contains(code) else { throw XCError.http(code) }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw XCError.empty
        }
        if html.contains("Your search is too short") {
            throw XCError.tooShort
        }
        if let alert = HTML.first(html, pattern: "<div class=['\\\"]alert['\\\"]>([\\s\\S]*?)</div>"),
           html.contains("Error") {
            let text = HTML.strip(alert)
            if text.count > 8, text.count < 240, !html.contains("torrents/details/") {
                throw XCError.message(text)
            }
        }
        return html
    }

    /// 首页轮播用浏览页推荐海报。站点首页轮播封面是脚本画的，HTML 里没有图。
    func home() async throws -> (trending: [XCTorrent], latest: [XCTorrent], updates: [String]) {
        async let homeHTML = get("/")
        async let browseHTML = get("/torrents/browse/all/")
        let home = try await homeHTML
        let browse = try await browseHTML
        var trending = XCParser.parseRecommend(browse)
        if trending.isEmpty {
            trending = Array(XCParser.parseRows(browse).prefix(8))
        }
        for index in trending.indices {
            trending[index].rank = index + 1
        }
        let latest = Array(XCParser.parseRows(browse).prefix(12))
        let updates = HTML.blocks(home, pattern: "<li>([\\s\\S]*?)</li>")
            .map { HTML.strip($0) }
            .filter { $0.count > 12 && !$0.contains("Category") }
            .prefix(6)
        return (trending, latest, Array(updates))
    }

    func browse(categoryID: String, cursor: String?) async throws -> (items: [XCTorrent], next: String?) {
        let cat = Site.category(id: categoryID) ?? Site.categories[0]
        var path = cat.path
        if let cursor, !cursor.isEmpty {
            path = cursor.hasPrefix("/") ? cursor : cat.path + cursor
        }
        let html = try await get(path)
        let page = XCParser.parsePage(html)
        return (page.items, page.next)
    }

    func search(query: String, categoryIDs: [String], cursor: String?) async throws -> (items: [XCTorrent], next: String?) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 3 else { throw XCError.tooShort }
        let path: String
        if let cursor, cursor.hasPrefix("/") {
            path = cursor
        } else {
            let cat: String
            if categoryIDs.isEmpty || categoryIDs.count >= Site.categories.count - 1 {
                cat = "all"
            } else {
                cat = categoryIDs.joined(separator: ",")
            }
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? q
            path = "/torrents/search/\(cat)/\(encoded)"
        }
        let html = try await get(path)
        return XCParser.parsePage(html)
    }

    func top10(categoryID: String?) async throws -> [XCTorrent] {
        let path = categoryID.map { "/torrents/topten/\($0)" } ?? "/torrents/topten/"
        return XCParser.parsePage(try await get(path)).items
    }

    func top100(categoryID: String?) async throws -> [XCTorrent] {
        let path = categoryID.map { "/torrents/top100/\($0)" } ?? "/torrents/top100/"
        return XCParser.parsePage(try await get(path)).items
    }

    func catalog() async throws -> [XCTorrent] {
        XCParser.parsePage(try await get("/torrents/catalog/")).items
    }

    func detail(id: String) async throws -> XCDetail {
        let html = try await get("/torrents/details/\(id)")
        guard let detail = XCParser.parseDetail(html, id: id) else { throw XCError.empty }
        return detail
    }

    private func unique(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
}
