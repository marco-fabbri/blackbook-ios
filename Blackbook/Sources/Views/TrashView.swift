import SwiftUI
import SwiftData

struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<BlackbookContact> { $0.isTrashed == true }) private var trashedContacts: [BlackbookContact]
    
    @AppStorage("showListImages") private var showImages = true
    @AppStorage("sortOrder") private var sortOrder = "Cognome"
    
    // Batch operations - Using UUIDs to match the List's selection type inferrence
    @State private var selectedContactIDs = Set<UUID>()
    @Environment(\.editMode) private var editMode
    
    // Confirmations
    @State private var showingSingleDeleteConfirm = false
    @State private var showingSingleRestoreConfirm = false
    @State private var contactToActOn: BlackbookContact?
    
    @State private var showingBatchDeleteConfirm = false
    @State private var showingBatchRestoreConfirm = false
    
    var sortedContacts: [BlackbookContact] {
        trashedContacts.sorted {
            if sortOrder == "Nome" {
                return $0.sortName < $1.sortName
            } else {
                return $0.sortName < $1.sortName
            }
        }
    }

    var body: some View {
        NavigationView {
            mainContent
                // Single Delete Confirm
                .alert("Elimina definitivamente", isPresented: $showingSingleDeleteConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Elimina", role: .destructive) {
                        if let contact = contactToActOn {
                            permanentlyDelete(contact)
                        }
                    }
                } message: {
                    Text("Vuoi eliminare questo contatto in modo permanente? L'azione non può essere annullata.")
                }
                // Single Restore Confirm
                .alert("Ripristina contatto", isPresented: $showingSingleRestoreConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Ripristina") {
                        if let contact = contactToActOn {
                            restoreContact(contact)
                        }
                    }
                } message: {
                    Text("Vuoi ripristinare questo contatto nell'Agenda?")
                }
                // Batch Delete Confirm
                .alert("Elimina selezionati", isPresented: $showingBatchDeleteConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Elimina tutti", role: .destructive) {
                        batchDelete()
                    }
                } message: {
                    Text("Vuoi eliminare definitivamente \(selectedContactIDs.count) contatti? L'azione non può essere annullata.")
                }
                // Batch Restore Confirm
                .alert("Ripristina selezionati", isPresented: $showingBatchRestoreConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Ripristina tutti") {
                        batchRestore()
                    }
                } message: {
                    Text("Vuoi ripristinare \(selectedContactIDs.count) contatti nell'Agenda?")
                }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        List(selection: $selectedContactIDs) {
            ForEach(sortedContacts) { contact in
                TrashCell(
                    contact: contact,
                    showImages: showImages,
                    onDelete: {
                        contactToActOn = contact
                        showingSingleDeleteConfirm = true
                    },
                    onRestore: {
                        contactToActOn = contact
                        showingSingleRestoreConfirm = true
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Cestino")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if editMode?.wrappedValue.isEditing == true {
                    HStack {
                        Button(action: { showingBatchRestoreConfirm = true }) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(selectedContactIDs.isEmpty)
                        
                        Button(action: { showingBatchDeleteConfirm = true }) {
                            Image(systemName: "xmark.bin")
                                .foregroundColor(selectedContactIDs.isEmpty ? .gray : .red)
                        }
                        .disabled(selectedContactIDs.isEmpty)
                    }
                }
            }
        }
    }
    
    private func permanentlyDelete(_ contact: BlackbookContact) {
        modelContext.delete(contact)
        try? modelContext.save()
    }
    
    private func restoreContact(_ contact: BlackbookContact) {
        contact.isTrashed = false
        try? modelContext.save()
    }
    
    private func batchDelete() {
        let contactsToDelete = trashedContacts.filter { selectedContactIDs.contains($0.id) }
        for contact in contactsToDelete {
            modelContext.delete(contact)
        }
        try? modelContext.save()
        selectedContactIDs.removeAll()
        editMode?.wrappedValue = .inactive
    }
    
    private func batchRestore() {
        let contactsToRestore = trashedContacts.filter { selectedContactIDs.contains($0.id) }
        for contact in contactsToRestore {
            contact.isTrashed = false
        }
        try? modelContext.save()
        selectedContactIDs.removeAll()
        editMode?.wrappedValue = .inactive
    }
}

// Extracted cell to prevent type-check timeouts and keep compilation fast
struct TrashCell: View {
    let contact: BlackbookContact
    let showImages: Bool
    let onDelete: () -> Void
    let onRestore: () -> Void
    
    var body: some View {
        TrashRowView(contact: contact, showImages: showImages)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "xmark.bin")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    onRestore()
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
                .tint(.green)
            }
    }
}

struct TrashRowView: View {
    let contact: BlackbookContact
    let showImages: Bool
    
    var body: some View {
        HStack {
            if showImages {
                if let imageData = contact.thumbnailData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading) {
                Text("\(contact.firstName) \(contact.lastName)")
                    .font(.headline)
                    .foregroundColor(.gray)
                if let firstPhone = contact.phoneNumbers.first {
                    Text(firstPhone)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
