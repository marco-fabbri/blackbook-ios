import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<BlackbookContact> { $0.isTrashed == false }) private var allContacts: [BlackbookContact]
    
    @AppStorage("showListImages") private var showImages = true
    @AppStorage("sortOrder") private var sortOrder = "Cognome"
    
    @StateObject private var viewModel = AgendaViewModel()
    @State private var currentEditMode: EditMode = .inactive
    
    var body: some View {
        NavigationView {
            mainContent
                .environment(\.editMode, $currentEditMode)
                .sheet(isPresented: $viewModel.showingContactPicker) {
                    ContactPickerManager { result in
                        viewModel.showingContactPicker = false
                        switch result {
                        case .success(let systemContacts):
                            Task {
                                do {
                                    try await ContactSyncService().importAndDeleteFromSystem(
                                        contacts: systemContacts,
                                        modelContext: modelContext
                                    )
                                } catch {
                                    viewModel.errorMessage = error.localizedDescription
                                    viewModel.showingError = true
                                }
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
        let grouped = viewModel.groupedContacts(from: allContacts, sortOrder: sortOrder)
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
            .listStyle(SidebarListStyle())
            
            if currentEditMode.isEditing == true {
                // Floating Mass Actions Bar
                HStack(spacing: 60) {
                    Button(action: { viewModel.showingBatchRestoreConfirm = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 20))
                            Text("Esporta")
                                .font(.caption)
                        }
                        .foregroundColor(viewModel.selectedContactIDs.isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.selectedContactIDs.isEmpty)
                    
                    Button(action: { viewModel.showingBatchDeleteConfirm = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 20))
                            Text("Cestina")
                                .font(.caption)
                        }
                        .foregroundColor(viewModel.selectedContactIDs.isEmpty ? .gray : .red)
                    }
                    .disabled(viewModel.selectedContactIDs.isEmpty)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 40)
                .background(Color(UIColor.systemBackground).opacity(0.95))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                .padding(.bottom, 20)
            } else {
                // FAB - Floating Action Button
                HStack {
                    Spacer()
                    Button(action: { viewModel.showingContactPicker = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
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
