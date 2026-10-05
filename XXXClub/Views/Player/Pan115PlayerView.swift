//
//  Pan115PlayerView.swift
//  AVDB
//
//  按番号全盘搜索 115 文件（对齐 Forward 模块 files/search），KSPlayer 播最高清晰度。
//

import SwiftUI
import KSPlayer

struct Pan115PlayerView: View {
    let movie: XCTorrent
    var magnetURL: String? = nil
    var manifest: [String] = []
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = Pan115PlayerViewModel()
    @State private var showEpisodes = false
    @State private var showQuality = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let url = vm.playURL, vm.errorMessage == nil, !vm.isLoading {
                KSChromePlayer(
                    url: url,
                    title: movie.title,
                    subtitle: vm.qualityLabel,
                    headers: vm.headers
                )
                .id(url.absoluteString)
            } else if let err = vm.errorMessage {
                ContentUnavailableView {
                    Label("无法播放", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(err)
                } actions: {
                    Button("重试") {
                        Task { await vm.start(movie: movie, magnetURL: magnetURL, manifest: manifest) }
                    }
                    Button("关闭") { dismiss() }
                }
                .foregroundStyle(.white)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                    Text(vm.status)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("取消") { dismiss() }
                        .foregroundStyle(.white)
                }
            }

            if vm.playURL != nil, vm.streams.count > 1 {
                Button(vm.qualityLabel + " ▾") { showQuality = true }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.leading, 60)
                    .padding(.top, 12)
            }

            if vm.episodes.count > 1 {
                HStack {
                    Spacer()
                    Button { showEpisodes = true } label: {
                        Image(systemName: "rectangle.stack.badge.play")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
                .padding(.trailing, 12)
            }

            if vm.playURL == nil || vm.errorMessage != nil {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.start(movie: movie, magnetURL: magnetURL, manifest: manifest) }
        .confirmationDialog("播放质量 / 源文件", isPresented: $showQuality) {
            ForEach(Array(vm.streams.enumerated()), id: \.offset) { _, stream in
                Button(stream.name) { vm.select(stream) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("原文件为下载直链；若编码不兼容或播放失败，请切换转码质量。切换将重新开始播放。")
        }
        .confirmationDialog("选择集数", isPresented: $showEpisodes) {
            ForEach(Array(vm.episodes.enumerated()), id: \.element.fileID) { index, file in
                Button(file.name) {
                    Task { await vm.selectEpisode(index) }
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    /// 4K、文件名含 -c（中文）、restored（破解）标在集数后面。
    private func episodeTitle(index: Int, name: String) -> String {
        let lower = name.lowercased()
        var marks: [String] = []
        if lower.contains("4k") || lower.contains("2160") { marks.append("4K") }
        if lower.range(of: #"(^|[^a-z0-9])-c([^a-z0-9]|$)"#, options: .regularExpression) != nil
            || lower.contains("-c.")
            || lower.contains("中字")
            || lower.contains("中文") {
            marks.append("-c")
        }
        if lower.contains("restored") { marks.append("restored") }
        let base = "第 \(index + 1) 集"
        return marks.isEmpty ? base : base + "  " + marks.joined(separator: " ")
    }
}

@MainActor
final class Pan115PlayerViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var status = "准备中…"
    @Published var errorMessage: String?
    @Published var fileName = ""
    @Published var episodes: [Pan115Client.FileItem] = []
    @Published var playURL: URL?
    @Published var streams: [Pan115Client.PlayStream] = []
    @Published var qualityLabel = "原画"

    var headers: [String: String] {
        guard let url = playURL else { return [:] }
        return Pan115PlaybackRouting.headers(url: url,
            common: Pan115Client.playHeaders(cookie: Pan115Settings.shared.cookie))
    }

    func start(movie: XCTorrent, magnetURL: String?, manifest: [String]) async {
        let settings = Pan115Settings.shared
        guard settings.isConfigured else {
            errorMessage = settings.missingHint
            return
        }
        isLoading = true
        errorMessage = nil
        playURL = nil
        streams = []
        episodes = []
        defer { isLoading = false }

        let cookie = settings.cookie
        let cid = settings.folderCID
        let keyword = movie.title
        let magnet = magnetURL ?? ""
        let hash = Pan115Identity.hash(magnet)

        do {
            status = "正在 115 中搜索 \(keyword)…"
            let existing: [Pan115Client.FileItem]
            do {
                existing = try await verify(keyword: keyword, infoHash: hash, cookie: cookie,
                    folderCID: cid, manifest: manifest)
            } catch Pan115Error.fileNotFound { existing = [] }
            if !existing.isEmpty {
                episodes = existing
                guard existing.count == 1, mayAutoplay(existing[0], keyword: keyword, manifest: manifest) else {
                    throw Pan115Error.api("候选文件尚未唯一确认身份，请关闭提示后手动选择文件；不会自动播放")
                }
                try await play(file: existing[0], cookie: cookie)
                return
            }

            if hash.isEmpty {
                throw Pan115Error.fileNotFound
            }

            status = "正在推送到 115 离线…"
            let result = try await Pan115Client.shared.addOfflineTask(
                url: magnet, cookie: cookie, folderCID: cid)
            Pan115PlaybackCache.save(movieID: movie.id, magnet: magnet)
            switch result {
            case .failed(let msg):
                throw Pan115Error.api(msg)
            case .exists:
                status = "任务已存在，正在打开已下载文件…"
            case .success:
                status = "已推送，等待离线完成…"
            }

            let files = try await waitUntilPlayable(
                keyword: keyword, infoHash: hash, cookie: cookie, folderCID: cid, manifest: manifest,
                timeout: result == .exists ? 60 : 180)
            episodes = files
            guard files.count == 1, mayAutoplay(files[0], keyword: keyword, manifest: manifest) else {
                throw Pan115Error.api("候选文件尚未唯一确认身份，请手动选择文件；不会自动播放")
            }
            try await play(file: files[0], cookie: cookie)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ stream: Pan115Client.PlayStream) {
        qualityLabel = stream.name
        playURL = URL(string: stream.url)
    }

    func selectEpisode(_ index: Int) async {
        guard episodes.indices.contains(index) else { return }
        isLoading = true
        errorMessage = nil
        playURL = nil
        do {
            try await play(file: episodes[index], cookie: Pan115Settings.shared.cookie)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Total verification budget includes network requests, not just polling sleeps.
    private func verify(
        keyword: String, infoHash: String, cookie: String, folderCID: String,
        manifest: [String], timeout: TimeInterval = 35
    ) async throws -> [Pan115Client.FileItem] {
        try await withThrowingTaskGroup(of: [Pan115Client.FileItem].self) { group in
            group.addTask {
                try await Pan115Client.shared.findPlayable(keyword: keyword, infoHash: infoHash,
                    cookie: cookie, folderCID: folderCID, manifest: manifest)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw Pan115Error.timeout
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw Pan115Error.fileNotFound }
            return result
        }
    }

    private func mayAutoplay(_ file: Pan115Client.FileItem, keyword: String, manifest: [String]) -> Bool {
        // Non studio/date results have already passed the strict hash/name fallback.
        !Pan115Identity.studioDateCandidate(file.name, title: keyword)
            || Pan115Identity.safeStudioHit(file.name, title: keyword, manifest: manifest)
    }

    private func waitUntilPlayable(
        keyword: String, infoHash: String, cookie: String, folderCID: String,
        manifest: [String], timeout: TimeInterval
    ) async throws -> [Pan115Client.FileItem] {
        guard !Pan115Identity.hash(infoHash).isEmpty else { throw Pan115Error.fileNotFound }
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            do {
                let remaining = timeout - Date().timeIntervalSince(start)
                let files = try await verify(keyword: keyword, infoHash: infoHash, cookie: cookie,
                    folderCID: folderCID, manifest: manifest, timeout: min(35, remaining))
                if !files.isEmpty { return files }
            } catch Pan115Error.fileNotFound { }
            if Date().timeIntervalSince(start) >= timeout { throw Pan115Error.timeout }
            let remaining = max(0, Int(timeout - Date().timeIntervalSince(start)))
            status = "正在按厂牌发行日期及文件身份核对（剩余 \(remaining) 秒）…"
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        throw Pan115Error.timeout
    }

    private func play(file: Pan115Client.FileItem, cookie: String) async throws {
        fileName = file.name
        status = "获取 115 播放地址…"
        let list = try await Pan115Client.shared.streamsForVideo(
            pickCode: file.pickCode, cookie: cookie, filename: file.name)
        streams = list
        guard let best = list.first, let url = URL(string: best.url) else {
            throw Pan115Error.playURLNotFound
        }
        qualityLabel = best.name
        playURL = url
    }
}

enum Pan115PlaybackCache {
    private static func key(_ movieID: String) -> String { "avdb.115.lastMagnet.\(movieID)" }

    static func save(movieID: String, magnet: String) {
        UserDefaults.standard.set(magnet, forKey: key(movieID))
    }

    static func magnet(for movieID: String) -> String? {
        UserDefaults.standard.string(forKey: key(movieID))
    }

    static func hasMagnet(_ id: String) -> Bool {
        !(magnet(for: id) ?? "").isEmpty
    }
}
