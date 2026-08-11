import SwiftUI
import SwiftData

@main
struct BlackbookApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                authManager.isAuthenticated = false
            }
        }
        .modelContainer(sharedModelContainer)
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
    var body: some View {
        TabView {
            AgendaView()
                .tabItem {
                    Label("Agenda", systemImage: "book")
                }
            
            TrashView()
                .tabItem {
                    Label("Trash", systemImage: "trash")
                }
        }
    }
}
