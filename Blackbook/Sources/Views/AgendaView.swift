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
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    
    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var isSearchFocused: Bool
    
    var filteredContacts: [BlackbookContact] {
        if searchText.isEmpty {
            return allContacts
        }
        return allContacts.filter { contact in
            contact.firstName.localizedCaseInsensitiveContains(searchText) ||
            contact.lastName.localizedCaseInsensitiveContains(searchText) ||
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
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ActivateSearch"))) { _ in
                    withAnimation {
                        isSearchActive = true
                        isSearchFocused = true
                    }
                }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        let grouped = viewModel.groupedContacts(from: filteredContacts, sortOrder: sortOrder)
        let keys = viewModel.sortedKeys(for: grouped)
        
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if isSearchActive {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Cerca contatti...", text: $searchText)
                            .focused($isSearchFocused)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button("Annulla") {
                            withAnimation {
                                searchText = ""
                                isSearchActive = false
                                isSearchFocused = false
                            }
                        }
                        .padding(.leading, 8)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
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
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let shareURL = shareURL {
                ActivityViewController(activityItems: [shareURL])
            }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                if currentEditMode.isEditing == false {
                    Button(action: { viewModel.showingContactPicker = true }) {
                        Image(systemName: "plus")
                    }
                } else {
                    HStack(spacing: 24) {
                        Button(action: { 
                            let selectedContacts = allContacts.filter { viewModel.selectedContactIDs.contains($0.id) }
                            if let url = ExportService.shared.generateCSV(from: selectedContacts) {
                                shareURL = url
                                showingShareSheet = true
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
                Text("\(contact.firstName) \(contact.lastName)")
                    .font(.headline)
                if let firstPhone = contact.phoneNumbers.first {
                    Text(firstPhone)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
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
