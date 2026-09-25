//
//  Pan115SettingsView.swift
//  XXXClub
//
//  115 离线设置：Cookie（UID/CID/SEID）+ 离线目录 CID。
//

import SwiftUI

struct Pan115SettingsView: View {
    @ObservedObject private var settings = Pan115Settings.shared
    @State private var cookieDraft = ""
    @State private var cidDraft = ""
    @State private var status: String?
    @State private var statusOK = false
    @State private var testing = false

    var body: some View {
        Form {
            Section {
                Text("从 115 网页登录后复制完整 Cookie，必须包含 UID、CID、SEID。离线目录 CID 是网盘目标文件夹 ID，根目录填 0。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Cookie") {
                TextEditor(text: $cookieDraft)
                    .frame(minHeight: 120)
                    .font(.system(.caption, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section("离线目录 CID") {
                TextField("例如 0 或 1234567890", text: $cidDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
            }
            Section {
                Button("保存") { save() }
                Button {
                    Task { await test() }
                } label: {
                    if testing {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("测试连接").frame(maxWidth: .infinity)
                    }
                }
                .disabled(testing)
            }
            if let status {
                Section {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(statusOK ? .green : .red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .liquidGlassPage()
        .navigationTitle("115 离线")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cookieDraft = settings.cookie
            cidDraft = settings.folderCID
        }
    }

    private func save() {
        settings.cookie = Pan115Settings.normalizeCookie(cookieDraft)
        settings.folderCID = cidDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        cookieDraft = settings.cookie
        cidDraft = settings.folderCID
        statusOK = settings.isConfigured
        status = settings.isConfigured ? "已保存。详情页点播放，会先推送到 115，完成后自动播放。" : settings.missingHint
    }

    private func test() async {
        save()
        guard settings.isConfigured else { return }
        testing = true
        defer { testing = false }
        do {
            let result = try await Pan115Client.shared.addOfflineTask(
                url: "magnet:?xt=urn:btih:0000000000000000000000000000000000000000",
                cookie: settings.cookie,
                folderCID: settings.folderCID
            )
            switch result {
            case .success, .exists:
                statusOK = true
                status = "连接正常（\(result.message)）"
            case .failed(let msg):
                let bad = msg.contains("Cookie") || msg.contains("登录") || msg.contains("过期")
                statusOK = !bad
                status = bad ? msg : "Cookie 有效：" + msg
            }
        } catch {
            statusOK = false
            status = error.localizedDescription
        }
    }
}
