//
//  ContentView.swift
//  XXXClub
//
//  系统 TabView。iOS 26 自动变成液态玻璃 Tab。
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case home, rankings, categories, me
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .rankings: return "排行"
        case .categories: return "类别"
        case .me: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .rankings: return "trophy"
        case .categories: return "square.grid.2x2"
        case .me: return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.icon) }
                .tag(AppTab.home)
            RankingsTab()
                .tabItem { Label(AppTab.rankings.title, systemImage: AppTab.rankings.icon) }
                .tag(AppTab.rankings)
            CategoriesView()
                .tabItem { Label(AppTab.categories.title, systemImage: AppTab.categories.icon) }
                .tag(AppTab.categories)
            MineView()
                .tabItem { Label(AppTab.me.title, systemImage: AppTab.me.icon) }
                .tag(AppTab.me)
        }
        .tint(XCPalette.pink)
        .modifier(TabBarMinimize())
    }
}

struct RankingsTab: View {
    var body: some View {
        NavigationStack {
            RankView(kind: .top10)
        }
    }
}

private struct TabBarMinimize: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !AdaptiveLayout.isPad {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}
