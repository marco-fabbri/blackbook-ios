import SwiftUI
import SwiftData

struct SearchView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .padding()
                Text("Ricerca in arrivo")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .navigationTitle("Cerca")
        }
    }
}
