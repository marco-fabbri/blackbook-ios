import SwiftUI
import SwiftData
import Contacts

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) private var presentationMode
    
    @Bindable var blackbookContact: BlackbookContact
    @State private var showingRestoreError = false
    @State private var showingRestoreConfirm = false
    @State private var showingEditSheet = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    if let data = blackbookContact.avatarData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    }
                    
                    Text(blackbookContact.displayName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Quick Actions
                HStack(spacing: 24) {
                    if let firstPhone = blackbookContact.phoneNumbers.first {
                        QuickActionButton(title: "Message", systemImage: "message.fill", color: .blue) {
                            if let url = URL(string: "sms://\(firstPhone.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(url)
                            }
                        }
                        
                        QuickActionButton(title: "Call", systemImage: "phone.fill", color: .green) {
                            if let url = URL(string: "tel://\(firstPhone.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Phone Numbers List
                VStack(spacing: 0) {
                    ForEach(blackbookContact.phoneNumbers, id: \.self) { phone in
                        VStack(alignment: .leading) {
                            Text("Mobile") // default label
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(phone)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        
                        if phone != blackbookContact.phoneNumbers.last {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Extra actions
                VStack(spacing: 0) {
                    Button(action: { showingRestoreConfirm = true }) {
                        Text("Restore to iOS")
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                }
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ContactEditView(blackbookContact: blackbookContact)
        }
        .alert("Error", isPresented: $showingRestoreError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Restore to iOS", isPresented: $showingRestoreConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                restoreContact()
            }
        } message: {
            Text("Warning: this contact will be restored to the iOS address book and permanently REMOVED from Blackbook. Proceed?")
        }
    }
    
    private func restoreContact() {
        Task {
            do {
                try await ContactSyncService().restoreToSystem(blackbookContact: blackbookContact, modelContext: modelContext)
                presentationMode.wrappedValue.dismiss()
            } catch {
                self.errorMessage = error.localizedDescription
                self.showingRestoreError = true
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .foregroundColor(color)
            .cornerRadius(10)
        }
    }
}
