//
//  SiteImage.swift
//  XXXClub
//
//  列表封面。自定义 URLSession 在真机上会被取消或拒绝，灰块就停在那里。
//  先用系统缓存加载，失败再带浏览器头重试。
//

import SwiftUI
import UIKit

struct SiteImage: View {
    let url: URL?
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if failed {
                ZStack {
                    Color(.systemGray6)
                    Image(systemName: "photo").font(.title3).foregroundStyle(.tertiary)
                }
            } else {
                ZStack {
                    Color(.systemGray6)
                    ProgressView()
                }
            }
        }
        .task(id: url?.absoluteString) { await load() }
    }

    private func load() async {
        image = nil
        failed = false
        guard let url else { failed = true; return }
        if let cached = SiteImageCache.image(for: url) {
            image = cached
            return
        }
        var decoded = await SiteImageCache.fetch(url, headers: false)
        if decoded == nil, !Task.isCancelled {
            decoded = await SiteImageCache.fetch(url, headers: true)
        }
        if let decoded {
            SiteImageCache.store(decoded, for: url)
            image = decoded
        } else if !Task.isCancelled {
            failed = true
        }
    }
}

enum SiteImageCache {
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    private static let cache = NSCache<NSURL, UIImage>()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache.shared
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    static func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    static func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    static func fetch(_ url: URL, headers: Bool) async -> UIImage? {
        var req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        if headers {
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req.setValue("https://xxxclub.to/", forHTTPHeaderField: "Referer")
            req.setValue("image/avif,image/webp,image/apng,image/jpeg,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        }
        do {
            let (data, response) = try await session.data(for: req)
            guard !Task.isCancelled else { return nil }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count > 32 else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
