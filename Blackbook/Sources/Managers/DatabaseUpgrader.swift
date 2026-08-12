import Foundation
import SwiftData
import Contacts

class DatabaseUpgrader {
    static func upgradeLegacyContacts(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<BlackbookContact>(predicate: #Predicate { $0.contactData == nil })
            let legacyContacts = try modelContext.fetch(descriptor)
            
            guard !legacyContacts.isEmpty else { return }
            
            for contact in legacyContacts {
                let mutableContact = CNMutableContact()
                mutableContact.givenName = contact.firstName
                mutableContact.familyName = contact.lastName
                
                for phone in contact.phoneNumbers {
                    let phoneNumber = CNPhoneNumber(stringValue: phone)
                    let labeledValue = CNLabeledValue(label: CNLabelPhoneNumberMain, value: phoneNumber)
                    mutableContact.phoneNumbers.append(labeledValue)
                }
                
                if let data = try? NSKeyedArchiver.archivedData(withRootObject: mutableContact, requiringSecureCoding: true) {
                    contact.contactData = data
                }
            }
            
            try modelContext.save()
            print("Aggiornati \(legacyContacts.count) contatti legacy al nuovo formato V2.")
            
        } catch {
            print("Errore durante l'upgrade del database: \(error)")
        }
    }
}
