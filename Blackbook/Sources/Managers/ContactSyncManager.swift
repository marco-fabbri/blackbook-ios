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
                    let data = try? NSKeyedArchiver.archivedData(withRootObject: systemContact, requiringSecureCoding: true)
                    
                    let newContact = BlackbookContact(
                        firstName: systemContact.givenName,
                        lastName: systemContact.familyName,
                        phoneNumbers: phoneNumbers,
                        isTrashed: false,
                        contactData: data
                    )
                    modelContext.insert(newContact)
                    
                    guard let mutableContact = systemContact.mutableCopy() as? CNMutableContact else { continue }
                    saveRequest.delete(mutableContact)
                }
                
                try modelContext.save()
                try self.contactStore.execute(saveRequest)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    func restoreToSystem(blackbookContact: BlackbookContact, modelContext: ModelContext, completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            do {
                guard let data = blackbookContact.contactData,
                      let systemContact = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CNContact.self, from: data),
                      let mutableContact = systemContact.mutableCopy() as? CNMutableContact else {
                    
                    // Fallback se non c'è il dato raw, creiamo uno basilare
                    let fallbackContact = CNMutableContact()
                    fallbackContact.givenName = blackbookContact.firstName
                    fallbackContact.familyName = blackbookContact.lastName
                    // Per il fallback ignoriamo i telefoni o andrebbero parsati, meglio fallire elegantemente o fare un restore limitato
                    // Ma abbiamo contactData in teoria.
                    let error = NSError(domain: "ContactSync", code: 2, userInfo: [NSLocalizedDescriptionKey: "Impossibile recuperare i dati originali del contatto."])
                    completion(error)
                    return
                }
                
                let saveRequest = CNSaveRequest()
                saveRequest.add(mutableContact, toContainerWithIdentifier: nil)
                
                try self.contactStore.execute(saveRequest)
                
                // Rimuoviamo da Blackbook
                modelContext.delete(blackbookContact)
                try modelContext.save()
                
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
