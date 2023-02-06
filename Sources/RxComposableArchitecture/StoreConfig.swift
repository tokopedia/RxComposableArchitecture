public struct StoreConfig {
    public var useNewScope: () -> Bool
    public var mainThreadChecksEnabled: () -> Bool
    public var cancelsEffectsOnDeinit: () -> Bool
    
    public init(
        useNewScope: @escaping () -> Bool,
        mainThreadChecksEnabled: @escaping () -> Bool,
        cancelsEffectsOnDeinit: @escaping () -> Bool
    ) {
        self.useNewScope = useNewScope
        self.mainThreadChecksEnabled = mainThreadChecksEnabled
        self.cancelsEffectsOnDeinit = cancelsEffectsOnDeinit
    }
}

extension StoreConfig {
    public static var `default`: StoreConfig = .init(
        useNewScope: { true },
        mainThreadChecksEnabled: { true },
        cancelsEffectsOnDeinit: { true }
    )
}
