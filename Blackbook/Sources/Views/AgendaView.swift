import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<BlackbookContact> { $0.isTrashed == false }, sort: \BlackbookContact.lastName) private var contacts: [BlackbookContact]
    
    @State private var showingContactPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var groupedContacts: [String: [BlackbookContact]] {
        Dictionary(grouping: contacts, by: { $0.sortInitial })
    }
    
    var sortedKeys: [String] {
        groupedContacts.keys.sorted()
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(sortedKeys, id: \.self) { key in
                    Section(header: Text(key)) {
                        ForEach(groupedContacts[key] ?? []) { contact in
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
                                Button(role: .destructive) {
                                    moveToTrash(contact)
                                } label: {
                                    Label("Trash", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Blackbook")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingContactPicker = true }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPickerManager { result in
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
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func moveToTrash(_ contact: BlackbookContact) {
        contact.isTrashed = true
        try? modelContext.save()
    }
}
