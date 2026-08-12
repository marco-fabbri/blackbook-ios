import Foundation
import SwiftData

@Model
final class BlackbookContact {
    var id: UUID
    var firstName: String
    var lastName: String
    var phoneNumbers: [String]
    var isTrashed: Bool
    var contactData: Data?
    var thumbnailData: Data?
    
    var sortName: String {
        let sortOrder = UserDefaults.standard.string(forKey: "sortOrder") ?? "Cognome"
        if sortOrder == "Nome" {
            return firstName.isEmpty ? lastName : firstName
        } else {
            return lastName.isEmpty ? firstName : lastName
        }
    }
    
    var sortInitial: String {
        guard let firstChar = sortName.first else { return "#" }
        return String(firstChar).uppercased()
    }
    
    init(firstName: String, lastName: String, phoneNumbers: [String], isTrashed: Bool = false, contactData: Data? = nil, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
        self.isTrashed = isTrashed
        self.contactData = contactData
        self.thumbnailData = thumbnailData
    }
}
