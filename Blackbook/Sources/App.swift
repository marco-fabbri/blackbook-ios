import SwiftUI
import SwiftData
import Contacts

@main
struct BlackbookApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @AppStorage("appTheme") private var appTheme = "Sistema"
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BlackbookContact.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                } else {
                    LockScreenView(authManager: authManager)
                }
            }
            .preferredColorScheme(colorScheme)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                let isFaceIDEnabled = UserDefaults.standard.bool(forKey: "isFaceIDEnabled")
                if isFaceIDEnabled {
                    authManager.isAuthenticated = false
                }
            }
            .task {
                // Request contacts permission at startup
                _ = try? await CNContactStore().requestAccess(for: .contacts)
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "Chiaro": return .light
        case "Scuro": return .dark
        default: return nil
        }
    }
}

struct LockScreenView: View {
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack {
            Image(systemName: "lock.shield")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
                .padding(.bottom, 20)
            
            Text("Blackbook is locked")
                .font(.title)
                .padding(.bottom, 30)
            
            Button(action: {
                authManager.authenticate()
            }) {
                Text("Unlock")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .onAppear {
            authManager.authenticate()
        }
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            AgendaView()
                .tabItem {
                    Label("Contatti", systemImage: "person.crop.circle")
                }
                
            SettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gear")
                }
        }
        .onAppear {
            DatabaseUpgrader.upgradeLegacyContacts(modelContext: modelContext)
        }
    }
}
