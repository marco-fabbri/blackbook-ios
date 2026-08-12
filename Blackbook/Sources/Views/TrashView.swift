import SwiftUI
import SwiftData

struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<BlackbookContact> { $0.isTrashed == true }) private var trashedContacts: [BlackbookContact]
    
    @AppStorage("showListImages") private var showImages = true
    @AppStorage("sortOrder") private var sortOrder = "Cognome"
    
    @StateObject private var viewModel = TrashViewModel()
    @State private var currentEditMode: EditMode = .inactive

    var body: some View {
        NavigationView {
            mainContent
                .environment(\.editMode, $currentEditMode)
                // Single Delete Confirm
                .alert("Elimina definitivamente", isPresented: $viewModel.showingSingleDeleteConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Elimina", role: .destructive) {
                        if let contact = viewModel.contactToActOn {
                            viewModel.permanentlyDelete(contact, context: modelContext)
                        }
                    }
                } message: {
                    Text("Vuoi eliminare questo contatto in modo permanente? L'azione non può essere annullata.")
                }
                // Single Restore Confirm
                .alert("Ripristina contatto", isPresented: $viewModel.showingSingleRestoreConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Ripristina") {
                        if let contact = viewModel.contactToActOn {
                            viewModel.restoreContact(contact, context: modelContext)
                        }
                    }
                } message: {
                    Text("Vuoi ripristinare questo contatto nell'Agenda?")
                }
                // Batch Delete Confirm
                .alert("Elimina selezionati", isPresented: $viewModel.showingBatchDeleteConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Elimina tutti", role: .destructive) {
                        viewModel.batchDelete(trashedContacts: trashedContacts, context: modelContext, editMode: $currentEditMode)
                    }
                } message: {
                    Text("Vuoi eliminare definitivamente \(viewModel.selectedContactIDs.count) contatti? L'azione non può essere annullata.")
                }
                // Batch Restore Confirm
                .alert("Ripristina selezionati", isPresented: $viewModel.showingBatchRestoreConfirm) {
                    Button("Annulla", role: .cancel) { }
                    Button("Ripristina tutti") {
                        viewModel.batchRestore(trashedContacts: trashedContacts, context: modelContext, editMode: $currentEditMode)
                    }
                } message: {
                    Text("Vuoi ripristinare \(viewModel.selectedContactIDs.count) contatti nell'Agenda?")
                }
                .onDisappear {
                    currentEditMode = .inactive
                }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        let sorted = viewModel.sortContacts(trashedContacts, sortOrder: sortOrder)
        
        List(selection: $viewModel.selectedContactIDs) {
            ForEach(sorted) { contact in
                TrashCell(
                    contact: contact,
                    showImages: showImages,
                    onDelete: {
                        viewModel.contactToActOn = contact
                        viewModel.showingSingleDeleteConfirm = true
                    },
                    onRestore: {
                        viewModel.contactToActOn = contact
                        viewModel.showingSingleRestoreConfirm = true
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
                if currentEditMode.isEditing == true {
                    HStack(spacing: 16) {
                        Button(action: { viewModel.showingBatchRestoreConfirm = true }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .disabled(viewModel.selectedContactIDs.isEmpty)
                        
                        Button(action: { viewModel.showingBatchDeleteConfirm = true }) {
                            Image(systemName: "xmark.bin")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .foregroundColor(viewModel.selectedContactIDs.isEmpty ? .gray : .red)
                                .background(viewModel.selectedContactIDs.isEmpty ? Color.gray.opacity(0.15) : Color.red.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .disabled(viewModel.selectedContactIDs.isEmpty)
                    }
                }
            }
        }
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
