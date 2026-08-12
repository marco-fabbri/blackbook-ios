import SwiftUI
import SwiftData
import Contacts

struct AgendaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<BlackbookContact> { $0.isTrashed == false }) private var allContacts: [BlackbookContact]
    
    @AppStorage("showListImages") private var showImages = true
    @AppStorage("sortOrder") private var sortOrder = "Cognome"
    
    @StateObject private var viewModel = AgendaViewModel()
    @State private var currentEditMode: EditMode = .inactive
    @State private var shareItem: ShareItem?
    
    @Binding var searchText: String
    
    var filteredContacts: [BlackbookContact] {
        if searchText.isEmpty {
            return allContacts
        }
        return allContacts.filter { contact in
            contact.firstName.localizedCaseInsensitiveContains(searchText) ||
            contact.lastName.localizedCaseInsensitiveContains(searchText) ||
            contact.organizationName.localizedCaseInsensitiveContains(searchText) ||
            (contact.phoneNumbers.first?.contains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            mainContent
                .environment(\.editMode, $currentEditMode)
                .sheet(isPresented: $viewModel.showingContactPicker) {
                    ContactPickerManager { result in
                        viewModel.showingContactPicker = false
                        switch result {
                        case .success(let systemContacts):
                            if !systemContacts.isEmpty {
                                viewModel.pendingImportContacts = systemContacts
                                viewModel.showingImportConfirm = true
                            }
                        case .failure(let error):
                            viewModel.errorMessage = error.localizedDescription
                            viewModel.showingError = true
                        }
                    }
                }
                // Error Alert
                .alert("Errore", isPresented: $viewModel.showingError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(viewModel.errorMessage)
                }
                // Import Confirm
                .alert("Conferma Importazione", isPresented: $viewModel.showingImportConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Importa", role: .destructive) {
                        let contactsToImport = viewModel.pendingImportContacts
                        Task {
                            do {
                                try await ContactSyncService().importAndDeleteFromSystem(
                                    contacts: contactsToImport,
                                    modelContext: modelContext
                                )
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                                viewModel.showingError = true
                            }
                        }
                    }
                } message: {
                    Text("Attenzione: i contatti selezionati verranno importati in Blackbook e RIMOSSI definitivamente dalla rubrica di iOS. Vuoi procedere?")
                }
                // Single Delete Confirm
                .alert("Sposta nel cestino", isPresented: $viewModel.showingSingleDeleteConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Sposta", role: .destructive) {
                        if let contact = viewModel.contactToActOn {
                            viewModel.trashContact(contact, context: modelContext)
                        }
                    }
                } message: {
                    Text("Vuoi spostare questo contatto nel cestino?")
                }
                // Batch Delete Confirm
                .alert("Sposta selezionati", isPresented: $viewModel.showingBatchDeleteConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Sposta", role: .destructive) {
                        viewModel.batchTrash(allContacts: allContacts, context: modelContext, editMode: $currentEditMode)
                    }
                } message: {
                    Text("Vuoi spostare \(viewModel.selectedContactIDs.count) contatti nel cestino?")
                }
                // Batch Restore Confirm
                .alert("Riporta su iOS", isPresented: $viewModel.showingBatchRestoreConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Riporta") {
                        viewModel.batchRestore(allContacts: allContacts, context: modelContext, editMode: $currentEditMode)
                    }
                } message: {
                    Text("Vuoi riportare \(viewModel.selectedContactIDs.count) contatti nella rubrica di sistema?")
                }
                .onDisappear {
                    currentEditMode = .inactive
                }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        let grouped = viewModel.groupedContacts(from: filteredContacts, sortOrder: sortOrder)
        let keys = viewModel.sortedKeys(for: grouped)
        
        ZStack(alignment: .bottom) {
            List(selection: $viewModel.selectedContactIDs) {
                ForEach(keys, id: \.self) { key in
                    Section(header: Text(key)) {
                        ForEach(grouped[key] ?? []) { contact in
                            AgendaCell(
                                contact: contact,
                                showImages: showImages,
                                onDelete: {
                                    viewModel.contactToActOn = contact
                                    viewModel.showingSingleDeleteConfirm = true
                                }
                            )
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 130) // Spazio per le capsule di vetro fluttuanti
            }
        }
        .navigationTitle("Contatti")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $shareItem) { item in
            ActivityViewController(activityItems: [item.url])
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation {
                            currentEditMode = currentEditMode.isEditing ? .inactive : .active
                        }
                    }) {
                        Text(currentEditMode.isEditing ? "Fine" : "Modifica")
                    }
                }
            }
            if currentEditMode.isEditing == false {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingContactPicker = true }) {
                        Image(systemName: "plus")
                    }
                }
            } else {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { 
                        let selectedContacts = allContacts.filter { viewModel.selectedContactIDs.contains($0.id) }
                        if let url = ExportService.shared.generateCSV(from: selectedContacts) {
                            shareItem = ShareItem(url: url)
                        }
                    }) {
                        Image(systemName: "arrow.up.doc")
                            .foregroundColor(viewModel.selectedContactIDs.isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.selectedContactIDs.isEmpty)
                    
                    Button(action: { viewModel.showingBatchDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(viewModel.selectedContactIDs.isEmpty ? .gray : .red)
                    }
                    .disabled(viewModel.selectedContactIDs.isEmpty)
                }
            }
        }
    }
}

// Extracted cell to prevent type-check timeouts and keep compilation fast
struct AgendaCell: View {
    let contact: BlackbookContact
    let showImages: Bool
    let onDelete: () -> Void
    
    var body: some View {
        NavigationLink(destination: ContactDetailView(blackbookContact: contact)) {
            AgendaRowView(contact: contact, showImages: showImages)
        }
        .swipeActions {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Trash", systemImage: "trash")
            }
        }
    }
}

struct AgendaRowView: View {
    let contact: BlackbookContact
    let showImages: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            if showImages {
                if let imageData = contact.thumbnailData ?? extractImage(from: contact.contactData), let uiImage = UIImage(data: imageData) {
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
                Text(contact.displayName)
                    .font(.headline)
                if let firstPhone = contact.phoneNumbers.first {
                    Text(firstPhone)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func extractImage(from data: Data?) -> Data? {
        guard let data = data,
              let contact = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CNContact.self, from: data) else {
            return nil
        }
        if contact.isKeyAvailable(CNContactThumbnailImageDataKey) {
            return contact.thumbnailImageData
        }
        if contact.isKeyAvailable(CNContactImageDataKey) {
            return contact.imageData
        }
        return nil
    }
}
