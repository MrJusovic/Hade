//
//  HadeApp.swift
//  Hade
//
//  Created by Fatih BAŞ on 25.09.2026.
//

import SwiftUI
import CoreData
import AppKit

@main
struct HadeApp: App {
    let persistenceController = PersistenceController.shared
    @State private var store: AppStore

    init() {
        let context = PersistenceController.shared.container.viewContext
        _store = State(initialValue: AppStore(context: context))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(store)
        }
        .windowStyle(.titleBar)
        .commands {
            // "Hade Hakkında" menüsünü özel ekranımızla değiştir.
            CommandGroup(replacing: .appInfo) {
                Button("\(AppInfo.appName) Hakkında") { store.showAbout = true }
            }
            // Yardım menüsü.
            CommandGroup(replacing: .help) {
                Button("\(AppInfo.appName) Hakkında / Bilgi") { store.showAbout = true }
                Button("Güncellemeleri Denetle…") { store.showAbout = true }
                Divider()
                Button("GitHub Deposu") { NSWorkspace.shared.open(AppInfo.repoURL) }
                Button("Sürümler") { NSWorkspace.shared.open(AppInfo.releasesURL) }
            }
        }
    }
}
