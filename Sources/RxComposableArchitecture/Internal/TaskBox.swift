final class TaskBox<Wrapped> {
    var wrappedValue: Wrapped
    
    init(wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }
    
    var boxedValue: Wrapped {
        _read { yield self.wrappedValue }
        _modify { yield &self.wrappedValue }
    }
}
