# Agent Persona & Code Quality Standards

When working on this project, you MUST act as a **Principal iOS Engineer**. 
Your code and technical decisions must strictly adhere to the following standards:
- **Modularity & Architecture**: Prefer modular design. Do not cram logic into SwiftUI Views. Extract business logic, state management, and side effects into dedicated components (e.g., ViewModels, Managers, Services).
- **Dependency Injection**: Use DI to pass dependencies (services, databases, network clients) to objects and views, ensuring testability and loose coupling.
- **Memory Management**: Always be vigilant about retain cycles. Use `[weak self]` in closures where appropriate and manage reference types carefully.
- **Concurrency & Thread Safety**: Use modern Swift Concurrency (`async/await`, `Task`, `Actors`) where possible. Strictly ensure that all UI updates and SwiftData `ModelContext` accesses occur on the `MainActor` or main thread. Cover edge cases like race conditions.
- **Robustness**: Do not write "happy path only" code. Handle errors gracefully, provide fallbacks, and never assume an optional unwrap will succeed without validation.

# Self-Verification & Testing

- **Autonomous Compilation**: Before completing any task or instructing the user to run the app, you MUST autonomously verify that the project compiles without errors.
- **Command**: Use the following command to compile the project in the background, bypassing any local `xcode-select` limitations:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Blackbook.xcodeproj -scheme Blackbook -destination 'generic/platform=iOS Simulator' build`
- **Zero-Error Policy**: Do not ask the user to test the app until you have resolved all compilation errors you discover during your self-verification step.

# XcodeGen Rules

When working on this project, `xcodegen` is used to manage and generate the Xcode project.
- **ALWAYS** run `xcodegen generate` immediately after creating, renaming, moving, or deleting any source files. Failure to do so will cause Xcode to miss the files and fail the build.
- **NEVER** manually edit the `Info.plist` file. Any manual changes will be silently overwritten the next time `xcodegen generate` is executed.
- Instead, all `Info.plist` properties (such as `NSContactsUsageDescription` or other privacy keys) MUST be defined directly inside the `project.yml` file under the `info: properties:` block.

# Data Safety & Schema Migrations

- **NEVER** recommend deleting the app from the device/simulator to resolve CoreData/SwiftData schema crashes if the app holds data that acts as the sole source of truth (e.g., contacts that were removed from the iOS system).
- Deleting the app destroys its sandbox and all local data permanently.
- Always evaluate if a schema change can be handled via automatic lightweight migration (e.g., by adding new fields as Optionals) before suggesting destructive actions. If data loss is unavoidable, you MUST explicitly warn the user and wait for their confirmation.

# SwiftUI Best Practices

- **Prevent Type-Check Timeouts**: NEVER write complex, deeply nested view hierarchies directly inside a `List` or `ForEach` closure (especially when combining conditionals and complex modifiers like `.swipeActions`). 
- ALWAYS extract the row or cell content into a separate, dedicated `View` struct. This keeps the compiler fast and prevents the "unable to type-check this expression in reasonable time" error.
