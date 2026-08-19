import SwiftUI
import SwiftData

struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<BlackbookContact> { $0.isTrashed == true }) private var trashedContacts: [BlackbookContact]
    
    @AppStorage("showListImages") private var showImages = true
    @AppStorage("sortOrder") private var sortOrder = "Last Name"
    
    @StateObject private var viewModel = TrashViewModel()
    @State private var currentEditMode: EditMode = .inactive

    var body: some View {
        mainContent
            .environment(\.editMode, $currentEditMode)
            // Single Delete Confirm
            .alert("Delete Permanently", isPresented: $viewModel.showingSingleDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let contact = viewModel.contactToActOn {
                        viewModel.permanentlyDelete(contact, context: modelContext)
                    }
                }
            } message: {
                Text("Permanently delete this contact? This action cannot be undone.")
            }
            // Single Restore Confirm
            .alert("Restore Contact", isPresented: $viewModel.showingSingleRestoreConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Restore") {
                    if let contact = viewModel.contactToActOn {
                        viewModel.restoreContact(contact, context: modelContext)
                    }
                }
            } message: {
                Text("Restore this contact to the Agenda?")
            }
            // Batch Delete Confirm
            .alert("Delete Selected", isPresented: $viewModel.showingBatchDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    viewModel.batchDelete(trashedContacts: trashedContacts, context: modelContext, editMode: $currentEditMode)
                }
            } message: {
                Text("Permanently delete \(viewModel.selectedContactIDs.count) contacts? This action cannot be undone.")
            }
            // Batch Restore Confirm
            .alert("Restore Selected", isPresented: $viewModel.showingBatchRestoreConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Restore All") {
                    viewModel.batchRestore(trashedContacts: trashedContacts, context: modelContext, editMode: $currentEditMode)
                }
            } message: {
                Text("Restore \(viewModel.selectedContactIDs.count) contacts to the Agenda?")
            }
            .onDisappear {
                currentEditMode = .inactive
            }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        let sorted = viewModel.sortContacts(trashedContacts, sortOrder: sortOrder)
        
        ZStack(alignment: .bottom) {
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
        }
        .navigationTitle("Trash")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if currentEditMode.isEditing == false {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            currentEditMode = .active
                        }
                    }) {
                        Text("Edit")
                    }
                }
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation {
                            currentEditMode = .inactive
                        }
                    }) {
                        Text("Done")
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingBatchRestoreConfirm = true }) {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundColor(viewModel.selectedContactIDs.isEmpty ? .gray : .green)
                    }
                    .disabled(viewModel.selectedContactIDs.isEmpty)
                    
                    Button(action: { viewModel.showingBatchDeleteConfirm = true }) {
                        Image(systemName: "xmark.bin")
                            .foregroundColor(viewModel.selectedContactIDs.isEmpty ? .gray : .red)
                    }
                    .disabled(viewModel.selectedContactIDs.isEmpty)
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
        HStack(spacing: 14) {
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
                Text(contact.displayName)
                    .font(.headline)
                    .foregroundColor(.gray)
                if let firstPhone = contact.phoneNumbers.first {
                    Text(firstPhone)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
