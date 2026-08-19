import Foundation
import SwiftData

@Model
final class BlackbookContact {
    var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    var organizationName: String = ""
    var phoneNumbers: [String] = []
    var isTrashed: Bool = false
    var contactData: Data? = nil
    var thumbnailData: Data? = nil
    
    var displayName: String {
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        if fullName.isEmpty && !organizationName.isEmpty {
            return organizationName
        } else if fullName.isEmpty {
            return "Unknown"
        }
        return fullName
    }
    
    var sortName: String {
        if firstName.isEmpty && lastName.isEmpty && !organizationName.isEmpty {
            return organizationName
        }
        
        let sortOrder = UserDefaults.standard.string(forKey: "sortOrder") ?? "Last Name"
        if sortOrder == "First Name" {
            return firstName.isEmpty ? lastName : firstName
        } else {
            return lastName.isEmpty ? firstName : lastName
        }
    }
    
    var sortInitial: String {
        guard let firstChar = sortName.first else { return "#" }
        return String(firstChar).uppercased()
    }
    
    init(firstName: String, lastName: String, organizationName: String = "", phoneNumbers: [String], isTrashed: Bool = false, contactData: Data? = nil, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.organizationName = organizationName
        self.phoneNumbers = phoneNumbers
        self.isTrashed = isTrashed
        self.contactData = contactData
        self.thumbnailData = thumbnailData
    }
}
