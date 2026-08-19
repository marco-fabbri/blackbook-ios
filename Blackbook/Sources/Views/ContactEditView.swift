import SwiftUI
import Contacts
import SwiftData

struct ContactEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var blackbookContact: BlackbookContact
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var organizationName: String = ""
    @State private var phoneNumbers: [String] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("First and Last Name")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Company", text: $organizationName)
                }
                
                Section(header: Text("Phone Numbers")) {
                    ForEach(phoneNumbers.indices, id: \.self) { index in
                        TextField("Phone", text: $phoneNumbers[index])
                            .keyboardType(.phonePad)
                    }
                    .onDelete { indices in
                        phoneNumbers.remove(atOffsets: indices)
                    }
                    
                    Button(action: {
                        phoneNumbers.append("")
                    }) {
                        Label("Add Phone Number", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                firstName = blackbookContact.firstName
                lastName = blackbookContact.lastName
                organizationName = blackbookContact.organizationName
                phoneNumbers = blackbookContact.phoneNumbers
            }
        }
    }
    
    private func saveChanges() {
        // Clean empty phone numbers
        let cleanedPhones = phoneNumbers.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        blackbookContact.firstName = firstName
        blackbookContact.lastName = lastName
        blackbookContact.organizationName = organizationName
        blackbookContact.phoneNumbers = cleanedPhones
        
        // Update CNContact data archive so exports/restores reflect changes
        let mutableContact: CNMutableContact
        if let data = blackbookContact.contactData,
           let oldContact = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CNContact.self, from: data),
           let copy = oldContact.mutableCopy() as? CNMutableContact {
            mutableContact = copy
        } else {
            mutableContact = CNMutableContact()
        }
        
        mutableContact.givenName = firstName
        mutableContact.familyName = lastName
        mutableContact.organizationName = organizationName
        
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
        
        try? modelContext.save()
    }
}
