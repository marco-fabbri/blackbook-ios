import LocalAuthentication
import Foundation

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated: Bool
    
    init() {
        let isFaceIDEnabled = UserDefaults.standard.bool(forKey: "isFaceIDEnabled")
        self.isAuthenticated = !isFaceIDEnabled
    }
    
    func authenticate() {
        let isFaceIDEnabled = UserDefaults.standard.bool(forKey: "isFaceIDEnabled")
        
        if !isFaceIDEnabled {
            DispatchQueue.main.async {
                self.isAuthenticated = true
            }
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock to access Blackbook"
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, authenticationError in
                DispatchQueue.main.async {
                    self?.isAuthenticated = success
                }
            }
        } else {
            DispatchQueue.main.async {
                self.isAuthenticated = true
            }
        }
    }
}
