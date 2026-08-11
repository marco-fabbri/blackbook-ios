import Foundation
import Contacts
import SwiftData

class ContactSyncManager {
    static let shared = ContactSyncManager()
    private let contactStore = CNContactStore()
    
    private init() {}
    
    func importAndDeleteFromSystem(contacts: [CNContact], modelContext: ModelContext, completion: @escaping (Error?) -> Void) {
        guard !contacts.isEmpty else {
            completion(nil)
            return
        }
        
        contactStore.requestAccess(for: .contacts) { [weak self] granted, error in
            if let error = error {
                DispatchQueue.main.async { completion(error) }
                return
            }
            
            guard granted else {
                let error = NSError(domain: "ContactSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Contacts access denied."])
                DispatchQueue.main.async { completion(error) }
                return
            }
            
            self?.performImportAndDelete(contacts: contacts, modelContext: modelContext, completion: completion)
        }
    }
    
    private func performImportAndDelete(contacts: [CNContact], modelContext: ModelContext, completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            do {
                let saveRequest = CNSaveRequest()
                
                for systemContact in contacts {
                    let phoneNumbers = systemContact.phoneNumbers.map { $0.value.stringValue }
                    let newContact = BlackbookContact(
                        firstName: systemContact.givenName,
                        lastName: systemContact.familyName,
                        phoneNumbers: phoneNumbers,
                        isTrashed: false
                    )
                    modelContext.insert(newContact)
                    
                    guard let mutableContact = systemContact.mutableCopy() as? CNMutableContact else { continue }
                    saveRequest.delete(mutableContact)
                }
                
                try modelContext.save()
                
                // execute(saveRequest) fa una chiamata di sistema, può essere eseguita qui
                // ma per evitare blocchi della UI eccessivi, potremmo spostarla in background,
                // però richiede l'uso corretto dei thread. Dato che è rapido, va bene sul main.
                try self.contactStore.execute(saveRequest)
                
                completion(nil)
                
            } catch {
                completion(error)
            }
        }
    }
}
