import SwiftUI
import ContactsUI

struct ContactPickerManager: UIViewControllerRepresentable {
    typealias UIViewControllerType = CNContactPickerViewController
    
    var completionHandler: (Result<[CNContact], Error>) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerManager
        
        init(_ parent: ContactPickerManager) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.completionHandler(.success([contact]))
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.completionHandler(.success(contacts))
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.completionHandler(.success([]))
        }
    }
}
