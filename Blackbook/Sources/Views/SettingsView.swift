import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "Sistema"
    case light = "Chiaro"
    case dark = "Scuro"
}

enum SortOrder: String, CaseIterable {
    case firstName = "Nome"
    case lastName = "Cognome"
}

struct SettingsView: View {
    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled = false
    @AppStorage("sortOrder") private var sortOrder = SortOrder.lastName.rawValue
    @AppStorage("showListImages") private var showListImages = true
    @AppStorage("appTheme") private var appTheme = AppTheme.system.rawValue
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Sconosciuta"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sicurezza")) {
                    Toggle("Richiedi Face ID / Codice", isOn: $isFaceIDEnabled)
                }
                
                Section(header: Text("Aspetto e Lista")) {
                    Picker("Tema App", selection: $appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme.rawValue)
                        }
                    }
                    
                    Picker("Ordina contatti per", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { sort in
                            Text(sort.rawValue).tag(sort.rawValue)
                        }
                    }
                    
                    Toggle("Mostra foto nella lista", isOn: $showListImages)
                }
                
                Section(header: Text("Informazioni")) {
                    HStack {
                        Text("Versione Software")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Impostazioni")
        }
    }
}
