//
//  Persistence.swift
//  Hade
//
//  Created by Fatih BAŞ on 25.09.2026.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Örnek bir koleksiyon ve istek ile önizlemeyi doldur.
        let collection = RequestCollection(context: viewContext)
        collection.id = UUID()
        collection.name = "Örnek Koleksiyon"
        collection.createdAt = Date()
        collection.sortIndex = 0

        let request = SavedRequest(context: viewContext)
        request.id = UUID()
        request.name = "Kullanıcıları listele"
        request.method = "GET"
        request.urlString = "https://jsonplaceholder.typicode.com/users"
        request.bodyType = "none"
        request.createdAt = Date()
        request.updatedAt = Date()
        request.sortIndex = 0
        request.collection = collection

        let env = AppEnvironment(context: viewContext)
        env.id = UUID()
        env.name = "Geliştirme"
        env.isActive = true
        env.createdAt = Date()
        env.variablesJSON = #"[{"key":"baseUrl","value":"https://jsonplaceholder.typicode.com","enabled":true}]"#

        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    /// Modeli yalnızca bir kez yükle ve tüm container'larda paylaş.
    ///
    /// Aksi halde (özellikle SwiftUI Preview'larında) model birden çok kez
    /// yüklenir; aynı NSManagedObject alt sınıfını birden fazla entity sahiplenir
    /// ve `Entity.entity()` `nil` döner. Bu da `@FetchRequest`'in nil entity'li
    /// bir fetch çalıştırıp exception fırlatmasına ve uygulamanın çökmesine yol açar.
    private static let managedObjectModel: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "Hade", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Hade.momd Core Data modeli bulunamadı.")
        }
        return model
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Hade", managedObjectModel: Self.managedObjectModel)
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
