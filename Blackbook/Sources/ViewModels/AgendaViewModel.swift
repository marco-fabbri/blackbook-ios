import Foundation
import SwiftData
import SwiftUI

@MainActor
final class AgendaViewModel: ObservableObject {
    @Published var selectedContactIDs = Set<UUID>()
    @Published var showingContactPicker = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    @Published var showingSingleDeleteConfirm = false
    @Published var showingBatchDeleteConfirm = false
    @Published var showingBatchRestoreConfirm = false
    
    @Published var contactToActOn: BlackbookContact?
    
    private let syncService: ContactSyncService
    
    init(syncService: ContactSyncService = ContactSyncService()) {
        self.syncService = syncService
    }
    
    // Formatting & Grouping
    func groupedContacts(from contacts: [BlackbookContact], sortOrder: String) -> [String: [BlackbookContact]] {
        let sorted = contacts.sorted {
            if sortOrder == "Nome" {
                return $0.sortName < $1.sortName
            } else {
                return $0.sortName < $1.sortName
            }
        }
        return Dictionary(grouping: sorted, by: { $0.sortInitial })
    }
    
    func sortedKeys(for groupedContacts: [String: [BlackbookContact]]) -> [String] {
        return groupedContacts.keys.sorted()
    }
    
    // Intents / Actions
    func trashContact(_ contact: BlackbookContact, context: ModelContext) {
        contact.isTrashed = true
        try? context.save()
    }
    
    func batchTrash(allContacts: [BlackbookContact], context: ModelContext, editMode: Binding<EditMode>?) {
        let contactsToTrash = allContacts.filter { selectedContactIDs.contains($0.id) }
        for contact in contactsToTrash {
            contact.isTrashed = true
        }
        try? context.save()
        selectedContactIDs.removeAll()
        editMode?.wrappedValue = .inactive
    }
    
    func batchRestore(allContacts: [BlackbookContact], context: ModelContext, editMode: Binding<EditMode>?) {
        let contactsToRestore = allContacts.filter { selectedContactIDs.contains($0.id) }
        var errors = [String]()
        
        Task {
            for contact in contactsToRestore {
                do {
                    try await syncService.restoreToSystem(blackbookContact: contact, modelContext: context)
                } catch {
                    errors.append(error.localizedDescription)
                }
            }
            
            if !errors.isEmpty {
                self.errorMessage = "Alcuni contatti non sono stati ripristinati: \n" + errors.joined(separator: "\n")
                self.showingError = true
            }
            self.selectedContactIDs.removeAll()
            editMode?.wrappedValue = .inactive
        }
    }
}
