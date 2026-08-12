1. Change selectedContacts to Set<UUID> in both views.
2. Update batch methods to use the UUIDs.
3. Extract the entire cell (with NavigationLink & swipeActions) into a separate View to guarantee fast compile times.
