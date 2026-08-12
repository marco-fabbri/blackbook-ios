import SwiftUI
import SwiftData
import Contacts
import ContactsUI

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) private var presentationMode
    
    var blackbookContact: BlackbookContact
    @State private var showingRestoreError = false
    @State private var showingRestoreConfirm = false
    @State private var errorMessage = ""
    
    var systemContact: CNContact? {
        if let data = blackbookContact.contactData,
           let contact = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CNContact.self, from: data) {
            return contact
        }
        return nil
    }
    
    var body: some View {
        VStack {
            if let contact = systemContact {
                SystemContactDetailView(contact: contact)
            } else {
                Text("Dettagli originali non disponibili")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(blackbookContact.firstName)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingRestoreConfirm = true }) {
                    Label("Riporta su iOS", systemImage: "arrow.up.doc")
                }
            }
        }
        .alert("Errore", isPresented: $showingRestoreError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Ripristina su iOS", isPresented: $showingRestoreConfirm) {
            Button("Annulla", role: .cancel) { }
            Button("Ripristina", role: .destructive) {
                restoreContact()
            }
        } message: {
            Text("Attenzione: questo contatto verrà reinserito nella rubrica di iOS e RIMOSSO definitivamente da Blackbook. Vuoi procedere?")
        }
    }
    
    private func restoreContact() {
        Task {
            do {
                try await ContactSyncService().restoreToSystem(blackbookContact: blackbookContact, modelContext: modelContext)
                presentationMode.wrappedValue.dismiss()
            } catch {
                self.errorMessage = error.localizedDescription
                self.showingRestoreError = true
            }
        }
    }
}

struct SystemContactDetailView: UIViewControllerRepresentable {
    var contact: CNContact
    
    func makeUIViewController(context: Context) -> CNContactViewController {
        let vc = CNContactViewController(forUnknownContact: contact)
        vc.allowsEditing = false
        vc.allowsActions = true // Permette di chiamare/messaggiare se possibile
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CNContactViewController, context: Context) { }
}
