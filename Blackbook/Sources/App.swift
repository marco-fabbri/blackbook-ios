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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)

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
    @State private var searchText = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            Group {
                if selectedTab == 0 {
                    AgendaView(searchText: $searchText)
                } else {
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
            
            // Floating iOS 27 Glass UI
            VStack(spacing: 12) {
                if selectedTab == 0 {
                    // Glass Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Cerca contatti...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.systemBackground).opacity(0.4))
                            .background(.ultraThinMaterial, in: Capsule())
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Glass Tab Bar
                HStack(spacing: 50) {
                    TabBarButton(icon: "person.crop.circle", title: "Contatti", isSelected: selectedTab == 0) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = 0
                        }
                    }
                    
                    TabBarButton(icon: "gear", title: "Impostazioni", isSelected: selectedTab == 1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = 1
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color(UIColor.systemBackground).opacity(0.4))
                        .background(.ultraThinMaterial, in: Capsule())
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            }
            .padding(.bottom, 24)
        }
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
