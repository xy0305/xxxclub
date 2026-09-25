//
//  BrowseView.swift
//  XXXClub
//
//  分类浏览。翻页只跟可见的 Next Page。
//

import SwiftUI

struct BrowseView: View {
    let categoryID: String
    @State private var items: [XCTorrent] = []
    @State private var next: String?
    @State private var loading = false
    @State private var error: String?

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
            if next != nil {
                ProgressView()
                    .padding()
                    .onAppear { Task { await loadMore() } }
            }
        }
        .liquidGlassPage()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .nestedListChrome()
        .task { if items.isEmpty { await reload() } }
        .refreshable { await reload() }
    }

    private func reload() async {
        items = []
        next = nil
        await loadMore()
    }

    private func loadMore() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let page = try await XCClient.shared.browse(categoryID: categoryID, cursor: next)
            let known = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !known.contains($0.id) })
            next = page.next
            error = nil
        } catch {
            self.error = error.localizedDescription
            next = nil
        }
    }
}
