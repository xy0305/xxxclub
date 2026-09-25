//
//  SubscriptionsView.swift
//  XXXClub
//
//  订阅厂牌。检查时搜最新，同一部只推画质最高的到 115。
//

import SwiftUI

struct SubscriptionsView: View {
    @StateObject private var store = SubscriptionStore.shared
    @State private var draft = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("厂牌或演员，例如 Lucy Mochi", text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { add() }
                    Button("订阅") { add() }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                }
                Text("可以订阅厂牌，也可以订阅标题里的演员名。同一部只推最高画质，只推订阅之后新发布的。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button {
                    Task { await store.checkNow() }
                } label: {
                    if store.checking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("立即检查").frame(maxWidth: .infinity)
                    }
                }
                .disabled(store.checking || store.items.isEmpty)
                if !store.lastStatus.isEmpty {
                    Text(store.lastStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("已订阅") {
                if store.items.isEmpty {
                    Text("还没有订阅")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.items) { item in
                        Text(item.query)
                    }
                    .onDelete(perform: store.remove)
                }
            }
            if !store.logs.isEmpty {
                Section("最近推送") {
                    ForEach(store.logs) { log in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(log.title).lineLimit(2)
                            Text(log.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .liquidGlassPage()
        .navigationTitle("订阅")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        let q = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 3 else { return }
        if !store.contains(q) { store.toggle(query: q) }
        draft = ""
    }
}
