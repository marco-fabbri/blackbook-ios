import SwiftUI
import SwiftData
import Contacts
import ContactsUI

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) private var presentationMode
    
    var blackbookContact: BlackbookContact
    @State private var showingRestoreError = false
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
                Button(action: { restoreContact() }) {
                    Label("Riporta su iOS", systemImage: "arrow.up.doc")
                }
            }
        }
        .alert("Errore", isPresented: $showingRestoreError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func restoreContact() {
        ContactSyncManager.shared.restoreToSystem(blackbookContact: blackbookContact, modelContext: modelContext) { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.showingRestoreError = true
            } else {
                self.presentationMode.wrappedValue.dismiss()
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
