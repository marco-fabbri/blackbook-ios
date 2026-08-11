import SwiftUI
import SwiftData

struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<BlackbookContact> { $0.isTrashed == true }, sort: \BlackbookContact.lastName) private var trashedContacts: [BlackbookContact]
    
    @State private var showingEmptyTrashConfirmation = false

    var body: some View {
        NavigationView {
            List {
                ForEach(trashedContacts) { contact in
                    VStack(alignment: .leading) {
                        Text("\(contact.firstName) \(contact.lastName)")
                            .font(.headline)
                        if let firstPhone = contact.phoneNumbers.first {
                            Text(firstPhone)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions {
                        Button {
                            restore(contact)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                        
                        Button(role: .destructive) {
                            deletePermanently(contact)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    }
                }
            }
            .navigationTitle("Trash")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Empty") {
                        showingEmptyTrashConfirmation = true
                    }
                    .disabled(trashedContacts.isEmpty)
                    .foregroundColor(.red)
                }
            }
            .alert("Empty Trash", isPresented: $showingEmptyTrashConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    emptyTrash()
                }
            } message: {
                Text("Are you sure you want to permanently delete all contacts in the trash? This cannot be undone.")
            }
        }
    }
    
    private func restore(_ contact: BlackbookContact) {
        contact.isTrashed = false
        try? modelContext.save()
    }
    
    private func deletePermanently(_ contact: BlackbookContact) {
        modelContext.delete(contact)
        try? modelContext.save()
    }
    
    private func emptyTrash() {
        for contact in trashedContacts {
            modelContext.delete(contact)
        }
        try? modelContext.save()
    }
}
