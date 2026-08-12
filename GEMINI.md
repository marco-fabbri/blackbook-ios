# XcodeGen Rules

When working on this project, `xcodegen` is used to manage and generate the Xcode project.
- **NEVER** manually edit the `Info.plist` file. Any manual changes will be silently overwritten the next time `xcodegen generate` is executed.
- Instead, all `Info.plist` properties (such as `NSContactsUsageDescription` or other privacy keys) MUST be defined directly inside the `project.yml` file under the `info: properties:` block.
