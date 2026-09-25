//
//  HTML.swift
//  XXXClub
//
//  站点 HTML 很乱：引号单双混用，分页里藏了大量 left:-99999 的诱饵链接。
//

import Foundation

enum HTML {
    static func decode(_ raw: String) -> String {
        var s = raw
        let map = [
            "&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'",
            "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&#160;": " "
        ]
        for (k, v) in map { s = s.replacingOccurrences(of: k, with: v) }
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);") {
            let ns = s as NSString
            let matches = regex.matches(in: s, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let digits = ns.substring(with: m.range(at: 1))
                if let code = Int(digits), let scalar = UnicodeScalar(code) {
                    s = (s as NSString).replacingCharacters(in: m.range, with: String(scalar))
                }
            }
        }
        return s
    }

    static func strip(_ raw: String) -> String {
        let noTags = raw.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return decode(noTags)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func attr(_ tag: String, _ name: String) -> String? {
        let pattern = "\(name)\\s*=\\s*['\"]([^'\"]*)['\"]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = tag as NSString
        guard let m = regex.firstMatch(in: tag, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else {
            return nil
        }
        return decode(ns.substring(with: m.range(at: 1)))
    }

    static func blocks(_ html: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.range)
        }
    }

    static func first(_ html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let ns = html as NSString
        guard let m = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else {
            return nil
        }
        return ns.substring(with: m.range(at: 1))
    }

    static func abs(_ raw: String?) -> URL? {
        guard var raw, !raw.isEmpty else { return nil }
        raw = decode(raw)
        if raw.hasPrefix("//") { raw = "https:" + raw }
        if raw.hasPrefix("/") { raw = Site.origin + raw }
        return URL(string: raw)
    }

    static func int(_ raw: String) -> Int {
        Int(raw.filter(\.isNumber)) ?? 0
    }
}

enum XCParser {
    static func parsePage(_ html: String) -> (items: [XCTorrent], next: String?) {
        var items = parseRows(html)
        if items.isEmpty { items = parseTopCards(html) }
        if items.isEmpty { items = parseCatalog(html) }
        if items.isEmpty { items = parseRecommend(html) }
        return (items, nextPath(html))
    }

    /// 浏览 / 搜索 / Top100 的行。封面在 floaterimg，src 用单引号。
    static func parseRows(_ html: String) -> [XCTorrent] {
        let lis = HTML.blocks(html, pattern: "<li[\\s>][\\s\\S]*?</li>")
        var out: [XCTorrent] = []
        var seen = Set<String>()
        for li in lis {
            guard li.contains("torrents/details/") else { continue }
            guard let href = HTML.first(li, pattern: "href=['\\\"](/torrents/details/[^'\\\"]+)['\\\"]") else { continue }
            let id = href.split(separator: "/").last.map(String.init) ?? href
            guard seen.insert(id).inserted else { continue }
            let title = HTML.strip(HTML.first(li, pattern: "href=['\\\"]/torrents/details/[^'\\\"]+['\\\"][^>]*>([\\s\\S]*?)</a>") ?? "")
            guard !title.isEmpty, title != "Next Page" else { continue }
            let catID = (HTML.first(li, pattern: "href=['\\\"]/torrents/browse/(\\d+)/?['\\\"]") ?? "")
            let catName = HTML.strip(HTML.first(li, pattern: "class=['\\\"]catla['\\\"]>([\\s\\S]*?)</lab(?:el|le)>") ?? "")
            let cover = HTML.abs(HTML.first(li, pattern: "class=['\\\"]floaterimg['\\\"][^>]*src=['\\\"]([^'\\\"]+)['\\\"]"))
            let added = HTML.strip(HTML.first(li, pattern: "addedtable[^>]*>([\\s\\S]*?)</span>") ?? "")
            let size = HTML.strip(HTML.first(li, pattern: "class=['\\\"]siz[^'\\\"]*['\\\"][^>]*>([\\s\\S]*?)</span>") ?? "")
            let seeds = HTML.int(HTML.first(li, pattern: "class=['\\\"]see[^'\\\"]*['\\\"][^>]*>([\\s\\S]*?)</span>") ?? "")
            let leech = HTML.int(HTML.first(li, pattern: "class=['\\\"]lee[^'\\\"]*['\\\"][^>]*>([\\s\\S]*?)</span>") ?? "")
            let up = HTML.strip(HTML.first(li, pattern: "uploadertable[^>]*>([\\s\\S]*?)</span>") ?? "")
            out.append(XCTorrent(
                id: id, title: title, coverURL: cover,
                categoryID: catID, categoryName: catName,
                added: shortDate(added), size: size,
                seeders: seeds, leechers: leech, uploader: up, rank: nil
            ))
        }
        return out
    }

    static func parseRecommend(_ html: String) -> [XCTorrent] {
        let anchors = HTML.blocks(html, pattern: "<a href=['\\\"]/torrents/details/[^'\\\"]+['\\\"][\\s\\S]*?</a>")
        var out: [XCTorrent] = []
        var seen = Set<String>()
        for a in anchors where a.contains("img-thumbnail") || a.contains("Poster Of") {
            guard let href = HTML.first(a, pattern: "href=['\\\"](/torrents/details/[^'\\\"]+)['\\\"]") else { continue }
            let id = String(href.split(separator: "/").last ?? "")
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            let title = HTML.decode(HTML.attr(a, "title") ?? HTML.attr(a, "alt") ?? "")
                .replacingOccurrences(of: "Details Of ", with: "")
                .replacingOccurrences(of: "Poster Of ", with: "")
            let cover = HTML.abs(HTML.first(a, pattern: "src=['\\\"]([^'\\\"]+)['\\\"]"))
            out.append(XCTorrent(
                id: id, title: title, coverURL: cover,
                categoryID: "", categoryName: "", added: "", size: "",
                seeders: 0, leechers: 0, uploader: "", rank: nil
            ))
        }
        return out
    }

    static func parseCatalog(_ html: String) -> [XCTorrent] {
        let spans = HTML.blocks(html, pattern: "<span>[\\s\\S]*?catalogimg[\\s\\S]*?</span>")
        var out: [XCTorrent] = []
        for span in spans {
            guard let href = HTML.first(span, pattern: "href=['\\\"](/torrents/details/[^'\\\"]+)['\\\"]") else { continue }
            let id = String(href.split(separator: "/").last ?? "")
            let title = HTML.strip(HTML.first(span, pattern: "</img>\\s*([\\s\\S]*?)</a>")
                ?? HTML.first(span, pattern: ">([^<]{8,})</a>")
                ?? HTML.attr(span, "title")
                ?? "")
                .replacingOccurrences(of: "Details of ", with: "")
            let cover = HTML.abs(HTML.first(span, pattern: "src=['\\\"]([^'\\\"]+)['\\\"]"))
            guard !id.isEmpty else { continue }
            out.append(XCTorrent(
                id: id, title: title, coverURL: cover,
                categoryID: "3", categoryName: "Movies", added: "", size: "",
                seeders: 0, leechers: 0, uploader: "", rank: nil
            ))
        }
        return out
    }

    static func parseTopCards(_ html: String) -> [XCTorrent] {
        let cards = HTML.blocks(html, pattern: "<a href=['\\\"]/torrents/details/[^'\\\"]+['\\\"] class=['\\\"]file-card['\\\"][\\s\\S]*?</a>")
        return cards.enumerated().compactMap { index, card in
            guard let href = HTML.first(card, pattern: "href=['\\\"](/torrents/details/[^'\\\"]+)['\\\"]") else { return nil }
            let id = String(href.split(separator: "/").last ?? "")
            let title = HTML.strip(HTML.first(card, pattern: "class=['\\\"]title['\\\"]>([\\s\\S]*?)</h4>") ?? "")
            let cover = HTML.abs(HTML.first(card, pattern: "src=['\\\"]([^'\\\"]+)['\\\"]"))
            let up = HTML.strip(HTML.first(card, pattern: "class=['\\\"]uploader['\\\"]>([\\s\\S]*?)</p>") ?? "")
                .replacingOccurrences(of: "Uploader : ", with: "")
                .replacingOccurrences(of: "Uploader:", with: "")
            let date = HTML.strip(HTML.first(card, pattern: "class=['\\\"]date['\\\"]>([\\s\\S]*?)</p>") ?? "")
                .replacingOccurrences(of: "Added : ", with: "")
            let size = HTML.strip(HTML.first(card, pattern: "class=['\\\"]size['\\\"]>([\\s\\S]*?)</p>") ?? "")
                .replacingOccurrences(of: "Size : ", with: "")
            let seeds = HTML.int(HTML.first(card, pattern: "class=['\\\"]stat-item seeds['\\\"]>([\\s\\S]*?)</div>") ?? "")
            let leech = HTML.int(HTML.first(card, pattern: "class=['\\\"]stat-item leechers['\\\"]>([\\s\\S]*?)</div>") ?? "")
            let rank = HTML.int(HTML.first(card, pattern: "class=['\\\"]rank['\\\"]>([\\s\\S]*?)</div>") ?? "")
            return XCTorrent(
                id: id, title: title, coverURL: cover,
                categoryID: "", categoryName: "",
                added: date, size: size.trimmingCharacters(in: .whitespaces),
                seeders: seeds, leechers: leech, uploader: up.trimmingCharacters(in: .whitespaces),
                rank: rank > 0 ? rank : index + 1
            )
        }
    }

    static func parseDetail(_ html: String, id: String) -> XCDetail? {
        let title = HTML.strip(HTML.first(html, pattern: "<h1>([\\s\\S]*?)</h1>") ?? "")
        guard !title.isEmpty else { return nil }
        let cover = HTML.abs(HTML.first(html, pattern: "<img[^>]*class=['\\\"]detailsposter['\\\"][^>]*>")
            .flatMap { HTML.attr($0, "src") }
            ?? HTML.first(html, pattern: "src=['\\\"](https://imgxclub.com/(?:ps|p)/(?!xclogo)[^'\\\"]+)['\\\"]"))
        let catName = HTML.strip(HTML.first(html, pattern: "Category</span>[\\s\\S]*?<a[^>]*>([\\s\\S]*?)</a>") ?? "")
        let catID = HTML.first(html, pattern: "href=['\\\"]/torrents/browse/(\\d+)/?['\\\"]") ?? ""
        let size = field(html, "Size")
        let added = field(html, "Added Date")
        let scraped = field(html, "Last Scraped")
        let uploader = field(html, "Uploader")
        let downloads = HTML.int(field(html, "Downloads"))
        let peers = HTML.first(html, pattern: "Peers</span>[\\s\\S]*?</li>") ?? ""
        let seeds = HTML.int(HTML.first(peers, pattern: "class=['\\\"]see['\\\"]>(\\d+)") ?? "")
        let leech = HTML.int(HTML.first(peers, pattern: "class=['\\\"]lee['\\\"]>(\\d+)") ?? "")
        let magnet = HTML.decode(HTML.first(html, pattern: "href=['\\\"](magnet:\\?xt=urn:btih:[^'\\\"]+)['\\\"]") ?? "")
        let hash = HTML.first(magnet, pattern: "btih:([a-fA-F0-9]+)") ?? HTML.first(html, pattern: "/torrents/download/([a-fA-F0-9]+)") ?? ""
        let torrentPath = HTML.first(html, pattern: "href=['\\\"](/torrents/download/[a-fA-F0-9]+)['\\\"]") ?? ""
        let likes = HTML.int(HTML.first(html, pattern: "class=['\\\"]like['\\\"][\\s\\S]*?<span>(\\d+)</span>") ?? "0")
        let dislikes = HTML.int(HTML.first(html, pattern: "class=['\\\"]dislike['\\\"][\\s\\S]*?<span>(\\d+)</span>") ?? "0")
        let descRaw = HTML.first(html, pattern: "<div class=['\\\"]description['\\\"]>([\\s\\S]*?)</div>") ?? ""
        let description = cleanDescription(descRaw)
        let files = parseFiles(html)
        let shots = screenshotURLs(descRaw)
        let similar = parseSimilar(html)

        let torrent = XCTorrent(
            id: id, title: title, coverURL: cover,
            categoryID: catID, categoryName: catName,
            added: shortDate(added), size: size,
            seeders: seeds, leechers: leech, uploader: uploader, rank: nil
        )
        return XCDetail(
            torrent: torrent, infoHash: hash, magnet: magnet, torrentPath: torrentPath,
            downloads: downloads, likes: likes, dislikes: dislikes, lastScraped: scraped,
            descriptionText: description, files: files, screenshots: shots, similar: similar
        )
    }

    static func parseSimilar(_ html: String) -> [XCTorrent] {
        guard let block = HTML.first(html, pattern: "class=['\\\"]similardiv['\\\"][\\s\\S]*?(?=<div class=['\\\"]footer|$)") else { return [] }
        return parseRows(block)
    }

    static func parseFiles(_ html: String) -> [XCFile] {
        guard let table = HTML.first(html, pattern: "id=['\\\"]filestable['\\\"]>([\\s\\S]*?)</div>") else { return [] }
        let lis = HTML.blocks(table, pattern: "<li>[\\s\\S]*?</li>")
        return lis.compactMap { li in
            let spans = HTML.blocks(li, pattern: "<span>[\\s\\S]*?</span>")
            guard spans.count >= 2 else { return nil }
            let name = HTML.strip(spans[0])
            let size = HTML.strip(spans[1])
            guard !name.isEmpty, name != "Filename" else { return nil }
            return XCFile(name: name, size: size)
        }
    }

    static func field(_ html: String, _ label: String) -> String {
        let pattern = NSRegularExpression.escapedPattern(for: label) + "</span>\\s*<span>\\s*:\\s*</span>\\s*<span>([\\s\\S]*?)</span>"
        return HTML.strip(HTML.first(html, pattern: pattern) ?? "")
    }

    /// 可见的下一页。隐藏的 left:-99999 链接是反爬诱饵，不能跟。
    static func nextPath(_ html: String) -> String? {
        let anchors = HTML.blocks(html, pattern: "<a\\b[^>]*>\\s*Next Page\\s*</a>")
        for a in anchors {
            let style = HTML.attr(a, "style") ?? ""
            if style.contains("-99999") { continue }
            if let href = HTML.attr(a, "href"), href.contains("/") {
                return href
            }
        }
        return nil
    }

    static func shortDate(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count >= 11, s.contains(" ") {
            let parts = s.split(separator: " ")
            if parts.count >= 3 {
                return parts.prefix(3).joined(separator: " ")
            }
        }
        return s
    }

    static func cleanDescription(_ raw: String) -> String {
        var s = raw
        s = s.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "</b>", with: "", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "<b>", with: "", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "<img[^>]*>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "<a[^>]*>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "</a>", with: "")
        s = HTML.decode(s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func screenshotURLs(_ raw: String) -> [URL] {
        let tags = HTML.blocks(raw, pattern: "<img[^>]*>")
        var urls: [URL] = []
        for tag in tags {
            guard let src = HTML.attr(tag, "src"), let url = HTML.abs(src) else { continue }
            if url.absoluteString.contains("logo") { continue }
            urls.append(url)
        }
        return urls
    }
}
