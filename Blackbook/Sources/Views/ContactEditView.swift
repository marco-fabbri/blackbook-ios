import SwiftUI
import Contacts
import SwiftData

struct ContactEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var blackbookContact: BlackbookContact
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumbers: [String] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nome e Cognome")) {
                    TextField("Nome", text: $firstName)
                    TextField("Cognome", text: $lastName)
                }
                
                Section(header: Text("Numeri di Telefono")) {
                    ForEach(phoneNumbers.indices, id: \.self) { index in
                        TextField("Telefono", text: $phoneNumbers[index])
                            .keyboardType(.phonePad)
                    }
                    .onDelete { indices in
                        phoneNumbers.remove(atOffsets: indices)
                    }
                    
                    Button(action: {
                        phoneNumbers.append("")
                    }) {
                        Label("Aggiungi numero", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Modifica Contatto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                firstName = blackbookContact.firstName
                lastName = blackbookContact.lastName
                phoneNumbers = blackbookContact.phoneNumbers
            }
        }
    }
    
    private func saveChanges() {
        // Clean empty phone numbers
        let cleanedPhones = phoneNumbers.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        blackbookContact.firstName = firstName
        blackbookContact.lastName = lastName
        blackbookContact.phoneNumbers = cleanedPhones
        
        // Update CNContact data archive so exports/restores reflect changes
        if let data = blackbookContact.contactData,
           let oldContact = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CNContact.self, from: data),
           let mutableContact = oldContact.mutableCopy() as? CNMutableContact {
            
            mutableContact.givenName = firstName
            mutableContact.familyName = lastName
            
            var newPhoneValues: [CNLabeledValue<CNPhoneNumber>] = []
            for phone in cleanedPhones {
                let cnPhone = CNPhoneNumber(stringValue: phone)
                let labeledValue = CNLabeledValue(label: CNLabelPhoneNumberMobile, value: cnPhone)
                newPhoneValues.append(labeledValue)
            }
            mutableContact.phoneNumbers = newPhoneValues
            
            if let newData = try? NSKeyedArchiver.archivedData(withRootObject: mutableContact, requiringSecureCoding: true) {
                blackbookContact.contactData = newData
            }
        }
        
        try? modelContext.save()
    }
}
