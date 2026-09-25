//
//  GlassUI.swift
//  XXXClub
//
//  跟 AVDB 同一套：iOS 26 用系统 Liquid Glass，更早系统回退材质。
//  玻璃默认不 interactive。iPad 不用 GlassEffectContainer，避免整块区域吃点击。
//

import SwiftUI
import UIKit

enum AdaptiveLayout {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    static var contentMaxWidth: CGFloat { 1100 }
    static var horizontalPadding: CGFloat { isPad ? 24 : 16 }
    static var gridPadding: CGFloat { isPad ? 20 : 12 }
    static var posterMin: CGFloat { isPad ? 150 : 108 }
}

enum XCPalette {
    static let pink = Color(red: 0.93, green: 0.15, blue: 0.48)
    static let accent = Color(red: 0.12, green: 0.48, blue: 0.96)
    static let seed = Color(red: 0.18, green: 0.62, blue: 0.38)
}

struct GlassRim<S: InsettableShape>: View {
    let shape: S
    var lineWidth: CGFloat = 1

    var body: some View {
        shape.strokeBorder(
            LinearGradient(
                colors: [.white.opacity(0.55), .white.opacity(0.08), .black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: lineWidth
        )
        .allowsHitTesting(false)
    }
}

struct LiquidGlassRectEffect: ViewModifier {
    var cornerRadius: CGFloat = 16
    var tint: Color? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            Group {
                if let tint {
                    content.glassEffect(.regular.tint(tint), in: shape)
                } else {
                    content.glassEffect(.regular, in: shape)
                }
            }
            .overlay { GlassRim(shape: shape) }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay { GlassRim(shape: shape, lineWidth: 0.7) }
        }
    }
}

struct LiquidGlassCapsuleEffect: ViewModifier {
    var tint: Color? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            Group {
                if let tint {
                    content.glassEffect(.regular.tint(tint), in: Capsule())
                } else {
                    content.glassEffect(.regular, in: Capsule())
                }
            }
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

struct LiquidGlassCircleEffect: ViewModifier {
    var tint: Color? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            Group {
                if let tint {
                    content.glassEffect(.regular.tint(tint), in: Circle())
                } else {
                    content.glassEffect(.regular, in: Circle())
                }
            }
            .overlay { GlassRim(shape: Circle()) }
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay { GlassRim(shape: Circle(), lineWidth: 0.7) }
        }
    }
}

struct LiquidGlassContainer<Content: View>: View {
    var spacing: CGFloat = 8
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *), !AdaptiveLayout.isPad {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension View {
    func liquidGlassRect(cornerRadius: CGFloat = 16, tint: Color? = nil) -> some View {
        modifier(LiquidGlassRectEffect(cornerRadius: cornerRadius, tint: tint))
    }

    func liquidGlass(tint: Color? = nil) -> some View {
        modifier(LiquidGlassCapsuleEffect(tint: tint))
    }

    func liquidGlassCircle(tint: Color? = nil) -> some View {
        modifier(LiquidGlassCircleEffect(tint: tint))
    }

    func liquidGlassPage() -> some View {
        background { LiquidGlassBackground() }
    }

    func glassMediaFrame(cornerRadius: CGFloat = 12) -> some View {
        clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                GlassRim(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }

    func nestedListChrome() -> some View {
        modifier(NestedListChrome())
    }

    @ViewBuilder
    func xcGlassButton(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

private struct NestedListChrome: ViewModifier {
    func body(content: Content) -> some View {
        if AdaptiveLayout.isPad {
            content.toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
    }
}

struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [
                    XCPalette.pink.opacity(0.08),
                    Color.blue.opacity(0.05),
                    Color.purple.opacity(0.03),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

enum GlassHaptic {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct PressableGlassStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func pressableGlass() -> some View {
        buttonStyle(PressableGlassStyle())
    }
}

struct GlassChip: View {
    let text: String
    var tint: Color = .blue
    var foreground: Color = .white

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.88), in: Capsule())
            .allowsHitTesting(false)
    }
}

struct SectionHeaderBar: View {
    let title: String
    var trailing: String? = "全部"
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))
            Spacer()
            if let trailing, let action {
                Button(trailing, action: action)
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
    }
}

struct PosterImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder
            default:
                ZStack {
                    Color(.systemGray6)
                    ProgressView()
                }
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.systemGray6)
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.tertiary)
        }
    }
}

struct PosterCard: View {
    let torrent: XCTorrent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                PosterImage(url: torrent.coverURL)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .glassMediaFrame(cornerRadius: 12)
                if let rank = torrent.rank {
                    GlassChip(text: "#\(rank)", tint: XCPalette.pink)
                        .padding(6)
                } else if !torrent.size.isEmpty {
                    GlassChip(text: torrent.size, tint: .black.opacity(0.55))
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            Text(torrent.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if torrent.seeders > 0 || !torrent.added.isEmpty {
                Text(meta)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }

    private var meta: String {
        var parts: [String] = []
        if torrent.seeders > 0 { parts.append("S \(torrent.seeders)") }
        if !torrent.added.isEmpty { parts.append(torrent.added) }
        return parts.joined(separator: " · ")
    }
}

struct PosterGrid: View {
    let items: [XCTorrent]

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: AdaptiveLayout.posterMin), spacing: 12)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { item in
                NavigationLink {
                    DetailView(id: item.id, preview: item)
                } label: {
                    PosterCard(torrent: item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AdaptiveLayout.gridPadding)
    }
}
