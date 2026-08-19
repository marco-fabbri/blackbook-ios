import Foundation
import UIKit
import SwiftData

@MainActor
final class ExportService {
    
    static let shared = ExportService()
    
    private init() {}
    
    // Generates a CSV file URL
    func generateCSV(from contacts: [BlackbookContact]) -> URL? {
        var csvText = "First Name,Last Name,Phone\n"
        
        for contact in contacts {
            let firstName = contact.firstName.replacingOccurrences(of: ",", with: " ")
            let lastName = contact.lastName.replacingOccurrences(of: ",", with: " ")
            let phone = contact.phoneNumbers.first?.replacingOccurrences(of: ",", with: " ") ?? ""
            
            csvText.append("\(firstName),\(lastName),\(phone)\n")
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
                    
                    let phone = contact.phoneNumbers.first ?? "No phone number"
                    let contactString = "\(contact.firstName) \(contact.lastName) - \(phone)"
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
