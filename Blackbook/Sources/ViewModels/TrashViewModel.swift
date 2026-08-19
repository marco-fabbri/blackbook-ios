import Foundation
import SwiftData
import SwiftUI

@MainActor
final class TrashViewModel: ObservableObject {
    @Published var selectedContactIDs = Set<UUID>()
    
    @Published var showingSingleDeleteConfirm = false
    @Published var showingSingleRestoreConfirm = false
    @Published var showingBatchDeleteConfirm = false
    @Published var showingBatchRestoreConfirm = false
    
    @Published var contactToActOn: BlackbookContact?
    
    // Formatting
    func sortContacts(_ contacts: [BlackbookContact], sortOrder: String) -> [BlackbookContact] {
        return contacts.sorted {
            if sortOrder == "First Name" {
                return $0.sortName < $1.sortName
            } else {
                return $0.sortName < $1.sortName
            }
        }
    }
    
    // Intents / Actions
    func permanentlyDelete(_ contact: BlackbookContact, context: ModelContext) {
        context.delete(contact)
        try? context.save()
    }
    
    func restoreContact(_ contact: BlackbookContact, context: ModelContext) {
        contact.isTrashed = false
        try? context.save()
    }
    
    func batchDelete(trashedContacts: [BlackbookContact], context: ModelContext, editMode: Binding<EditMode>?) {
        let contactsToDelete = trashedContacts.filter { selectedContactIDs.contains($0.id) }
        for contact in contactsToDelete {
            context.delete(contact)
        }
        try? context.save()
        selectedContactIDs.removeAll()
        editMode?.wrappedValue = .inactive
    }
    
    func batchRestore(trashedContacts: [BlackbookContact], context: ModelContext, editMode: Binding<EditMode>?) {
        let contactsToRestore = trashedContacts.filter { selectedContactIDs.contains($0.id) }
        for contact in contactsToRestore {
            contact.isTrashed = false
        }
        try? context.save()
        selectedContactIDs.removeAll()
        editMode?.wrappedValue = .inactive
    }
}
