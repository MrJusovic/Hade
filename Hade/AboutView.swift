//
//  AboutView.swift
//  Hade
//
//  Uygulama hakkında bilgi + güncelleme denetimi ekranı.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var status: UpdateStatus = .idle

    var body: some View {
        VStack(spacing: 14) {
            appIcon
                .frame(width: 72, height: 72)

            Text(AppInfo.appName)
                .font(.largeTitle.bold())
            Text("Sürüm \(AppInfo.version) (\(AppInfo.build))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Hade, API benzeri açık kaynaklı bir HTTP istemcisidir. Tamamen ücretsizdir — herhangi bir ücret talep edilmez, reklam veya takip içermez.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            HStack(spacing: 10) {
                Button("GitHub") { openURL(AppInfo.repoURL) }
                Button("Sürümler") { openURL(AppInfo.releasesURL) }
                Button("Lisans") { openURL(AppInfo.licenseURL) }
            }
            .controlSize(.small)

            Divider()

            updateSection

            Button("Kapat") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 440)
    }

    private var appIcon: some View {
        Group {
            if let icon = loadedIcon {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "paperplane.circle.fill").resizable().foregroundStyle(.tint)
            }
        }
    }

    /// Uygulama ikonunu önce asset katalogdan, sonra çalışan uygulamanın ikonundan dener.
    private var loadedIcon: NSImage? {
        if let named = NSImage(named: "AppIcon") { return named }
        let appIcon = NSApp.applicationIconImage
        if let appIcon, appIcon.size.width > 1 { return appIcon }
        return nil
    }

    @ViewBuilder
    private var updateSection: some View {
        switch status {
        case .idle:
            checkButton("Güncellemeleri Denetle")
        case .checking:
            ProgressView("Denetleniyor…")
        case .upToDate:
            Label("En güncel sürümü kullanıyorsunuz.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            checkButton("Yeniden Denetle")
        case .available(let info):
            VStack(spacing: 8) {
                Label("Yeni sürüm mevcut: \(info.version)", systemImage: "arrow.down.circle.fill")
                    .foregroundStyle(.orange)
                if !info.notes.isEmpty {
                    ScrollView {
                        Text(info.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                }
                Button("İndir / Sürüm Sayfasını Aç") { openURL(info.url) }
                    .buttonStyle(.borderedProminent)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            checkButton("Yeniden Denetle")
        }
    }

    private func checkButton(_ title: String) -> some View {
        Button(title) {
            Task {
                status = .checking
                status = await UpdateChecker.check()
            }
        }
    }
}
