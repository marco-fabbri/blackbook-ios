import SwiftUI
import SwiftData

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

enum SortOrder: String, CaseIterable {
    case firstName = "First Name"
    case lastName = "Last Name"
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
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingRestoreAllConfirm = false
    @State private var isRestoring = false
    @State private var showingRestoreError = false
    @State private var restoreErrorMessage = ""
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        Form {
                Section(header: Text("Security")) {
                    Toggle("Require Face ID / Passcode", isOn: $isFaceIDEnabled)
                }
                
                Section(header: Text("Appearance and List")) {
                    Picker("App Theme", selection: $appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme.rawValue)
                        }
                    }
                    
                    Picker("Sort contacts by", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { sort in
                            Text(sort.rawValue).tag(sort.rawValue)
                        }
                    }
                    
                    Toggle("Show photos in list", isOn: $showListImages)
                }
                
                Section(header: Text("Export Contacts")) {
                    Button(action: {
                        if let url = ExportService.shared.generateCSV(from: activeContacts) {
                            shareItem = ShareItem(url: url)
                        }
                    }) {
                        Label("Export to CSV (Excel)", systemImage: "tablecells")
                    }
                    
                    Button(action: {
                        if let url = ExportService.shared.generatePDF(from: activeContacts) {
                            shareItem = ShareItem(url: url)
                        }
                    }) {
                        Label("Export to PDF", systemImage: "doc.richtext")
                    }
                }
                
                Section(header: Text("Information")) {
                    HStack {
                        Text("Software Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    NavigationLink(destination: TrashView()) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Trash")
                        }
                        .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        showingRestoreAllConfirm = true
                    }) {
                        HStack {
                            if isRestoring {
                                ProgressView()
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "arrow.uturn.backward.circle")
                            }
                            Text(isRestoring ? "Restoring..." : "Restore all contacts to iOS")
                        }
                        .foregroundColor(isRestoring ? .gray : .blue)
                    }
                    .disabled(isRestoring)
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $shareItem) { item in
                ActivityViewController(activityItems: [item.url])
            }
            .alert("Restore all contacts to iOS", isPresented: $showingRestoreAllConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Restore", role: .destructive) {
                    restoreAllContacts()
                }
            } message: {
                Text("Are you sure you want to restore ALL contacts from Blackbook to the iOS address book? They will be removed from this app.")
            }
            .alert("Restore Error", isPresented: $showingRestoreError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreErrorMessage)
            }
    }
    
    private func restoreAllContacts() {
        isRestoring = true
        let syncService = ContactSyncService()
        let contactsToRestore = activeContacts // or you can fetch all including trashed
        
        Task {
            var errors = [String]()
            for contact in contactsToRestore {
                do {
                    try await syncService.restoreToSystem(blackbookContact: contact, modelContext: modelContext)
                } catch {
                    errors.append(error.localizedDescription)
                }
            }
            
            isRestoring = false
            if !errors.isEmpty {
                restoreErrorMessage = "Some contacts were not restored: \n" + errors.joined(separator: "\n")
                showingRestoreError = true
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
