//
//  Site.swift
//  XXXClub
//
//  站点常量与分类。XXXClub 是种子站，没有在线播放。
//

import Foundation

enum Site {
    static let origin = "https://xxxclub.to"
    static let displayName = "XXXClub"

    static let categories: [XCCategory] = [
        .init(id: "all", name: "全部", shortName: "全部", icon: "square.grid.2x2", path: "/torrents/browse/all/"),
        .init(id: "0", name: "480p/SD", shortName: "SD", icon: "video", path: "/torrents/browse/0/"),
        .init(id: "1", name: "720p/HD", shortName: "720p", icon: "video.fill", path: "/torrents/browse/1/"),
        .init(id: "2", name: "1080p/FullHD", shortName: "1080p", icon: "tv", path: "/torrents/browse/2/"),
        .init(id: "4", name: "2160p/4K", shortName: "4K", icon: "sparkles", path: "/torrents/browse/4/"),
        .init(id: "3", name: "Movies/DVD/WEB", shortName: "Movies", icon: "film", path: "/torrents/browse/3/"),
        .init(id: "5", name: "IMAGESET", shortName: "图集", icon: "photo.on.rectangle", path: "/torrents/browse/5/"),
        .init(id: "6", name: "VR", shortName: "VR", icon: "view.3d", path: "/torrents/browse/6/"),
        .init(id: "7", name: "Pack", shortName: "合集", icon: "square.stack.3d.up", path: "/torrents/browse/7/")
    ]

    static func category(id: String) -> XCCategory? {
        categories.first { $0.id == id }
    }
}

struct XCCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let icon: String
    let path: String
}

struct XCTorrent: Identifiable, Hashable {
    var id: String
    var title: String
    var coverURL: URL?
    var categoryID: String
    var categoryName: String
    var added: String
    var size: String
    var seeders: Int
    var leechers: Int
    var uploader: String
    var rank: Int?

    var detailPath: String { "/torrents/details/\(id)" }

    var subtitle: String {
        [size, added.isEmpty ? nil : added, seeders > 0 ? "S \(seeders)" : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

struct XCFile: Identifiable, Hashable {
    var id: String { name + size }
    var name: String
    var size: String
    var isVideo: Bool {
        let lower = name.lowercased()
        return lower.hasSuffix(".mp4") || lower.hasSuffix(".mkv") || lower.hasSuffix(".avi") || lower.hasSuffix(".wmv")
    }
}

struct XCDetail {
    var torrent: XCTorrent
    var infoHash: String
    var magnet: String
    var torrentPath: String
    var downloads: Int
    var likes: Int
    var dislikes: Int
    var lastScraped: String
    var descriptionText: String
    var files: [XCFile]
    var screenshots: [URL]

    var torrentURL: URL? {
        URL(string: Site.origin + torrentPath)
    }
}

enum XCFeed: Hashable {
    case browse(categoryID: String)
    case search(query: String, categoryIDs: [String])
    case top10(categoryID: String?)
    case top100(categoryID: String?)
    case catalog

    var title: String {
        switch self {
        case .browse(let id):
            return Site.category(id: id)?.name ?? "浏览"
        case .search(let q, _):
            return q.isEmpty ? "搜索" : q
        case .top10:
            return "Top 10"
        case .top100:
            return "Top 100"
        case .catalog:
            return "Catalog"
        }
    }
}
