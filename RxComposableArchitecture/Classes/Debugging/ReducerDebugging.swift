//
//  ReducerDebugging.swift
//  RxComposableArchitecture
//
//  Created by Wendy Liga on 19/05/20.
//

import CasePaths
import Dispatch

/// Determines how the string description of an action should be printed when using the `.debug()`
/// higher-order reducer.
public enum ActionFormat {
    /// Prints the action in a single line by only specifying the labels of the associated values:
    ///
    ///     Action.screenA(.row(index:, action: .textChanged(query:)))
    case labelsOnly
    /// Prints the action in a multiline, pretty-printed format, including all the labels of
    /// any associated values, as well as the data held in the associated values:
    ///
    ///     Action.screenA(
    ///       ScreenA.row(
    ///         index: 1,
    ///         action: RowAction.textChanged(
    ///           query: "Hi"
    ///         )
    ///       )
    ///     )
    case prettyPrint
}

/// A container for storing action filters.
///
/// The logic behind having this rather than a normal closure is that it allows us to namespace and gather action filters together in a consistent manner.
/// - Note: You should be adding extensions in your modules and exposing common filters you might want to use to focus your debugging work, e.g.
/// ```swift
/// extension ActionFilter where Action == AppAction {
///    static var windowActions: Self {
///        Self(isIncluded: {
///            switch $0 {
///            case .windows:
///                return true
///            default:
///                return false
///            }
///        })
///    }
/// }
/// ```
public struct ActionFilter<Action> {
    private let isIncluded: (Action) -> Bool

    public init(isIncluded: @escaping (Action) -> Bool) {
        self.isIncluded = isIncluded
    }

    public func callAsFunction(_ action: Action) -> Bool {
        isIncluded(action)
    }

    /// Include all actions
    public static var all: Self {
        .init(isIncluded: { _ in true })
    }

    /// negates the filter
    public static func not(_ filter: Self) -> Self {
        .init(isIncluded: { !filter($0) })
    }

    /// Allows all actions except those specified
    public static func allExcept(_ actions: Self...) -> Self {
        allExcept(actions)
    }

    /// Allows all actions except those specified
    public static func allExcept(_ actions: [Self]) -> Self {
        .init(isIncluded: { action in
            !actions.contains(where: { $0(action) })
        })
    }

    /// Allows any of the specified actions
    public static func anyOf(_ actions: Self...) -> Self {
        .anyOf(actions)
    }

    /// Allows any of the specified actions
    public static func anyOf(_ actions: [Self]) -> Self {
        .init(isIncluded: { action in
            actions.contains(where: { $0(action) })
        })
    }
}

extension Reducer {
    /// Prints debug messages describing all received actions and state mutations.
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds.
    ///
    /// - Parameters:
    ///   - prefix: A string with which to prefix all debug messages.
    ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default `DebugEnvironment` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: A reducer that prints debug messages for all received actions.
    public func debug(
        _ prefix: String = "",
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Reducer {
        debug(
            prefix,
            state: { $0 },
            action: .self,
            actionFormat: actionFormat,
            environment: toDebugEnvironment
        )
    }

    /// Prints debug messages describing all received actions.
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds.
    ///
    /// - Parameters:
    ///   - prefix: A string with which to prefix all debug messages.
    ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default `DebugEnvironment` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: A reducer that prints debug messages for all received actions.
    public func debugActions(
        _ prefix: String = "",
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Reducer {
        debug(
            prefix,
            state: { _ in () },
            action: .self,
            actionFormat: actionFormat,
            environment: toDebugEnvironment
        )
    }

    public func debug(
        _ prefix: String = "",
        actionFormat: ActionFormat = .prettyPrint,
        allowedActions: ActionFilter<Action> = .all,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Reducer {
        debug(
            prefix,
            state: { _ in () },
            action: .self,
            actionFormat: actionFormat,
            allowedActions: allowedActions,
            environment: toDebugEnvironment
        )
    }

    /// Prints debug messages describing all received local actions and local state mutations.
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds.
    ///
    /// - Parameters:
    ///   - prefix: A string with which to prefix all debug messages.
    ///   - toLocalState: A function that filters state to be printed.
    ///   - toLocalAction: A case path that filters actions that are printed.
    ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default `DebugEnvironment` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: A reducer that prints debug messages for all received actions.
    public func debug<LocalState, LocalAction>(
        _ prefix: String = "",
        state toLocalState: @escaping (State) -> LocalState,
        action toLocalAction: CasePath<Action, LocalAction>,
        actionFormat: ActionFormat = .prettyPrint,
        allowedActions: ActionFilter<Action> = .all,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Reducer {
        #if DEBUG
            return .init { state, action, environment in
                let previousState = toLocalState(state)
                let effects = self.run(&state, action, environment)
                guard let localAction = toLocalAction.extract(from: action) else { return effects }
                let nextState = toLocalState(state)
                let debugEnvironment = toDebugEnvironment(environment)
                guard allowedActions(action) else {
                    return effects
                }

                return .merge(
                    .fireAndForget {
                        debugEnvironment.queue.async {
                            let actionOutput =
                                actionFormat == .prettyPrint
                                    ? debugOutput(localAction).indent(by: 2)
                                    : debugCaseOutput(localAction).indent(by: 2)
                            let stateOutput =
                                LocalState.self == Void.self
                                    ? ""
                                    : debugDiff(previousState, nextState).map { "\($0)\n" } ?? "  (No state changes)\n"
                            debugEnvironment.printer(
                                """
                                \(prefix.isEmpty ? "" : "\(prefix): ")received action:
                                \(actionOutput)
                                \(stateOutput)
                                """
                            )
                        }
                    },
                    effects
                )
            }
        #else
            return self
        #endif
    }
}

/// An environment for debug-printing reducers.
public struct DebugEnvironment {
    public var printer: (String) -> Void
    public var queue: DispatchQueue

    public init(
        printer: @escaping (String) -> Void = { print($0) },
        queue: DispatchQueue
    ) {
        self.printer = printer
        self.queue = queue
    }

    public init(
        printer: @escaping (String) -> Void = { print($0) }
    ) {
        self.init(printer: printer, queue: _queue)
    }
}

private let _queue = DispatchQueue(
    label: "com.tokopedia.Tokopedia.DebugEnvironment",
    qos: .background
)
