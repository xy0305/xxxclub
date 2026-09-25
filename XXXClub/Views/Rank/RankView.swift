//
//  RankView.swift
//  XXXClub
//
//  Top 10 是海报卡片，Top 100 是带封面的列表，Catalog 是电影海报墙。
//

import SwiftUI

enum RankKind {
    case top10, top100
    var title: String { self == .top10 ? "Top 10" : "Top 100" }
}

struct RankView: View {
    let kind: RankKind
    @State private var categoryID: String = "all"
    @State private var items: [XCTorrent] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                chips
                if loading && items.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if let error {
                    Text(error).font(.caption).foregroundStyle(.secondary).padding()
                } else {
                    PosterGrid(items: ranked)
                }
            }
            .padding(.vertical, 8)
        }
        .liquidGlassPage()
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .nestedListChrome()
        .task(id: categoryID) { await load() }
        .refreshable { await load() }
    }

    private var ranked: [XCTorrent] {
        items.enumerated().map { index, item in
            var copy = item
            if copy.rank == nil { copy.rank = index + 1 }
            return copy
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Site.categories) { cat in
                    let on = categoryID == cat.id
                    Button(cat.shortName) {
                        GlassHaptic.tap()
                        categoryID = cat.id
                    }
                    .font(.caption.weight(on ? .semibold : .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(on ? Color.white : Color.primary)
                    .background(on ? XCPalette.pink : Color(.systemGray6), in: Capsule())
                }
            }
            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let id = categoryID == "all" ? nil : categoryID
            items = kind == .top10
                ? try await XCClient.shared.top10(categoryID: id)
                : try await XCClient.shared.top100(categoryID: id)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CatalogView: View {
    @State private var items: [XCTorrent] = []
    @State private var error: String?

    var body: some View {
        ScrollView {
            if items.isEmpty && error == nil {
                ProgressView().padding(.top, 48)
            }
            PosterGrid(items: items)
            if let error {
                Text(error).font(.caption).foregroundStyle(.secondary).padding()
            }
        }
        .liquidGlassPage()
        .navigationTitle("Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .nestedListChrome()
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            items = try await XCClient.shared.catalog()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
