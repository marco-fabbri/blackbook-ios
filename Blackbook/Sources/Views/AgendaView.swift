import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<BlackbookContact> { $0.isTrashed == false }) private var allContacts: [BlackbookContact]
    
    @AppStorage("showListImages") private var showImages = true
    @AppStorage("sortOrder") private var sortOrder = "Cognome"
    
    @State private var showingContactPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Batch operations
    @State private var selectedContacts = Set<BlackbookContact>()
    @Environment(\.editMode) private var editMode
    
    // Confirmations
    @State private var showingSingleDeleteConfirm = false
    @State private var contactToDelete: BlackbookContact?
    
    @State private var showingBatchDeleteConfirm = false
    @State private var showingBatchRestoreConfirm = false
    
    var sortedContacts: [BlackbookContact] {
        allContacts.sorted {
            if sortOrder == "Nome" {
                return $0.sortName < $1.sortName
            } else {
                return $0.sortName < $1.sortName
            }
        }
    }
    
    var groupedContacts: [String: [BlackbookContact]] {
        Dictionary(grouping: sortedContacts, by: { $0.sortInitial })
    }
    
    var sortedKeys: [String] {
        groupedContacts.keys.sorted()
    }

    var body: some View {
        NavigationView {
            List(selection: $selectedContacts) {
                ForEach(sortedKeys, id: \.self) { key in
                    Section(header: Text(key)) {
                        ForEach(groupedContacts[key] ?? []) { contact in
                            NavigationLink(destination: ContactDetailView(blackbookContact: contact)) {
                                AgendaRowView(contact: contact, showImages: showImages)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    contactToDelete = contact
                                    showingSingleDeleteConfirm = true
                                } label: {
                                    Label("Trash", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if editMode?.wrappedValue.isEditing == true {
                        HStack {
                            Button(action: { showingBatchRestoreConfirm = true }) {
                                Image(systemName: "arrow.up.doc")
                            }
                            .disabled(selectedContacts.isEmpty)
                            
                            Button(action: { showingBatchDeleteConfirm = true }) {
                                Image(systemName: "trash")
                                    .foregroundColor(selectedContacts.isEmpty ? .gray : .red)
                            }
                            .disabled(selectedContacts.isEmpty)
                        }
                    } else {
                        Button(action: { showingContactPicker = true }) {
                            Label("Add", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPickerManager { result in
                    showingContactPicker = false
                    switch result {
                    case .success(let systemContacts):
                        ContactSyncManager.shared.importAndDeleteFromSystem(
                            contacts: systemContacts,
                            modelContext: modelContext
                        ) { error in
                            if let error = error {
                                self.errorMessage = error.localizedDescription
                                self.showingError = true
                            }
                        }
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.showingError = true
                    }
                }
            }
            // Error Alert
            .alert("Errore", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            // Single Delete Confirm
            .alert("Sposta nel cestino", isPresented: $showingSingleDeleteConfirm) {
                Button("Annulla", role: .cancel) { }
                Button("Sposta", role: .destructive) {
                    if let contact = contactToDelete {
                        moveToTrash(contact)
                    }
                }
            } message: {
                Text("Vuoi spostare questo contatto nel cestino?")
            }
            // Batch Delete Confirm
            .alert("Sposta selezionati", isPresented: $showingBatchDeleteConfirm) {
                Button("Annulla", role: .cancel) { }
                Button("Sposta", role: .destructive) {
                    batchTrash()
                }
            } message: {
                Text("Vuoi spostare \(selectedContacts.count) contatti nel cestino?")
            }
            // Batch Restore Confirm
            .alert("Riporta su iOS", isPresented: $showingBatchRestoreConfirm) {
                Button("Annulla", role: .cancel) { }
                Button("Riporta", role: .default) {
                    batchRestore()
                }
            } message: {
                Text("Vuoi riportare \(selectedContacts.count) contatti nella rubrica di sistema?")
            }
        }
    }
    
    private func moveToTrash(_ contact: BlackbookContact) {
        contact.isTrashed = true
        try? modelContext.save()
    }
    
    private func batchTrash() {
        for contact in selectedContacts {
            contact.isTrashed = true
        }
        try? modelContext.save()
        selectedContacts.removeAll()
        editMode?.wrappedValue = .inactive
    }
    
    private func batchRestore() {
        let contactsToRestore = Array(selectedContacts)
        var errors = [String]()
        
        let dispatchGroup = DispatchGroup()
        
        for contact in contactsToRestore {
            dispatchGroup.enter()
            ContactSyncManager.shared.restoreToSystem(blackbookContact: contact, modelContext: modelContext) { error in
                if let error = error {
                    errors.append(error.localizedDescription)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if !errors.isEmpty {
                self.errorMessage = "Alcuni contatti non sono stati ripristinati: \n" + errors.joined(separator: "\n")
                self.showingError = true
            }
            self.selectedContacts.removeAll()
            self.editMode?.wrappedValue = .inactive
        }
    }
}

struct AgendaRowView: View {
    var contact: BlackbookContact
    var showImages: Bool
    
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
                if let firstPhone = contact.phoneNumbers.first {
                    Text(firstPhone)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
