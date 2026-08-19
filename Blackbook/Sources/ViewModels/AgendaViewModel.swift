import Foundation
import SwiftData
import SwiftUI
import Contacts

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
    
    @Published var showingImportConfirm = false
    var pendingImportContacts: [CNContact] = []
    
    private let syncService: ContactSyncService
    
    init(syncService: ContactSyncService? = nil) {
        self.syncService = syncService ?? ContactSyncService()
    }
    
    // Formatting & Grouping
    func groupedContacts(from contacts: [BlackbookContact], sortOrder: String) -> [String: [BlackbookContact]] {
        let sorted = contacts.sorted {
            $0.sortName(for: sortOrder).localizedCaseInsensitiveCompare($1.sortName(for: sortOrder)) == .orderedAscending
        }
        return Dictionary(grouping: sorted, by: { $0.sortInitial(for: sortOrder) })
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
                self.errorMessage = "Some contacts were not restored: \n" + errors.joined(separator: "\n")
                self.showingError = true
            }
            self.selectedContactIDs.removeAll()
            editMode?.wrappedValue = .inactive
        }
    }
}
