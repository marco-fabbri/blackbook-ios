# Blackbook

Blackbook is a privacy-first iOS application designed to manage a secondary, secure address book parallel to your system's contacts. 

> **Note:** This project was originally created as a playground to test and demonstrate the capabilities of the **Antigravity CLI** and its AI-driven development workflows. I'm open-sourcing it so that anyone interested can fork it, explore the code, or use it as a foundation for their own projects.

## Features

- **Isolated Address Book**: Keep a separate list of contacts that are securely stored within the app and removed from the iOS system address book.
- **Biometric Security**: Optionally require Face ID or Touch ID to unlock the app and view your private contacts.
- **Seamless Import/Restore**: Select contacts from your iOS address book to import into Blackbook (which deletes them from the system). At any time, you can restore them back to iOS.
- **Export Capabilities**: Export your Blackbook contacts to CSV or PDF for backup and sharing.
- **Trash Management**: Deleted contacts are moved to a Trash bin, where they can be permanently deleted or restored to the active agenda.
- **Modern iOS Stack**: Built with SwiftUI, SwiftData, and modern Swift Concurrency.

## Architecture & Code Highlights

- **MVVM Architecture**: Strict separation of concerns using ViewModels for state management and business logic.
- **Dependency Injection**: Services like `ContactSyncService` and `ExportService` are decoupled for testability.
- **MainActor & Concurrency**: Proper usage of `@MainActor` and `Task` to handle UI updates and SwiftData context operations without blocking the main thread.
- **Data Persistence**: Uses `SwiftData` for local persistence with CloudKit auto-sync configured (`cloudKitDatabase: .automatic`).
- **XcodeGen**: The project is generated and managed using `xcodegen`.

## Getting Started

### Requirements
- Xcode 15.0+
- iOS 17.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/marco-fabbri/blackbook-ios.git
   cd blackbook-ios
   ```
2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
3. Open `Blackbook.xcodeproj` and build the project.

## License

This project is open-source and available for anyone to use, modify, and distribute. Feel free to fork it!
