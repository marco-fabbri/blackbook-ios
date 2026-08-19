import Foundation
import SwiftData
import Contacts

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
    
    var avatarData: Data? {
        if let thumbnailData { return thumbnailData }
        guard let contactData,
              let contact = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CNContact.self, from: contactData) else {
            return nil
        }
        if contact.isKeyAvailable(CNContactThumbnailImageDataKey), let data = contact.thumbnailImageData {
            return data
        }
        if contact.isKeyAvailable(CNContactImageDataKey), let data = contact.imageData {
            return data
        }
        return nil
    }
    
    var sortName: String {
        let sortOrder = UserDefaults.standard.string(forKey: "sortOrder") ?? "Last Name"
        return sortName(for: sortOrder)
    }
    
    func sortName(for sortOrder: String) -> String {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        let trimmedOrg = organizationName.trimmingCharacters(in: .whitespaces)
        
        if trimmedFirst.isEmpty && trimmedLast.isEmpty && !trimmedOrg.isEmpty {
            return trimmedOrg
        }
        
        if sortOrder == "First Name" {
            if !trimmedFirst.isEmpty { return trimmedFirst }
            if !trimmedLast.isEmpty { return trimmedLast }
            return trimmedOrg
        } else {
            if !trimmedLast.isEmpty { return trimmedLast }
            if !trimmedFirst.isEmpty { return trimmedFirst }
            return trimmedOrg
        }
    }
    
    var sortInitial: String {
        let sortOrder = UserDefaults.standard.string(forKey: "sortOrder") ?? "Last Name"
        return sortInitial(for: sortOrder)
    }
    
    func sortInitial(for sortOrder: String) -> String {
        guard let firstChar = sortName(for: sortOrder).first, firstChar.isLetter else { return "#" }
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
