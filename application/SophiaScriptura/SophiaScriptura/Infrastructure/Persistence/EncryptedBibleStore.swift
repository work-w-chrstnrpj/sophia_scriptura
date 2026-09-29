import Foundation
import CoreData
import CryptoKit

/// Core Data stores authenticated ciphertext only, including edition metadata and leases.
/// Row identities are non-content lookup keys. Used exclusively by the library actor.
final class EncryptedBibleStore {
    private let coordinator: NSPersistentStoreCoordinator
    private let context: NSManagedObjectContext
    private let key: SymmetricKey
    init(url: URL, key: SymmetricKey) throws {
        self.key = key
        let entity = NSEntityDescription()
        entity.name = "EncryptedPayload"; entity.managedObjectClassName = "NSManagedObject"
        let identifier = NSAttributeDescription(); identifier.name = "identity"; identifier.attributeType = .stringAttributeType; identifier.isOptional = false
        let payload = NSAttributeDescription(); payload.name = "sealed"; payload.attributeType = .binaryDataAttributeType; payload.isOptional = false
        entity.properties = [identifier,payload]; entity.uniquenessConstraints = [["identity"]]
        let model = NSManagedObjectModel(); model.entities = [entity]
        coordinator = NSPersistentStoreCoordinator(managedObjectModel:model)
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.protectionKey:FileProtectionType.complete])
        var protectedFolder = folder
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try protectedFolder.setResourceValues(values)
        do {
            try coordinator.addPersistentStore(ofType:NSSQLiteStoreType,configurationName:nil,at:url,options:[
                NSPersistentStoreFileProtectionKey:FileProtectionType.complete,
                NSSQLitePragmasOption:["journal_mode":"DELETE","secure_delete":"ON"]])
        } catch { throw LicensedContentError.storage }
        context = NSManagedObjectContext(concurrencyType:.privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
    }
    func get<T: Decodable>(_ id: String, as type: T.Type = T.self) throws -> T? {
        try context.performAndWait {
            guard let object = try row(id), let sealed = object.value(forKey:"sealed") as? Data else { return nil }
            do {
                let bytes = try AES.GCM.open(AES.GCM.SealedBox(combined:sealed),using:key,authenticating:Data(id.utf8))
                return try JSONDecoder().decode(type,from:bytes)
            } catch { throw LicensedContentError.storage }
        }
    }
    func put<T: Encodable>(_ value: T, at id: String) throws {
        try context.performAndWait {
            do {
                let data = try JSONEncoder().encode(value)
                let sealed = try AES.GCM.seal(data,using:key,authenticating:Data(id.utf8)).combined!
                let object = try row(id) ?? NSEntityDescription.insertNewObject(forEntityName:"EncryptedPayload",into:context)
                object.setValue(id,forKey:"identity"); object.setValue(sealed,forKey:"sealed")
                try context.save(); context.reset()
            } catch { context.rollback(); throw LicensedContentError.storage }
        }
    }
    func remove(prefix: String) throws {
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName:"EncryptedPayload")
            request.predicate = NSPredicate(format:"identity BEGINSWITH %@",prefix)
            do { for row in try context.fetch(request) { context.delete(row) }; try context.save(); context.reset() }
            catch { context.rollback(); throw LicensedContentError.storage }
        }
    }
    private func row(_ id: String) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName:"EncryptedPayload")
        request.predicate = NSPredicate(format:"identity == %@",id); request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
