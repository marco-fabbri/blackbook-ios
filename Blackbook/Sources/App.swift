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
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            Group {
                switch selectedTab {
                case 0:
                    AgendaView()
                case 1:
                    SettingsView()
                case 2:
                    SearchView()
                default:
                    AgendaView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 60) // Make room for the custom tab bar
            
            // Custom Tab Bar
            HStack {
                TabBarButton(icon: "person.crop.circle", title: "Contatti", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                TabBarButton(icon: "gear", title: "Impostazioni", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                Spacer()
                
                TabBarButton(icon: "magnifyingglass", title: "Cerca", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(
                Color(UIColor.systemBackground)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
            )
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            DatabaseUpgrader.upgradeLegacyContacts(modelContext: modelContext)
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .blue : .gray)
            .frame(minWidth: 50)
        }
    }
}
