import SwiftUI
import SwiftData

enum AppTheme: String, CaseIterable {
    case system = "Sistema"
    case light = "Chiaro"
    case dark = "Scuro"
}

enum SortOrder: String, CaseIterable {
    case firstName = "Nome"
    case lastName = "Cognome"
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct SettingsView: View {
    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled = false
    @AppStorage("sortOrder") private var sortOrder = SortOrder.lastName.rawValue
    @AppStorage("showListImages") private var showListImages = true
    @AppStorage("appTheme") private var appTheme = AppTheme.system.rawValue
    
    @Query(filter: #Predicate<BlackbookContact> { $0.isTrashed == false }) private var activeContacts: [BlackbookContact]
    
    @State private var shareItem: ShareItem?
    
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
                
                Section(header: Text("Esportazione Contatti")) {
                    Button(action: {
                        if let url = ExportService.shared.generateCSV(from: activeContacts) {
                            shareItem = ShareItem(url: url)
                        }
                    }) {
                        Label("Esporta in CSV (Excel)", systemImage: "tablecells")
                    }
                    
                    Button(action: {
                        if let url = ExportService.shared.generatePDF(from: activeContacts) {
                            shareItem = ShareItem(url: url)
                        }
                    }) {
                        Label("Esporta in PDF", systemImage: "doc.richtext")
                    }
                }
                
                Section(header: Text("Informazioni")) {
                    HStack {
                        Text("Versione Software")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    NavigationLink(destination: TrashView()) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Cestino")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .sheet(item: $shareItem) { item in
                ActivityViewController(activityItems: [item.url])
            }
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
