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
    
    var sortName: String {
        return lastName.isEmpty ? firstName : lastName
    }
    
    var sortInitial: String {
        guard let firstChar = sortName.first else { return "#" }
        return String(firstChar).uppercased()
    }
    
    init(firstName: String, lastName: String, phoneNumbers: [String], isTrashed: Bool = false, contactData: Data? = nil) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
        self.isTrashed = isTrashed
        self.contactData = contactData
    }
}
