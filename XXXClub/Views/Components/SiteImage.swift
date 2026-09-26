//
//  SiteImage.swift
//  XXXClub
//
//  列表封面很多，不能每张图新建一个会话。新建会话会被系统取消，看起来就是灰块。
//  共用一个会话，带浏览器头。失败再重试一次。
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
        var decoded = await SiteImageCache.fetch(url)
        if decoded == nil, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 400_000_000)
            decoded = await SiteImageCache.fetch(url)
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
    private static let session = XCClient.shared.session

    static func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    static func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    static func fetch(_ url: URL) async -> UIImage? {
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://xxxclub.to/", forHTTPHeaderField: "Referer")
        req.setValue("image/jpeg,image/png,image/*;q=0.8", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
