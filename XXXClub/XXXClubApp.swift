//
//  XXXClubApp.swift
//  XXXClub
//

import SwiftUI

@main
struct XXXClubApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(XCPalette.accent)
                .task { await SubscriptionStore.shared.checkNow() }
        }
    }
}
