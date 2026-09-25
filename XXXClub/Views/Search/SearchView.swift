//
//  SearchView.swift
//  XXXClub
//
//  站点要求至少一个词超过两个字符。
//  路径：/torrents/search/{分类索引或 all}/{关键词}
//

import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var selected: Set<String> = []
    @State private var items: [XCTorrent] = []
    @State private var next: String?
    @State private var loading = false
    @State private var error: String?
    @State private var didSearch = false

    private var filters: [XCCategory] {
        Site.categories.filter { $0.id != "all" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                field
                chips
                results
            }
            .padding(.top, 8)
        }
        .liquidGlassPage()
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var results: some View {
        if loading && items.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
        } else if let error, items.isEmpty {
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 32)
        } else if didSearch && items.isEmpty {
            Text("没有结果")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
        } else {
            PosterGrid(items: items)
            if next != nil {
                ProgressView().padding().onAppear { Task { await loadMore() } }
            }
        }
    }

    private var field: some View {
        HStack {
            TextField("片名 / 厂牌", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await reload() } }
            Button("搜索") { Task { await reload() } }
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .liquidGlassRect(cornerRadius: 14)
        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters) { cat in
                    let on = selected.contains(cat.id)
                    Button(cat.shortName) {
                        GlassHaptic.tap()
                        if on { selected.remove(cat.id) } else { selected.insert(cat.id) }
                    }
                    .font(.caption.weight(on ? .semibold : .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(on ? Color.white : Color.primary)
                    .background(on ? XCPalette.accent : Color(.systemGray6), in: Capsule())
                }
            }
            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
        }
    }

    private func reload() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 3 else {
            error = XCError.tooShort.localizedDescription
            items = []
            didSearch = true
            return
        }
        didSearch = true
        items = []
        next = nil
        await loadMore()
    }

    private func loadMore() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let page = try await XCClient.shared.search(
                query: query,
                categoryIDs: Array(selected).sorted(),
                cursor: next
            )
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
