# XcodeGen Rules

When working on this project, `xcodegen` is used to manage and generate the Xcode project.
- **NEVER** manually edit the `Info.plist` file. Any manual changes will be silently overwritten the next time `xcodegen generate` is executed.
- Instead, all `Info.plist` properties (such as `NSContactsUsageDescription` or other privacy keys) MUST be defined directly inside the `project.yml` file under the `info: properties:` block.

# Data Safety & Schema Migrations

- **NEVER** recommend deleting the app from the device/simulator to resolve CoreData/SwiftData schema crashes if the app holds data that acts as the sole source of truth (e.g., contacts that were removed from the iOS system).
- Deleting the app destroys its sandbox and all local data permanently.
- Always evaluate if a schema change can be handled via automatic lightweight migration (e.g., by adding new fields as Optionals) before suggesting destructive actions. If data loss is unavoidable, you MUST explicitly warn the user and wait for their confirmation.
