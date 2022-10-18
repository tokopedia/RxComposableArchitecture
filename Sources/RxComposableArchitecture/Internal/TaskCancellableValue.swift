@available(iOS 13.0, *)
extension Task where Failure == Error {
    public var cancellableValue: Success {
        get async throws {
            try await withTaskCancellationHandler {
                self.cancel()
            } operation: {
                try await self.value
            }
        }
    }
}

@available(iOS 13.0, *)
extension Task where Failure == Never {
    public var cancellableValue: Success {
        get async {
            await withTaskCancellationHandler {
                self.cancel()
            } operation: {
                await self.value
            }
        }
    }
}
