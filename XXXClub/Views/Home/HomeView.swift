//
//  HomeView.swift
//  XXXClub
//
//  首页对齐 AVDB：搜索条、快捷入口、推荐轮播、最新海报。
//

import SwiftUI

struct HomeView: View {
    @State private var trending: [XCTorrent] = []
    @State private var latest: [XCTorrent] = []
    @State private var updates: [String] = []
    @State private var error: String?
    @State private var goSearch = false
    @State private var browseID = "all"
    @State private var goBrowse = false
    @State private var goTop10 = false
    @State private var goTop100 = false
    @State private var goCatalog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    searchBar
                    shortcutRow
                    trendingSection
                    latestSection
                    if !updates.isEmpty { updatesSection }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: AdaptiveLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .liquidGlassPage()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await load() }
            .task { if trending.isEmpty { await load() } }
            .navigationDestination(isPresented: $goSearch) { SearchView() }
            .navigationDestination(isPresented: $goBrowse) { BrowseView(categoryID: browseID) }
            .navigationDestination(isPresented: $goTop10) { RankView(kind: .top10) }
            .navigationDestination(isPresented: $goTop100) { RankView(kind: .top100) }
            .navigationDestination(isPresented: $goCatalog) { CatalogView() }
        }
    }

    private var searchBar: some View {
        Button {
            GlassHaptic.tap()
            goSearch = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("搜索片名 / 厂牌")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .liquidGlassRect(cornerRadius: 14)
        }
        .pressableGlass()
        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
        .padding(.top, 8)
    }

    private var shortcutRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LiquidGlassContainer(spacing: 12) {
                HStack(spacing: 12) {
                    shortcut("最新", "clock.fill", .blue) { openBrowse("all") }
                    shortcut("Top 10", "flame.fill", XCPalette.pink) { goTop10 = true }
                    shortcut("Top 100", "trophy.fill", .orange) { goTop100 = true }
                    shortcut("Catalog", "film.fill", .purple) { goCatalog = true }
                    shortcut("1080p", "tv.fill", .teal) { openBrowse("2") }
                    shortcut("4K", "sparkles", .indigo) { openBrowse("4") }
                }
            }
            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
        }
    }

    private func openBrowse(_ id: String) {
        browseID = id
        goBrowse = true
    }

    private func shortcut(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button {
            GlassHaptic.tap()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 56, height: 56)
                    .liquidGlassCircle(tint: color.opacity(0.22))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: 72)
        }
        .pressableGlass()
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderBar(title: "推荐", trailing: "Top 10") { goTop10 = true }
            if trending.isEmpty {
                loading("正在加载推荐…")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(trending) { item in
                            NavigationLink {
                                DetailView(id: item.id, preview: item)
                            } label: {
                                PosterCard(torrent: item)
                                    .frame(width: AdaptiveLayout.isPad ? 180 : 140)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                }
            }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
            }
        }
    }

    private var latestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderBar(title: "最新", trailing: "全部") { goBrowse = true }
            if latest.isEmpty {
                loading("正在加载最新…")
            } else {
                PosterGrid(items: Array(latest.prefix(9)))
            }
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderBar(title: "站点更新", trailing: nil)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(updates, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassRect(cornerRadius: 16)
            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
        }
    }

    private func loading(_ text: String) -> some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func load() async {
        do {
            let page = try await XCClient.shared.home()
            trending = page.trending
            latest = page.latest
            updates = page.updates
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
