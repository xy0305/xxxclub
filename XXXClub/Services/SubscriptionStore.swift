//
//  SubscriptionStore.swift
//  XXXClub
//
//  订阅厂牌。打开 App 或手动检查时搜最新，同一部只推画质最高的一版到 115。
//  同一部用「厂牌 + 日期」比较，4K > 1080p > 720p > 480p。
//

import Foundation
import Combine

struct Subscription: Identifiable, Codable, Hashable {
    var id: String { query }
    var query: String
    var createdAt: Date
}

struct SubscriptionLog: Identifiable, Codable {
    var id: String
    var title: String
    var query: String
    var message: String
    var date: Date
}

@MainActor
final class SubscriptionStore: ObservableObject {
    static let shared = SubscriptionStore()

    @Published private(set) var items: [Subscription] = []
    @Published private(set) var logs: [SubscriptionLog] = []
    @Published var checking = false
    @Published var lastStatus = ""

    private let key = "xxxclub.subscriptions"
    private let logKey = "xxxclub.subscription.logs"
    private let pushedKey = "xxxclub.subscription.pushed"
    private var pushed: Set<String> = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([Subscription].self, from: data) {
            items = saved
        }
        if let data = UserDefaults.standard.data(forKey: logKey),
           let saved = try? JSONDecoder().decode([SubscriptionLog].self, from: data) {
            logs = saved
        }
        pushed = Set(UserDefaults.standard.stringArray(forKey: pushedKey) ?? [])
    }

    func contains(_ query: String) -> Bool {
        let q = Self.normalize(query)
        return items.contains { $0.query.caseInsensitiveCompare(q) == .orderedSame }
    }

    func toggle(query: String) {
        let q = Self.normalize(query)
        guard q.count >= 3 else { return }
        if let index = items.firstIndex(where: { $0.query.caseInsensitiveCompare(q) == .orderedSame }) {
            items.remove(at: index)
        } else {
            items.insert(Subscription(query: q, createdAt: Date()), at: 0)
        }
        persist()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persist()
    }

    func checkNow() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        guard !items.isEmpty else {
            lastStatus = "还没有订阅"
            return
        }
        guard Pan115Settings.shared.isConfigured else {
            lastStatus = Pan115Settings.shared.missingHint
            return
        }
        var pushedCount = 0
        for sub in items {
            do {
                let page = try await XCClient.shared.search(query: sub.query, categoryIDs: [], cursor: nil)
                let picks = Self.bestOfEachWork(page.items, query: sub.query)
                    .filter { Self.isNew($0, since: sub.createdAt) }
                for item in picks where !pushed.contains(item.id) {
                    let detail = try await XCClient.shared.detail(id: item.id)
                    guard !detail.magnet.isEmpty else { continue }
                    let result = try await Pan115Client.shared.addOfflineTask(
                        url: detail.magnet,
                        cookie: Pan115Settings.shared.cookie,
                        folderCID: Pan115Settings.shared.folderCID
                    )
                    pushed.insert(item.id)
                    pushedCount += 1
                    addLog(id: item.id, title: item.title, query: sub.query, message: result.message)
                }
            } catch {
                addLog(id: UUID().uuidString, title: sub.query, query: sub.query, message: error.localizedDescription)
            }
        }
        UserDefaults.standard.set(Array(pushed), forKey: pushedKey)
        lastStatus = pushedCount == 0 ? "没有新的更新" : "已推送 \(pushedCount) 部"
    }

    /// 标题里的日期和实际上传日期对不上，不能用来判断是不是同一部。
    /// 同一部 = 厂牌 + 去掉日期和画质后的作品名。日期只用来判断是不是新发布。
    static func bestOfEachWork(_ items: [XCTorrent], query: String) -> [XCTorrent] {
        let needle = query.lowercased()
        var groups: [String: [XCTorrent]] = [:]
        for item in items {
            guard item.title.lowercased().contains(needle) else { continue }
            let key = workKey(item.title, query: query)
            groups[key, default: []].append(item)
        }
        return groups.values.compactMap { group in
            group.max { lhs, rhs in
                if qualityRank(lhs) != qualityRank(rhs) { return qualityRank(lhs) < qualityRank(rhs) }
                return addedDate(lhs.added) < addedDate(rhs.added)
            }
        }
    }

    static func workKey(_ title: String, query: String) -> String {
        var words = title.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let noise: Set<String> = [
            "xxx", "mp4", "mkv", "web", "dl", "p2p", "wrb", "nbq", "xc", "hd",
            "split", "scenes", "scene", "pack"
        ]
        words.removeAll { word in
            let lower = word.lowercased()
            if noise.contains(lower) { return true }
            if word.allSatisfy(\.isNumber) { return true }
            if ["480p", "720p", "1080p", "2160p", "4k"].contains(lower) { return true }
            return false
        }
        if let first = words.first, first.caseInsensitiveCompare(query) == .orderedSame {
            words.removeFirst()
        }
        let name = words.joined(separator: " ").lowercased()
        return query.lowercased() + "|" + (name.isEmpty ? title.lowercased() : name)
    }

    static func isNew(_ item: XCTorrent, since: Date) -> Bool {
        addedDate(item.added) >= Calendar.current.startOfDay(for: since)
    }

    static func qualityRank(_ item: XCTorrent) -> Int {
        let title = item.title.lowercased()
        let cat = (item.categoryID + " " + item.categoryName).lowercased()
        if title.contains("2160") || title.contains("4k") || cat.contains("4k") || item.categoryID == "4" { return 400 }
        if title.contains("1080") || cat.contains("1080") || item.categoryID == "2" { return 300 }
        if title.contains("720") || item.categoryID == "1" { return 200 }
        if title.contains("480") || cat.contains("sd") || item.categoryID == "0" { return 100 }
        return sizeBytes(item.size) > 0 ? 50 : 0
    }

    static func studioQuery(from title: String) -> String {
        let words = title.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return words.first { $0.first?.isLetter == true && $0.count >= 3 } ?? ""
    }

    private func addLog(id: String, title: String, query: String, message: String) {
        logs.insert(SubscriptionLog(id: id, title: title, query: query, message: message, date: Date()), at: 0)
        logs = Array(logs.prefix(40))
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: logKey)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func addedDate(_ raw: String) -> Date {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = ["dd MMM yyyy HH:mm:ss", "dd MMM yyyy", "d MMM yyyy"]
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            parser.dateFormat = format
            if let date = parser.date(from: trimmed) { return date }
        }
        return .distantPast
    }

    private static func sizeBytes(_ raw: String) -> Int64 {
        let lower = raw.lowercased()
        let number = Double(lower.filter { $0.isNumber || $0 == "." }) ?? 0
        if lower.contains("gb") { return Int64(number * 1_000_000_000) }
        if lower.contains("mb") { return Int64(number * 1_000_000) }
        return Int64(number)
    }
}
