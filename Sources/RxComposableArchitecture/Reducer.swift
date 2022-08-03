import CasePaths
import Darwin
import RxSwift

public struct Reducer<State, Action, Environment> {
    private let reducer: (inout State, Action, Environment) -> Effect<Action>

    public init(_ reducer: @escaping (inout State, Action, Environment) -> Effect<Action>) {
        self.reducer = reducer
    }

    public static var empty: Reducer {
        Self { _, _, _ in .none }
    }

    public static func combine(_ reducers: Reducer...) -> Reducer {
        .combine(reducers)
    }

    public static func combine(_ reducers: [Reducer]) -> Reducer {
        Self { value, action, environment in
            .merge(reducers.map { $0.reducer(&value, action, environment) })
        }
    }

    /// Transforms a reducer that works on local state, action and environment into one that works on
    /// global state, action and environment. It accomplishes this by providing 3 transformations to
    /// the method:
    ///
    /// * A writable key path that can get/set a piece of local state from the global state.
    /// * A case path that can extract/embed a local action into a global action.
    /// * A function that can transform the global environment into a local environment.
    ///
    /// This operation is important for breaking down large reducers into small ones. When used with
    /// the `combine` operator you can define many reducers that work on small pieces of domain, and
    /// then _pull them back_ and _combine_ them into one big reducer that works on a large domain.
    ///
    ///     // Global domain that holds a local domain:
    ///     struct AppState { var settings: SettingsState, /* rest of state */ }
    ///     struct AppAction { case settings(SettingsAction), /* other actions */ }
    ///     struct AppEnvironment { var settings: SettingsEnvironment, /* rest of dependencies */ }
    ///
    ///     // A reducer that works on the local domain:
    ///     let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment> { ... }
    ///
    ///     // Pullback the settings reducer so that it works on all of the app domain:
    ///     let appReducer: Reducer<AppState, AppAction, AppEnvironment> = .combine(
    ///       settingsReducer.pullback(
    ///         state: \.settings,
    ///         action: /AppAction.settings,
    ///         environment: { $0.settings }
    ///       ),
    ///
    ///       /* other reducers */
    ///     )
    ///
    /// - Parameters:
    ///   - toLocalState: A writable path (`WritableKeyPath`, `CasePath`, or `OptionalPath`) that can
    ///     get/set `State` inside `GlobalState`.
    ///   - toLocalAction: A writable path (`WritableKeyPath`, `CasePath`, or `OptionalPath`) that can
    ///     get/set `Action` inside `GlobalAction`.
    ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
    /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
    public func pullback<GlobalState, GlobalAction, GlobalEnvironment>(
        state toLocalState: WritableKeyPath<GlobalState, State>,
        action toLocalAction: CasePath<GlobalAction, Action>,
        environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
    ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
        .init { globalState, globalAction, globalEnvironment in
            guard let localAction = toLocalAction.extract(from: globalAction) else { return .none }
            return self.reducer(
                &globalState[keyPath: toLocalState],
                localAction,
                toLocalEnvironment(globalEnvironment)
            )
            .map(toLocalAction.embed)
        }
    }

    public func pullback<GlobalState, GlobalAction, GlobalEnvironment, StatePath, ActionPath>(
        state toLocalState: StatePath,
        action toLocalAction: ActionPath,
        environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
    ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment>
        where
        StatePath: WritablePath, StatePath.Root == GlobalState, StatePath.Value == State,
        ActionPath: WritablePath, ActionPath.Root == GlobalAction, ActionPath.Value == Action {
        return .init { globalState, globalAction, globalEnvironment in
            guard
                var localState = toLocalState.extract(from: globalState),
                let localAction = toLocalAction.extract(from: globalAction)
            else { return .none }
            let effect =
                self
                    .reducer(&localState, localAction, toLocalEnvironment(globalEnvironment))
                    .map { localAction -> GlobalAction in
                        var globalAction = globalAction
                        toLocalAction.set(into: &globalAction, localAction)
                        return globalAction
                    }
            toLocalState.set(into: &globalState, localState)
            return effect
        }
    }

    /// Transforms a reducer that works on non-optional state into one that works on optional state by
    /// only running the non-optional reducer when state is non-nil.
    ///
    /// Often used in tandem with `pullback` to transform a reducer on a non-optional child domain
    /// into a reducer that can be combined with a reducer on a parent domain that contains some
    /// optional child domain:
    ///
    ///     // Global domain that holds an optional local domain:
    ///     struct AppState { var modal: ModalState? }
    ///     enum AppAction { case modal(ModalAction) }
    ///     struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
    ///
    ///     // A reducer that works on the non-optional local domain:
    ///     let modalReducer = Reducer<ModalState, ModalAction, ModalEnvironment { ... }
    ///
    ///     // Pullback the local modal reducer so that it works on all of the app domain:
    ///     let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
    ///       modalReducer.optional().pullback(
    ///         state: \.modal,
    ///         action: /AppAction.modal,
    ///         environment: { ModalEnvironment(mainQueue: $0.mainQueue) }
    ///       ),
    ///       Reducer { state, action, environment in
    ///         ...
    ///       }
    ///     )
    ///
    /// Take care when combining optional reducers into parent domains. An optional reducer cannot
    /// process actions in its domain when its state is `nil`. If a child action is sent to an
    /// optional reducer when child state is `nil`, it is generally considered a logic error. There
    /// are a few ways in which these errors can sneak into a code base:
    ///
    ///   * A parent reducer sets child state to `nil` when processing a child action and runs
    ///     _before_ the child reducer:
    ///
    ///         let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
    ///           // When combining reducers, the parent reducer runs first
    ///           Reducer { state, action, environment in
    ///             switch action {
    ///             case .child(.didDisappear):
    ///               // And `nil`s out child state when processing a child action
    ///               state.child = nil
    ///               return .none
    ///             ...
    ///             }
    ///           },
    ///           // Before the child reducer runs
    ///           childReducer.optional().pullback(...)
    ///         )
    ///
    ///         let childReducer = Reducer<
    ///           ChildState, ChildAction, ChildEnvironment
    ///         > { state, action environment in
    ///           case .didDisappear:
    ///             // This action is never received here because child state is `nil` in the parent
    ///           ...
    ///         }
    ///
    ///     To ensure that a child reducer can process any action that a parent may use to `nil` out
    ///     its state, combine it _before_ the parent:
    ///
    ///         let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
    ///           // The child runs first
    ///           childReducer.optional().pullback(...),
    ///           // The parent runs after
    ///           Reducer { state, action, environment in
    ///             ...
    ///           }
    ///         )
    ///
    ///   * A child effect feeds a child action back into the store when child state is `nil`:
    ///
    ///         let childReducer = Reducer<
    ///           ChildState, ChildAction, ChildEnvironment
    ///         > { state, action environment in
    ///           switch action {
    ///           case .onAppear:
    ///             // An effect may want to feed its result back to the child domain in an action
    ///             return environment.apiClient
    ///               .request()
    ///               .map(ChildAction.response)
    ///
    ///           case let .response(response):
    ///             // But the child cannot process this action if its state is `nil` in the parent
    ///           ...
    ///           }
    ///         }
    ///
    ///     It is perfectly reasonable to ignore the result of an effect when child state is `nil`,
    ///     for example one-off effects that you don't want to cancel. However, many long-living
    ///     effects _should_ be explicitly canceled when tearing down a child domain:
    ///
    ///         let childReducer = Reducer<
    ///           ChildState, ChildAction, ChildEnvironment
    ///         > { state, action environment in
    ///           struct MotionId: Hashable {}
    ///
    ///           switch action {
    ///           case .onAppear:
    ///             // Mark long-living effects that shouldn't outlive their domain cancellable
    ///             return environment.motionClient
    ///               .start()
    ///               .map(ChildAction.motion)
    ///               .cancellable(id: MotionId())
    ///
    ///           case .onDisappear:
    ///             // And explicitly cancel them when the domain is torn down
    ///             return .cancel(id: MotionId())
    ///           ...
    ///           }
    ///         }
    ///
    ///   * A view store sends a child action when child state is `nil`:
    ///
    ///         WithViewStore(self.parentStore) { parentViewStore in
    ///           // If child state is `nil`, it cannot process this action.
    ///           Button("Child Action") { parentViewStore.send(.child(.action)) }
    ///           ...
    ///         }
    ///
    ///     Use `Store.scope` with`IfLetStore` or `Store.ifLet` to ensure that views can only send
    ///     child actions when the child domain is non-`nil`.
    ///
    ///         IfLetStore(
    ///           self.parentStore.scope(state: { $0.child }, action: { .child($0) }
    ///         ) { childStore in
    ///           // This destination only appears when child state is non-`nil`
    ///           WithViewStore(childStore) { childViewStore in
    ///             // So this action can only be sent when child state is non-`nil`
    ///             Button("Child Action") { childViewStore.send(.action) }
    ///           }
    ///           ...
    ///         }
    ///
    /// - See also: `IfLetStore`, a SwiftUI helper for transforming a store on optional state into a
    ///   store on non-optional state.
    /// - See also: `Store.ifLet`, a UIKit helper for doing imperative work with a store on optional
    ///   state.
    ///
    /// - Parameter breakpointOnNil: Raises `SIGTRAP` signal when an action is sent to the reducer
    ///   but state is `nil`. This is generally considered a logic error, as a child reducer cannot
    ///   process a child action for unavailable child state.
    /// - Returns: A reducer that works on optional state.
    public func optional(
        breakpointOnNil: Bool = true,
        _ file: StaticString = #file,
        _ line: UInt = #line
    ) -> Reducer<
        State?, Action, Environment
    > {
        .init { state, action, environment in
            guard state != nil else {
                #if DEBUG
                    if breakpointOnNil {
                        fputs(
                            """
                            ---
                            Warning: Reducer.optional@\(file):\(line)

                            "\(debugCaseOutput(action))" was received by an optional reducer when its state was \
                            "nil". This is generally considered an application logic error, and can happen for a \
                            few reasons:

                            * The optional reducer was combined with or run from another reducer that set \
                            "\(State.self)" to "nil" before the optional reducer ran. Combine or run optional \
                            reducers before reducers that can set their state to "nil". This ensures that \
                            optional reducers can handle their actions while their state is still non-"nil".

                            * An in-flight effect emitted this action while state was "nil". While it may be \
                            perfectly reasonable to ignore this action, you may want to cancel the associated \
                            effect before state is set to "nil", especially if it is a long-living effect.

                            * This action was sent to the store while state was "nil". Make sure that actions \
                            for this reducer can only be sent to a view store when state is non-"nil". In \
                            SwiftUI applications, use "IfLetStore".
                            ---

                            """,
                            stderr
                        )
                        raise(SIGTRAP)
                    }
                #endif
                return .none
            }
            return self.reducer(&state!, action, environment)
        }
    }

    /// A version of `pullback` that transforms a reducer that works on an element into one that works
    /// on a collection of elements.
    ///
    ///     // Global domain that holds a collection of local domains:
    ///     struct AppState { var todos: [Todo] }
    ///     enum AppAction { case todo(index: Int, action: TodoAction) }
    ///     struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
    ///
    ///     // A reducer that works on a local domain:
    ///     let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { ... }
    ///
    ///     // Pullback the local todo reducer so that it works on all of the app domain:
    ///     let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
    ///       todoReducer.forEach(
    ///         state: \.todos,
    ///         action: /AppAction.todo(index:action:),
    ///         environment: { _ in TodoEnvironment() }
    ///       ),
    ///       Reducer { state, action, environment in
    ///         ...
    ///       }
    ///     )
    ///
    /// Take care when combining `forEach` reducers into parent domains, as order matters. Always
    /// combine `forEach` reducers _before_ parent reducers that can modify the collection.
    ///
    /// - Parameters:
    ///   - toLocalState: A key path that can get/set an array of `State` elements inside.
    ///     `GlobalState`.
    ///   - toLocalAction: A case path that can extract/embed `(Int, Action)` from `GlobalAction`.
    ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
    ///   - breakpointOnNil: Raises `SIGTRAP` signal when an action is sent to the reducer but the
    ///     index is out of bounds. This is generally considered a logic error, as a child reducer
    ///     cannot process a child action for unavailable child state.
    /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
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
            return self.reducer(
                &globalState[keyPath: toLocalState][index],
                localAction,
                toLocalEnvironment(globalEnvironment)
            )
            .map { toLocalAction.embed((index, $0)) }
        }
    }

    public func forEach<GlobalState, GlobalAction, GlobalEnvironment, Key>(
        state toLocalState: WritableKeyPath<GlobalState, [Key: State]>,
        action toLocalAction: CasePath<GlobalAction, (Key, Action)>,
        environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
        breakpointOnNil: Bool = true,
        _ file: StaticString = #file,
        _ line: UInt = #line
    ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
        .init { globalState, globalAction, globalEnvironment in
            guard let (key, localAction) = toLocalAction.extract(from: globalAction) else { return .none }
            if globalState[keyPath: toLocalState][key] == nil {
                #if DEBUG
                    if breakpointOnNil {
                        fputs(
                            """
                            ---
                            Warning: Reducer.forEach@\(file):\(line)

                            "\(debugCaseOutput(localAction))" was received by a "forEach" reducer at key \(key) \
                            when its state contained no element at this key. This is generally considered an \
                            application logic error, and can happen for a few reasons:

                            * This "forEach" reducer was combined with or run from another reducer that removed \
                            the element at this key when it handled this action. To fix this make sure that this \
                            "forEach" reducer is run before any other reducers that can move or remove elements \
                            from state. This ensures that "forEach" reducers can handle their actions for the \
                            element at the intended key.

                            * An in-flight effect emitted this action while state contained no element at this \
                            key. It may be perfectly reasonable to ignore this action, but you also may want to \
                            cancel the effect it originated from when removing a value from the dictionary, \
                            especially if it is a long-living effect.

                            * This action was sent to the store while its state contained no element at this \
                            key. To fix this make sure that actions for this reducer can only be sent to a view \
                            store when its state contains an element at this key.
                            ---

                            """,
                            stderr
                        )
                        raise(SIGTRAP)
                    }
                #endif
                return .none
            }
            return self.reducer(
                &globalState[keyPath: toLocalState][key]!,
                localAction,
                toLocalEnvironment(globalEnvironment)
            )
            .map { toLocalAction.embed((key, $0)) }
        }
    }

    /// A version of `pullback` that transforms a reducer that works on an element into one that works
    /// on an identified array of elements.
    ///
    ///     // Global domain that holds a collection of local domains:
    ///     struct AppState { var todos: IdentifiedArrayOf<Todo> }
    ///     enum AppAction { case todo(id: Todo.ID, action: TodoAction) }
    ///     struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
    ///
    ///     // A reducer that works on a local domain:
    ///     let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { ... }
    ///
    ///     // Pullback the local todo reducer so that it works on all of the app domain:
    ///     let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
    ///       todoReducer.forEach(
    ///         state: \.todos,
    ///         action: /AppAction.todo(id:action:),
    ///         environment: { _ in TodoEnvironment() }
    ///       ),
    ///       Reducer { state, action, environment in
    ///         ...
    ///       }
    ///     )
    ///
    /// Take care when combining `forEach` reducers into parent domains, as order matters. Always
    /// combine `forEach` reducers _before_ parent reducers that can modify the collection.
    ///
    /// - Parameters:
    ///   - toLocalState: A key path that can get/set a collection of `State` elements inside
    ///     `GlobalState`.
    ///   - toLocalAction: A case path that can extract/embed `(Collection.Index, Action)` from
    ///     `GlobalAction`.
    ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
    ///   - breakpointOnNil: Raises `SIGTRAP` signal when an action is sent to the reducer but the
    ///     identified array does not contain an element with the action's identifier. This is
    ///     generally considered a logic error, as a child reducer cannot process a child action
    ///     for unavailable child state.
    /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
    public func forEach<GlobalState, GlobalAction, GlobalEnvironment, ID>(
        state toLocalState: WritableKeyPath<GlobalState, IdentifiedArray<ID, State>>,
        action toLocalAction: CasePath<GlobalAction, (ID, Action)>,
        environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
        breakpointOnNil: Bool = true,
        _ file: StaticString = #file,
        _ line: UInt = #line
    ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
        .init { globalState, globalAction, globalEnvironment in
            guard let (id, localAction) = toLocalAction.extract(from: globalAction) else { return .none }
            if globalState[keyPath: toLocalState][id: id] == nil {
                #if DEBUG
                    if breakpointOnNil {
                        fputs(
                            """
                            ---
                            Warning: Reducer.forEach@\(file):\(line)

                            "\(debugCaseOutput(localAction))" was received by a "forEach" reducer at id \(id) \
                            when its state contained no element at this id. This is generally considered an \
                            application logic error, and can happen for a few reasons:

                            * This "forEach" reducer was combined with or run from another reducer that removed \
                            the element at this id when it handled this action. To fix this make sure that this \
                            "forEach" reducer is run before any other reducers that can move or remove elements \
                            from state. This ensures that "forEach" reducers can handle their actions for the \
                            element at the intended id.

                            * An in-flight effect emitted this action while state contained no element at this \
                            id. It may be perfectly reasonable to ignore this action, but you also may want to \
                            cancel the effect it originated from when removing an element from the identified \
                            array, especially if it is a long-living effect.

                            * This action was sent to the store while its state contained no element at this id. \
                            To fix this make sure that actions for this reducer can only be sent to a view store \
                            when its state contains an element at this id. In SwiftUI applications, use \
                            "ForEachStore".
                            ---

                            """,
                            stderr
                        )
                        raise(SIGTRAP)
                    }
                #endif
                return .none
            }
            return
                self
                    .reducer(
                        &globalState[keyPath: toLocalState][id: id]!,
                        localAction,
                        toLocalEnvironment(globalEnvironment)
                    )
                    .map { toLocalAction.embed((id, $0)) }
        }
    }

    public func combined(with other: Reducer) -> Reducer {
        .combine(self, other)
    }

    /// Runs the reducer.
    ///
    /// - Parameters:
    ///   - state: Mutable state.
    ///   - action: An action.
    ///   - environment: An environment.
    ///   - debug: any additional action when executing reducer
    /// - Returns: An effect that can emit zero or more actions.
    public func run(
        _ state: inout State,
        _ action: Action,
        _ environment: Environment,
        _ debug: (State) -> Void = { _ in }
    ) -> Effect<Action> {
        func environmentToUse() -> Environment {
            #if DEBUG
                if let bootstrappedEnvironment = Bootstrap.get(environment: type(of: environment)) {
                    return bootstrappedEnvironment
                } else {
                    return environment
                }
            #else
                return environment
            #endif
        }

        let reducer = reducer(&state, action, environmentToUse())
        debug(state)

        return reducer
    }
}

extension Reducer where State: HashDiffable {
    /**
     Pullback reducer for reducer which store is part of `Differentiable` array.
     */
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
            guard let index = globalState[keyPath: toLocalState].firstIndex(where: { $0.id == identifier })
            else {
                assertionFailure("\(identifier) is not exist on Global State")
                return .none
            }

            // return redux
            return self.reducer(
                &globalState[keyPath: toLocalState][index],
                localAction,
                toLocalEnvironment(globalEnvironment)
            )
            .map { toLocalAction.embed((identifier, $0)) }
        }
    }
}
