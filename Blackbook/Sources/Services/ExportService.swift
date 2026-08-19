import Foundation
import UIKit
import SwiftData

@MainActor
final class ExportService {
    
    static let shared = ExportService()
    
    private init() {}
    
    // Generates a CSV file URL
    func generateCSV(from contacts: [BlackbookContact]) -> URL? {
        var csvText = "First Name,Last Name,Company,Phone Numbers\n"
        
        for contact in contacts {
            let firstName = contact.firstName.replacingOccurrences(of: ",", with: " ")
            let lastName = contact.lastName.replacingOccurrences(of: ",", with: " ")
            let company = contact.organizationName.replacingOccurrences(of: ",", with: " ")
            let phones = contact.phoneNumbers.joined(separator: "; ").replacingOccurrences(of: ",", with: " ")
            
            csvText.append("\(firstName),\(lastName),\(company),\(phones)\n")
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("Blackbook_Contacts.csv")
        
        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error generating CSV: \(error)")
            return nil
        }
    }
    
    // Generates a PDF file URL
    func generatePDF(from contacts: [BlackbookContact]) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Blackbook App",
            kCGPDFContextAuthor: "User"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("Blackbook_Contacts.pdf")
        
        do {
            try renderer.writePDF(to: fileURL) { context in
                context.beginPage()
                
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 24)
                ]
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12)
                ]
                
                "Blackbook Contacts".draw(at: CGPoint(x: 20, y: 20), withAttributes: titleAttributes)
                
                var yOffset: CGFloat = 60
                
                for contact in contacts {
                    if yOffset > pageHeight - 50 {
                        context.beginPage()
                        yOffset = 20
                    }
                    
                    let phones = contact.phoneNumbers.isEmpty ? "No phone number" : contact.phoneNumbers.joined(separator: ", ")
                    let contactString = "\(contact.displayName) - \(phones)"
                    contactString.draw(at: CGPoint(x: 20, y: yOffset), withAttributes: textAttributes)
                    yOffset += 20
                }
            }
            return fileURL
        } catch {
            print("Error generating PDF: \(error)")
            return nil
        }
    }
}
