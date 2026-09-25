//
//  Pan115PlayerView.swift
//  XXXClub
//
//  先在 115 里按标题找已完成的文件。找不到就推磁力，等离线完成再播。
//  用系统 AVPlayer，请求头和换链 UA 保持一致。
//

import SwiftUI
import AVKit

struct Pan115PlayerView: View {
    let torrentID: String
    let title: String
    let magnet: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = Pan115PlayerViewModel()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let player = vm.player, vm.errorMessage == nil {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else if let err = vm.errorMessage {
                ContentUnavailableView {
                    Label("无法播放", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(err)
                } actions: {
                    Button("重试") { Task { await vm.start(id: torrentID, title: title, magnet: magnet) } }
                    Button("关闭") { dismiss() }
                }
                .foregroundStyle(.white)
            } else {
                VStack(spacing: 16) {
                    ProgressView().tint(.white)
                    Text(vm.status)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("取消") { dismiss() }
                        .foregroundStyle(.white)
                }
            }

            if vm.player == nil || vm.errorMessage != nil {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .padding(.leading, 16)
                .padding(.top, 12)
            }
        }
        .task { await vm.start(id: torrentID, title: title, magnet: magnet) }
        .onDisappear { vm.stop() }
    }
}

@MainActor
final class Pan115PlayerViewModel: ObservableObject {
    @Published var status = "准备中…"
    @Published var errorMessage: String?
    @Published var player: AVPlayer?

    func start(id: String, title: String, magnet: String) async {
        let settings = Pan115Settings.shared
        guard settings.isConfigured else {
            errorMessage = settings.missingHint
            return
        }
        errorMessage = nil
        player = nil
        let cookie = settings.cookie
        let cid = settings.folderCID
        let saved = Pan115PlaybackCache.magnet(for: id)
        let link = magnet.isEmpty ? (saved ?? "") : magnet

        do {
            status = "正在 115 中查找…"
            if let file = try? await firstPlayable(keyword: title, cookie: cookie) {
                try await play(file: file, cookie: cookie)
                return
            }
            guard !link.isEmpty else { throw Pan115Error.fileNotFound }

            status = "正在推送到 115 离线…"
            let result = try await Pan115Client.shared.addOfflineTask(url: link, cookie: cookie, folderCID: cid)
            Pan115PlaybackCache.save(id: id, magnet: link)
            switch result {
            case .failed(let msg): throw Pan115Error.api(msg)
            case .exists: status = "任务已存在，等待完成…"
            case .success: status = "已推送，等待离线完成…"
            }
            let file = try await waitUntilPlayable(keyword: title, cookie: cookie, timeout: result == .exists ? 45 : 180)
            try await play(file: file, cookie: cookie)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        player?.pause()
        player = nil
    }

    private func waitUntilPlayable(keyword: String, cookie: String, timeout: TimeInterval) async throws -> Pan115Client.FileItem {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let file = try? await firstPlayable(keyword: keyword, cookie: cookie) {
                return file
            }
            let tasks = (try? await Pan115Client.shared.listOfflineTasks(cookie: cookie)) ?? []
            if let hit = tasks.first(where: { task in
                task.name.localizedCaseInsensitiveContains(keyword)
                    || keyword.localizedCaseInsensitiveContains(task.name)
                    || (!task.infoHash.isEmpty && keyword.localizedCaseInsensitiveContains(task.infoHash))
            }) {
                if hit.isFailed { throw Pan115Error.taskFailed(hit.name) }
                if hit.isRunning { status = "离线中 \(Int(hit.percent))%…" }
            } else {
                status = "任务已完成，正在匹配文件…"
            }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        throw Pan115Error.timeout
    }

    private func firstPlayable(keyword: String, cookie: String) async throws -> Pan115Client.FileItem {
        let files = try await Pan115Client.shared.findMatchedVideos(keyword: keyword, cookie: cookie)
        guard let file = files.first else { throw Pan115Error.fileNotFound }
        return file
    }

    private func play(file: Pan115Client.FileItem, cookie: String) async throws {
        status = "获取播放地址…"
        let streams = try await Pan115Client.shared.streamsForVideo(
            pickCode: file.pickCode, cookie: cookie, filename: file.name)
        guard let best = streams.first, let url = URL(string: best.url) else {
            throw Pan115Error.playURLNotFound
        }
        let headers = Pan115Client.playHeaders(cookie: cookie)
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        self.player = player
        player.play()
    }
}

enum Pan115PlaybackCache {
    private static func key(_ id: String) -> String { "xxxclub.115.magnet.\(id)" }

    static func save(id: String, magnet: String) {
        UserDefaults.standard.set(magnet, forKey: key(id))
    }

    static func magnet(for id: String) -> String? {
        UserDefaults.standard.string(forKey: key(id))
    }

    static func hasMagnet(_ id: String) -> Bool {
        !(magnet(for: id) ?? "").isEmpty
    }
}
