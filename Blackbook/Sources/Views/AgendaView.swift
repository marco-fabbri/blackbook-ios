import SwiftUI
import SwiftData
import Contacts

struct AgendaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<BlackbookContact> { $0.isTrashed == false }) private var allContacts: [BlackbookContact]
    
    @AppStorage("showListImages") private var showImages = true
    @AppStorage("sortOrder") private var sortOrder = "Last Name"
    
    @StateObject private var viewModel = AgendaViewModel()
    @State private var currentEditMode: EditMode = .inactive
    @State private var shareItem: ShareItem?
    
    @State private var searchText = ""
    
    var filteredContacts: [BlackbookContact] {
        if searchText.isEmpty {
            return allContacts
        }
        return allContacts.filter { contact in
            contact.firstName.localizedCaseInsensitiveContains(searchText) ||
            contact.lastName.localizedCaseInsensitiveContains(searchText) ||
            contact.organizationName.localizedCaseInsensitiveContains(searchText) ||
            contact.phoneNumbers.contains { $0.localizedCaseInsensitiveContains(searchText) }
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
                .alert("Error", isPresented: $viewModel.showingError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(viewModel.errorMessage)
                }
                // Import Confirm
                .alert("Confirm Import", isPresented: $viewModel.showingImportConfirm) {
                    Button("Cancel", role: .cancel) { }
                    Button("Import", role: .destructive) {
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
                    Text("Warning: selected contacts will be imported into Blackbook and permanently REMOVED from the iOS address book. Proceed?")
                }
                // Single Delete Confirm
                .alert("Move to Trash", isPresented: $viewModel.showingSingleDeleteConfirm) {
                    Button("Cancel", role: .cancel) { }
                    Button("Move", role: .destructive) {
                        if let contact = viewModel.contactToActOn {
                            viewModel.trashContact(contact, context: modelContext)
                        }
                    }
                } message: {
                    Text("Move this contact to the trash?")
                }
                // Batch Delete Confirm
                .alert("Move Selected", isPresented: $viewModel.showingBatchDeleteConfirm) {
                    Button("Cancel", role: .cancel) { }
                    Button("Move", role: .destructive) {
                        viewModel.batchTrash(allContacts: allContacts, context: modelContext, editMode: $currentEditMode)
                    }
                } message: {
                    Text("Move \(viewModel.selectedContactIDs.count) contacts to the trash?")
                }
                // Batch Restore Confirm
                .alert("Restore to iOS", isPresented: $viewModel.showingBatchRestoreConfirm) {
                    Button("Cancel", role: .cancel) { }
                    Button("Restore") {
                        viewModel.batchRestore(allContacts: allContacts, context: modelContext, editMode: $currentEditMode)
                    }
                } message: {
                    Text("Restore \(viewModel.selectedContactIDs.count) contacts to the system address book?")
                }
                .onDisappear {
                    currentEditMode = .inactive
                }
                .onAppear {
                    DatabaseUpgrader.upgradeLegacyContacts(modelContext: modelContext)
                }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        let grouped = viewModel.groupedContacts(from: filteredContacts, sortOrder: sortOrder)
        let keys = viewModel.sortedKeys(for: grouped)
        
        ContactListView(
            keys: keys,
            grouped: grouped,
            viewModel: viewModel,
            showImages: showImages
        )
        .safeAreaInset(edge: .bottom) {
            FloatingBottomBar(searchText: $searchText, onAddContact: {
                viewModel.showingContactPicker = true
            })
        }
        .navigationTitle("Contacts")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $shareItem) { item in
            ActivityViewController(activityItems: [item.url])
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation {
                            if currentEditMode.isEditing {
                                viewModel.selectedContactIDs.removeAll()
                                currentEditMode = .inactive
                            } else {
                                currentEditMode = .active
                            }
                        }
                    }) {
                        Text(currentEditMode.isEditing ? "Done" : "Edit")
                    }
                }
            }
            if currentEditMode.isEditing == false {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            } else {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingBatchRestoreConfirm = true }) {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundColor(viewModel.selectedContactIDs.isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.selectedContactIDs.isEmpty)
                    
                    Button(action: { 
                        let selectedContacts = allContacts.filter { viewModel.selectedContactIDs.contains($0.id) }
                        if let url = ExportService.shared.generateCSV(from: selectedContacts) {
                            shareItem = ShareItem(url: url)
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
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
                if let imageData = contact.avatarData, let uiImage = UIImage(data: imageData) {
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
}

struct FloatingBottomBar: View {
    @Binding var searchText: String
    let onAddContact: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
            
            TextField("Search contacts...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)
            
            Button(action: onAddContact) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}

struct ContactListView: View {
    let keys: [String]
    let grouped: [String: [BlackbookContact]]
    @ObservedObject var viewModel: AgendaViewModel
    let showImages: Bool
    
    var body: some View {
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
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}
