//
//  SiteImage.swift
//  XXXClub
//
//  imgxclub.com 不带浏览器 User-Agent 会 403。AsyncImage 不带请求头，所以封面全空。
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
        var req = URLRequest(url: url)
        req.setValue(SiteImageCache.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://xxxclub.to/", forHTTPHeaderField: "Referer")
        req.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let decoded = UIImage(data: data) else {
                failed = true
                return
            }
            SiteImageCache.store(decoded, for: url)
            image = decoded
        } catch {
            failed = true
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
