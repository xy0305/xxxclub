//
//  DetailView.swift
//  XXXClub
//
//  种子详情。没有在线播放，主动作是复制磁力。
//

import SwiftUI

struct DetailView: View {
    let id: String
    var preview: XCTorrent?
    @State private var detail: XCDetail?
    @State private var error: String?
    @State private var copied = false
    @State private var showFiles = false
    @StateObject private var library = LibraryStore.shared
    @Environment(\.openURL) private var openURL

    private var torrent: XCTorrent? { detail?.torrent ?? preview }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                actions
                facts
                if let detail, !detail.files.isEmpty { files(detail) }
                if let text = detail?.descriptionText, !text.isEmpty { description(text) }
                if let shots = detail?.screenshots, !shots.isEmpty { shotsRow(shots) }
                if let error, detail == nil {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: AdaptiveLayout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .liquidGlassPage()
        .navigationTitle(torrent?.categoryName.isEmpty == false ? torrent!.categoryName : "详情")
        .navigationBarTitleDisplayMode(.inline)
        .nestedListChrome()
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            PosterImage(url: torrent?.coverURL)
                .frame(width: 132, height: 198)
                .glassMediaFrame(cornerRadius: 14)
            VStack(alignment: .leading, spacing: 8) {
                Text(torrent?.title ?? "加载中")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let t = torrent {
                    metaLine(t)
                }
                if detail == nil && error == nil {
                    ProgressView().padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
    }

    private func metaLine(_ t: XCTorrent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !t.size.isEmpty {
                Text(t.size).font(.subheadline.weight(.semibold))
            }
            HStack(spacing: 8) {
                if t.seeders > 0 {
                    Label("\(t.seeders)", systemImage: "arrow.up.circle.fill")
                        .foregroundStyle(XCPalette.seed)
                }
                if t.leechers > 0 {
                    Label("\(t.leechers)", systemImage: "arrow.down.circle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption.weight(.medium))
            if !t.added.isEmpty {
                Text(t.added).font(.caption).foregroundStyle(.secondary)
            }
            if !t.uploader.isEmpty {
                Text(t.uploader).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                copyMagnet()
            } label: {
                Label(copied ? "已复制" : "复制磁力", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .xcGlassButton(prominent: true)
            .disabled(detail?.magnet.isEmpty != false)

            Button {
                openMagnet()
            } label: {
                Label("打开", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .xcGlassButton()
            .disabled(detail?.magnet.isEmpty != false)

            Button {
                if let torrent { library.toggle(torrent) }
                GlassHaptic.tap()
            } label: {
                Image(systemName: library.contains(id) ? "heart.fill" : "heart")
                    .frame(width: 28)
            }
            .xcGlassButton()
            .disabled(torrent == nil)
        }
        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
    }

    @ViewBuilder
    private var facts: some View {
        if let detail {
            VStack(spacing: 0) {
                fact("分类", detail.torrent.categoryName)
                fact("大小", detail.torrent.size)
                fact("添加", detail.torrent.added)
                fact("下载", detail.downloads > 0 ? "\(detail.downloads)" : "")
                fact("做种 / 下载", "\(detail.torrent.seeders) / \(detail.torrent.leechers)")
                fact("评分", "\(detail.likes) 赞 · \(detail.dislikes) 踩")
                if !detail.infoHash.isEmpty {
                    fact("Hash", String(detail.infoHash.prefix(16)) + "…")
                }
            }
            .liquidGlassRect(cornerRadius: 16)
            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
        }
    }

    private func fact(_ name: String, _ value: String) -> some View {
        Group {
            if !value.isEmpty {
                HStack {
                    Text(name).foregroundStyle(.secondary)
                    Spacer()
                    Text(value).multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private func files(_ detail: XCDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showFiles.toggle() }
            } label: {
                HStack {
                    Text("文件 \(detail.files.count)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: showFiles ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            if showFiles {
                ForEach(detail.files) { file in
                    HStack {
                        Image(systemName: file.isVideo ? "film" : "doc")
                            .foregroundStyle(file.isVideo ? XCPalette.accent : .secondary)
                        Text(file.name).lineLimit(1)
                        Spacer()
                        Text(file.size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(14)
        .liquidGlassRect(cornerRadius: 16)
        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
    }

    private func description(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassRect(cornerRadius: 16)
        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
    }

    private func shotsRow(_ urls: [URL]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("截图")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(urls, id: \.absoluteString) { url in
                        PosterImage(url: url)
                            .frame(width: 140, height: 90)
                            .glassMediaFrame(cornerRadius: 10)
                    }
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
            }
        }
    }

    private func load() async {
        do {
            detail = try await XCClient.shared.detail(id: id)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func copyMagnet() {
        guard let magnet = detail?.magnet, !magnet.isEmpty else { return }
        UIPasteboard.general.string = magnet
        GlassHaptic.success()
        copied = true
    }

    private func openMagnet() {
        guard let magnet = detail?.magnet, let url = URL(string: magnet) else { return }
        openURL(url)
    }
}
