# Refactoring Plan (Principal Engineer Standards)

1. **Services & Modern Concurrency**: 
   - Replace the callback-based `ContactSyncManager` singleton with a modern, thread-safe `actor ContactSyncService` using `async/await`.
   - Update all data operations to be strictly concurrent-safe.
2. **MVVM Architecture**:
   - Introduce `AgendaViewModel` and `TrashViewModel`.
   - Move all business logic (batch operations, grouping, sorting, alert state management) out of the SwiftUI Views into testable ViewModels.
3. **Dependency Injection**:
   - Inject the `ContactSyncService` and `ModelContext` into the ViewModels rather than accessing singletons globally.
4. **XcodeGen Management**:
   - Run `xcodegen generate` after creating/deleting files to keep the `.xcodeproj` in sync.
