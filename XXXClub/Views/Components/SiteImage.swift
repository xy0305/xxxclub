//
//  SiteImage.swift
//  XXXClub
//
//  封面走系统图片加载。自定义请求偶发被取消或被站点拒绝时，灰块会一直停着。
//  失败后换浏览器头重试一次。
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
        if let decoded = await fetch(url, headers: false) ?? await fetch(url, headers: true) {
            SiteImageCache.store(decoded, for: url)
            image = decoded
        } else if !Task.isCancelled {
            failed = true
        }
    }

    private func fetch(_ url: URL, headers: Bool) async -> UIImage? {
        var req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 25)
        if headers {
            req.setValue(SiteImageCache.userAgent, forHTTPHeaderField: "User-Agent")
            req.setValue("https://xxxclub.to/", forHTTPHeaderField: "Referer")
            req.setValue("image/jpeg,image/png,image/*;q=0.8", forHTTPHeaderField: "Accept")
        }
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache.shared
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

enum SiteImageCache {
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    private static let cache = NSCache<NSURL, UIImage>()

    static func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    static func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
