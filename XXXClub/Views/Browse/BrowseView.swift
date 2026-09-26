//
//  BrowseView.swift
//  XXXClub
//
//  分类浏览。翻页只跟可见的 Next Page。
//  底部转圈如果没进入可视区，onAppear 不会触发，看起来就像一直在转。
//  所以有下一页就直接继续拉，直到没有新内容或没有下一页。
//

import SwiftUI

struct BrowseView: View {
    let categoryID: String
    @State private var items: [XCTorrent] = []
    @State private var next: String?
    @State private var loading = false
    @State private var error: String?
    @State private var started = false

    private var title: String {
        Site.category(id: categoryID)?.name ?? "浏览"
    }

    var body: some View {
        ScrollView {
            if items.isEmpty && loading {
                ProgressView().padding(.top, 48)
            }
            PosterGrid(items: items)
            if let error, items.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
            if next != nil || loading {
                ProgressView()
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
                    .onAppear { Task { await loadMore() } }
            }
        }
        .liquidGlassPage()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .nestedListChrome()
        .task {
            guard !started else { return }
            started = true
            await reload()
        }
        .refreshable { await reload() }
    }

    private func reload() async {
        items = []
        next = nil
        error = nil
        await loadMore()
    }

    private func loadMore() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        var cursor = next
        var pages = 0
        while pages < 4 {
            do {
                let page = try await XCClient.shared.browse(categoryID: categoryID, cursor: cursor)
                let known = Set(items.map(\.id))
                let fresh = page.items.filter { !known.contains($0.id) }
                if !fresh.isEmpty { items.append(contentsOf: fresh) }
                error = nil
                let samePage = page.next == cursor
                cursor = page.next
                next = cursor
                pages += 1
                if fresh.isEmpty || cursor == nil || samePage { break }
            } catch {
                self.error = error.localizedDescription
                next = nil
                break
            }
        }
    }
}
