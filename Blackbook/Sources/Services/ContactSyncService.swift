import Foundation
import Contacts
import SwiftData

@MainActor
final class ContactSyncService {
    private let contactStore = CNContactStore()
    
    // Dependency Injection: the service should be instantiated or provided
    init() {}
    
    enum SyncError: LocalizedError {
        case accessDenied
        case unarchivingFailed
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "L'accesso ai contatti è stato negato."
            case .unarchivingFailed:
                return "Impossibile recuperare i dati originali del contatto."
            case .unknown(let error):
                return error.localizedDescription
            }
        }
    }
    
    func importAndDeleteFromSystem(contacts: [CNContact], modelContext: ModelContext) async throws {
        guard !contacts.isEmpty else { return }
        
        let granted = try await contactStore.requestAccess(for: .contacts)
        guard granted else {
            throw SyncError.accessDenied
        }
        
        let saveRequest = CNSaveRequest()
        
        for systemContact in contacts {
            let phoneNumbers = systemContact.phoneNumbers.map { $0.value.stringValue }
            let data = try? NSKeyedArchiver.archivedData(withRootObject: systemContact, requiringSecureCoding: true)
            
            // Refetch the contact just to get the thumbnail image data
            var thumbnail: Data? = nil
            if systemContact.isKeyAvailable(CNContactThumbnailImageDataKey) {
                thumbnail = systemContact.thumbnailImageData
            }
            
            if thumbnail == nil {
                let keys = [
                    CNContactImageDataAvailableKey as CNKeyDescriptor,
                    CNContactThumbnailImageDataKey as CNKeyDescriptor,
                    CNContactImageDataKey as CNKeyDescriptor
                ]
                if let fetched = try? contactStore.unifiedContact(withIdentifier: systemContact.identifier, keysToFetch: keys) {
                    if fetched.imageDataAvailable {
                        thumbnail = fetched.thumbnailImageData ?? fetched.imageData
                    }
                }
            }
            
            let newContact = BlackbookContact(
                firstName: systemContact.givenName,
                lastName: systemContact.familyName,
                phoneNumbers: phoneNumbers,
                isTrashed: false,
                contactData: data,
                thumbnailData: thumbnail
            )
            modelContext.insert(newContact)
            
            if let mutableContact = systemContact.mutableCopy() as? CNMutableContact {
                saveRequest.delete(mutableContact)
            }
        }
        
        try modelContext.save()
        try contactStore.execute(saveRequest)
    }
    
    func restoreToSystem(blackbookContact: BlackbookContact, modelContext: ModelContext) async throws {
        let granted = try await contactStore.requestAccess(for: .contacts)
        guard granted else {
            throw SyncError.accessDenied
        }
        
        guard let data = blackbookContact.contactData,
              let systemContact = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CNContact.self, from: data),
              let mutableContact = systemContact.mutableCopy() as? CNMutableContact else {
            throw SyncError.unarchivingFailed
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.add(mutableContact, toContainerWithIdentifier: nil)
        
        try contactStore.execute(saveRequest)
        
        // Remove from Blackbook
        modelContext.delete(blackbookContact)
        try modelContext.save()
    }
}
