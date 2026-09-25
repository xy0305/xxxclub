//
//  MineView.swift
//  XXXClub
//
//  收藏只存在本机。
//

import SwiftUI

struct MineView: View {
    @StateObject private var library = LibraryStore.shared
    @StateObject private var subs = SubscriptionStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section("115") {
                    NavigationLink {
                        Pan115SettingsView()
                    } label: {
                        LabeledContent("离线播放") {
                            Text(Pan115Settings.shared.isConfigured ? "已设置" : "未设置")
                                .foregroundStyle(Pan115Settings.shared.isConfigured ? .green : .secondary)
                        }
                    }
                }
                Section("订阅") {
                    NavigationLink {
                        SubscriptionsView()
                    } label: {
                        LabeledContent("厂牌订阅") {
                            Text(subs.items.isEmpty ? "未订阅" : "\(subs.items.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("收藏") {
                    if library.saved.isEmpty {
                        Text("在详情页点收藏。磁力存在本机，不上传。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(library.saved) { item in
                            NavigationLink {
                                DetailView(id: item.id, preview: item)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).lineLimit(2)
                                    Text(item.size).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: library.remove)
                    }
                }
                Section("关于") {
                    LabeledContent("站点", value: "xxxclub.to")
                    LabeledContent("备用", value: "xxxclub.me")
                    Text("这是种子索引。点播放会推到 115 离线，完成后在 App 里播。也可以复制磁力交给外部下载器。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .liquidGlassPage()
            .navigationTitle("我的")
        }
    }
}

@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()
    @Published var saved: [XCTorrent] = []
    private let key = "xxxclub.saved"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([SavedTorrent].self, from: data) else { return }
        saved = items.map(\.torrent)
    }

    func toggle(_ torrent: XCTorrent) {
        if let index = saved.firstIndex(where: { $0.id == torrent.id }) {
            saved.remove(at: index)
        } else {
            saved.insert(torrent, at: 0)
        }
        persist()
    }

    func contains(_ id: String) -> Bool {
        saved.contains { $0.id == id }
    }

    func remove(at offsets: IndexSet) {
        saved.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        let items = saved.map(SavedTorrent.init)
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

private struct SavedTorrent: Codable {
    var id: String
    var title: String
    var cover: String
    var categoryID: String
    var categoryName: String
    var added: String
    var size: String
    var seeders: Int
    var leechers: Int
    var uploader: String

    init(_ t: XCTorrent) {
        id = t.id
        title = t.title
        cover = t.coverURL?.absoluteString ?? ""
        categoryID = t.categoryID
        categoryName = t.categoryName
        added = t.added
        size = t.size
        seeders = t.seeders
        leechers = t.leechers
        uploader = t.uploader
    }

    var torrent: XCTorrent {
        XCTorrent(
            id: id, title: title, coverURL: URL(string: cover),
            categoryID: categoryID, categoryName: categoryName,
            added: added, size: size, seeders: seeders, leechers: leechers,
            uploader: uploader, rank: nil
        )
    }
}
