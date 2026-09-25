//
//  HadeApp.swift
//  Hade
//
//  Created by Fatih BAŞ on 25.09.2026.
//

import SwiftUI
import CoreData

@main
struct HadeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
