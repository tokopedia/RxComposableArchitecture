//
//  Deprecated.swift
//  RxComposableArchitecture_RxComposableArchitecture
//
//  Created by Jefferson Setiawan on 22/03/21.
//

import Darwin

extension Reducer {
    @available(*, deprecated, renamed: "optional()")
    public var optional: Reducer<State?, Action, Environment> {
        self.optional()
    }

    /// https://github.com/pointfreeco/swift-composable-architecture/pull/641
    @available(*, deprecated, message: "Use the 'IdentifiedArray'-based version, instead.")
    public func forEach<GlobalState, GlobalAction, GlobalEnvironment>(
        state toLocalState: WritableKeyPath<GlobalState, [State]>,
        action toLocalAction: CasePath<GlobalAction, (Int, Action)>,
        environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
        breakpointOnNil: Bool = true,
        _ file: StaticString = #file,
        _ line: UInt = #line
    ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
        .init { globalState, globalAction, globalEnvironment in
            guard let (index, localAction) = toLocalAction.extract(from: globalAction) else {
                return .none
            }
            if index >= globalState[keyPath: toLocalState].endIndex {
                #if DEBUG
                    if breakpointOnNil {
                        fputs(
                            """
                            ---
                            Warning: Reducer.forEach@\(file):\(line)

                            "\(debugCaseOutput(localAction))" was received by a "forEach" reducer at index \
                            \(index) when its state contained no element at this index. This is generally \
                            considered an application logic error, and can happen for a few reasons:

                            * This "forEach" reducer was combined with or run from another reducer that removed \
                            the element at this index when it handled this action. To fix this make sure that \
                            this "forEach" reducer is run before any other reducers that can move or remove \
                            elements from state. This ensures that "forEach" reducers can handle their actions \
                            for the element at the intended index.

                            * An in-flight effect emitted this action while state contained no element at this \
                            index. While it may be perfectly reasonable to ignore this action, you may want to \
                            cancel the associated effect when moving or removing an element. If your "forEach" \
                            reducer returns any long-living effects, you should use the identifier-based \
                            "forEach" instead.

                            * This action was sent to the store while its state contained no element at this \
                            index. To fix this make sure that actions for this reducer can only be sent to a \
                            view store when its state contains an element at this index. In SwiftUI \
                            applications, use "ForEachStore".
                            ---

                            """,
                            stderr
                        )
                        raise(SIGTRAP)
                    }
                #endif
                return .none
            }
            return self.run(
                &globalState[keyPath: toLocalState][index],
                localAction,
                toLocalEnvironment(globalEnvironment)
            )
            .map { toLocalAction.embed((index, $0)) }
        }
    }
}

extension Reducer where State: HashDiffable {
    /// https://github.com/pointfreeco/swift-composable-architecture/pull/641
    @available(*, deprecated, message: "Use the 'IdentifiedArray'-based version, instead.")
    public func forEach<Identifier, GlobalState, GlobalAction, GlobalEnvironment>(
        state toLocalState: WritableKeyPath<GlobalState, [State]>,
        action toLocalAction: CasePath<GlobalAction, (Identifier, Action)>,
        environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
    ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment>
    where Identifier == State.IdentifierType {
        .init { globalState, globalAction, globalEnvironment in
            guard let (identifier, localAction) = toLocalAction.extract(from: globalAction) else {
                return .none
            }

            // search index of identifier
            guard
                let index = globalState[keyPath: toLocalState].firstIndex(where: {
                    $0.id == identifier
                })
            else {
                assertionFailure("\(identifier) is not exist on Global State")
                return .none
            }

            // return redux
            return self.run(
                &globalState[keyPath: toLocalState][index],
                localAction,
                toLocalEnvironment(globalEnvironment)
            )
            .map { toLocalAction.embed((identifier, $0)) }
        }
    }
}
