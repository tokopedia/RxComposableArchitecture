import Foundation
import RxRelay
import RxSwift

public final class Store<State, Action> {
    public private(set) var state: State {
        get { relay.value }
        set { relay.accept(newValue) }
    }

    private var isSending = false
    private var synchronousActionsToSend: [Action] = []
    private var bufferedActions: [Action] = []

    private let reducer: (inout State, Action) -> Effect<Action>

    private let disposeBag = DisposeBag()
    internal var effectDisposables = CompositeDisposable()
    private let relay: BehaviorRelay<State>
    
    private let useNewScope: Bool
    
    #if DEBUG
    private let mainThreadChecksEnabled: Bool
    #endif

    public var observable: Observable<State> {
        return relay.asObservable()
    }

    public convenience init<Environment>(
        initialState: State,
        reducer: Reducer<State, Action, Environment>,
        environment: Environment,
        useNewScope: Bool = false
    ) {
        self.init(
            initialState: initialState,
            reducer: reducer,
            environment: environment,
            useNewScope: useNewScope,
            mainThreadChecksEnabled: true
        )
        self.threadCheck(status: .`init`)
    }
    
    /// Initializes a store from an initial state, a reducer, and an environment, and the main thread
    /// check is disabled for all interactions with this store.
    ///
    /// - Parameters:
    ///   - initialState: The state to start the application in.
    ///   - reducer: The reducer that powers the business logic of the application.
    ///   - environment: The environment of dependencies for the application.
    public static func unchecked<Environment>(
        initialState: State,
        reducer: Reducer<State, Action, Environment>,
        environment: Environment,
        useNewScope: Bool = false
    ) -> Self {
        Self(
            initialState: initialState,
            reducer: reducer,
            environment: environment,
            useNewScope: useNewScope,
            mainThreadChecksEnabled: false
        )
    }
    
    private func newSend(_ action: Action, originatingFrom originatingAction: Action? = nil, instrumentation: Instrumentation) {
        bufferedActions.append(action)
        guard !isSending else { return }
        
        isSending = true
        var currentState = state
        let callbackInfo = Instrumentation.CallbackInfo(storeKind: Self.self, action: action, originatingAction: originatingAction).eraseToAny()
        instrumentation.callback?(callbackInfo, .pre, .storeSend)
        defer { instrumentation.callback?(callbackInfo, .post, .storeSend) }
        defer {
            instrumentation.callback?(callbackInfo, .pre, .storeChangeState)
            defer { instrumentation.callback?(callbackInfo, .post, .storeChangeState) }
            self.isSending = false
            self.state = currentState
        }
        while !bufferedActions.isEmpty {
            let action = bufferedActions.removeFirst()
            
            let processCallbackInfo = Instrumentation.CallbackInfo(storeKind: Self.self, action: action, originatingAction: nil).eraseToAny()
            instrumentation.callback?(processCallbackInfo, .pre, .storeProcessEvent)
            defer { instrumentation.callback?(processCallbackInfo, .post, .storeProcessEvent) }
            
            let effect = reducer(&currentState, action)
            
            var didComplete = false
            var disposeKey: CompositeDisposable.DisposeKey?
            
            let effectDisposable = effect.subscribe(
                onNext: { [weak self] effectAction in
                    self?.send(effectAction, originatingFrom: action, instrumentation: instrumentation)
                },
                onError: { err in
                    assertionFailure("Error during effect handling: \(err.localizedDescription)")
                },
                onCompleted: { [weak self] in
                    self?.threadCheck(status: .effectCompletion(action))
                    didComplete = true
                    if let disposeKey = disposeKey {
                        self?.effectDisposables.remove(for: disposeKey)
                    }
                }
            )
            
            if !didComplete {
                disposeKey = effectDisposables.insert(effectDisposable)
            }
        }
    }

    public func send(_ action: Action, originatingFrom originatingAction: Action? = nil, instrumentation: Instrumentation = .shared) {
        self.threadCheck(status: .send(action, originatingAction: originatingAction))
        guard !useNewScope else {
            newSend(action, originatingFrom: originatingAction, instrumentation: instrumentation)
            return
        }
        let callbackInfo = Instrumentation.CallbackInfo(storeKind: Self.self, action: action, originatingAction: originatingAction).eraseToAny()
        instrumentation.callback?(callbackInfo, .pre, .storeSend)
        defer { instrumentation.callback?(callbackInfo, .post, .storeSend) }
        if !isSending {
            synchronousActionsToSend.append(action)
        } else {
            bufferedActions.append(action)
            return
        }

        while !synchronousActionsToSend.isEmpty || !bufferedActions.isEmpty {
            let action = !synchronousActionsToSend.isEmpty
                ? synchronousActionsToSend.removeFirst()
                : bufferedActions.removeFirst()

            let processCallbackInfo = Instrumentation.CallbackInfo(storeKind: Self.self, action: action, originatingAction: nil).eraseToAny()
            instrumentation.callback?(processCallbackInfo, .pre, .storeProcessEvent)
            defer { instrumentation.callback?(processCallbackInfo, .post, .storeProcessEvent) }
            
            isSending = true
            instrumentation.callback?(callbackInfo, .pre, .storeChangeState)
            let effect = reducer(&state, action)
            instrumentation.callback?(callbackInfo, .post, .storeChangeState)
            isSending = false

            var didComplete = false
            var isProcessingEffects = true
            var disposeKey: CompositeDisposable.DisposeKey?

            let effectDisposable = effect.subscribe(
                onNext: { [weak self] action in
                    if isProcessingEffects {
                        self?.synchronousActionsToSend.append(action)
                    } else {
                        self?.send(action)
                    }
                },
                onError: { err in
                    assertionFailure("Error during effect handling: \(err.localizedDescription)")
                },
                onCompleted: { [weak self] in
                    didComplete = true
                    if let disposeKey = disposeKey {
                        self?.effectDisposables.remove(for: disposeKey)
                    }
                }
            )

            isProcessingEffects = false

            if !didComplete {
                disposeKey = effectDisposables.insert(effectDisposable)
            }
        }
    }

    public func scope<LocalState, LocalAction>(
        state toLocalState: @escaping (State) -> LocalState,
        action fromLocalAction: @escaping (LocalAction) -> Action,
        instrumentation: Instrumentation = .shared
    ) -> Store<LocalState, LocalAction> {
        self.threadCheck(status: .scope)
        if useNewScope {
            var isSending = false
            let localStore = Store<LocalState, LocalAction>(
                initialState: toLocalState(state),
                reducer: Reducer { localState, localAction, _ in
                    isSending = true
                    defer { isSending = false }
                    self.send(fromLocalAction(localAction))
                    localState = toLocalState(self.state)
                    return .none
                },
                environment: (),
                useNewScope: useNewScope
            )
            
            relay
                .skip(1)
                .subscribe(onNext: { [weak localStore] newValue in
                    guard !isSending else { return }
                    let callbackInfo = Instrumentation.CallbackInfo<Self.Type, Any>(storeKind: Self.self, action: nil).eraseToAny()
                    instrumentation.callback?(callbackInfo, .pre, .storeToLocal)
                    let newState = toLocalState(newValue)
                    instrumentation.callback?(callbackInfo, .post, .storeToLocal)
                    localStore?.state = newState
                })
                .disposed(by: localStore.disposeBag)
            
            return localStore
        } else {
            let localStore = Store<LocalState, LocalAction>(
                initialState: toLocalState(state),
                reducer: Reducer { localState, localAction, _ in
                    self.send(fromLocalAction(localAction))
                    localState = toLocalState(self.state)
                    return .none
                },
                environment: (),
                useNewScope: useNewScope
            )

            relay
                .subscribe(onNext: { [weak localStore] newValue in
                    let callbackInfo = Instrumentation.CallbackInfo<Self.Type, Any>(storeKind: Self.self, action: nil).eraseToAny()
                    instrumentation.callback?(callbackInfo, .pre, .storeToLocal)
                    let newState = toLocalState(newValue)
                    instrumentation.callback?(callbackInfo, .post, .storeToLocal)
                    localStore?.state = newState
                })
                .disposed(by: localStore.disposeBag)

            return localStore
        }
    }

    public func scope<LocalState>(
        state toLocalState: @escaping (State) -> LocalState,
        instrumentation: Instrumentation = .shared
    ) -> Store<LocalState, Action> {
        scope(state: toLocalState, action: { $0 }, instrumentation: instrumentation)
    }

    /// Returns a "stateless" store by erasing state to `Void`.
    public var stateless: Store<Void, Action> {
        scope(state: { _ in () })
    }

    /// Returns an "actionless" store by erasing action to `Never`.
    public var actionless: Store<State, Never> {
        func absurd<A>(_: Never) -> A {}
        return scope(state: { $0 }, action: absurd)
    }
    
    private enum ThreadCheckStatus {
      case effectCompletion(Action)
      case `init`
      case scope
      case send(Action, originatingAction: Action?)
    }

    @inline(__always)
    private func threadCheck(status: ThreadCheckStatus) {
      #if DEBUG
        guard self.mainThreadChecksEnabled && !Thread.isMainThread
        else { return }

        switch status {
        case let .effectCompletion(action):
          runtimeWarning(
            """
            An effect completed on a non-main thread. …

              Effect returned from:
                %@

            Make sure to use ".receive(on:)" on any effects that execute on background threads to \
            receive their output on the main thread, or create your store via "Store.unchecked" to \
            opt out of the main thread checker.

            The "Store" class is not thread-safe, and so all interactions with an instance of \
            "Store" (including all of its scopes and derived view stores) must be done on the same \
            thread.
            """,
            [debugCaseOutput(action)]
          )

        case .`init`:
          runtimeWarning(
            """
            A store initialized on a non-main thread. …

            If a store is intended to be used on a background thread, create it via \
            "Store.unchecked" to opt out of the main thread checker.

            The "Store" class is not thread-safe, and so all interactions with an instance of \
            "Store" (including all of its scopes and derived view stores) must be done on the same \
            thread.
            """
          )

        case .scope:
          runtimeWarning(
            """
            "Store.scope" was called on a non-main thread. …

            Make sure to use "Store.scope" on the main thread, or create your store via \
            "Store.unchecked" to opt out of the main thread checker.

            The "Store" class is not thread-safe, and so all interactions with an instance of \
            "Store" (including all of its scopes and derived view stores) must be done on the same \
            thread.
            """
          )

        case let .send(action, originatingAction: nil):
          runtimeWarning(
            """
            "Store.send" was called on a non-main thread with: %@ …

            Make sure that "ViewStore.send" is always called on the main thread, or create your \
            store via "Store.unchecked" to opt out of the main thread checker.

            The "Store" class is not thread-safe, and so all interactions with an instance of \
            "Store" (including all of its scopes and derived view stores) must be done on the same \
            thread.
            """,
            [debugCaseOutput(action)]
          )

        case let .send(action, originatingAction: .some(originatingAction)):
          runtimeWarning(
            """
            An effect published an action on a non-main thread. …

              Effect published:
                %@

              Effect returned from:
                %@

            Make sure to use ".receive(on:)" on any effects that execute on background threads to \
            receive their output on the main thread, or create this store via "Store.unchecked" to \
            disable the main thread checker.

            The "Store" class is not thread-safe, and so all interactions with an instance of \
            "Store" (including all of its scopes and derived view stores) must be done on the same \
            thread.
            """,
            [
              debugCaseOutput(action),
              debugCaseOutput(originatingAction),
            ]
          )
        }
      #endif
    }

    public func subscribe<LocalState>(
        _ toLocalState: @escaping (State) -> LocalState,
        removeDuplicates isDuplicate: @escaping (LocalState, LocalState) -> Bool,
        instrumentation: Instrumentation = .shared
    ) -> Effect<LocalState> {
        let stateChangeCallbackInfo = Instrumentation.CallbackInfo(storeKind: Self.self, action: nil as Action?).eraseToAny()
        return relay
            .map {
                instrumentation.callback?(stateChangeCallbackInfo, .pre, .viewStoreChangeState)
                defer { instrumentation.callback?(stateChangeCallbackInfo, .post, .viewStoreChangeState) }
                return toLocalState($0)
            }
            .distinctUntilChanged {
                instrumentation.callback?(stateChangeCallbackInfo, .pre, .viewStoreDeduplicate)
                        defer { instrumentation.callback?(stateChangeCallbackInfo, .post, .viewStoreDeduplicate) }
                return isDuplicate($0, $1)
            }
            .eraseToEffect()
//        return relay.map(toLocalState).distinctUntilChanged(isDuplicate).eraseToEffect()
    }

    public func subscribe<LocalState: Equatable>(
        _ toLocalState: @escaping (State) -> LocalState,
        instrumentation: Instrumentation = .shared
    ) -> Effect<LocalState> {
        return subscribe(toLocalState, removeDuplicates: ==, instrumentation: instrumentation)
    }
    
    private init<Environment>(
        initialState: State,
        reducer: Reducer<State, Action, Environment>,
        environment: Environment,
        useNewScope: Bool,
        mainThreadChecksEnabled: Bool
    ) {
        relay = BehaviorRelay(value: initialState)
        self.reducer = { state, action in reducer.run(&state, action, environment) }
        self.useNewScope = useNewScope
        
        #if DEBUG
        self.mainThreadChecksEnabled = mainThreadChecksEnabled
        #endif
        
        state = initialState
    }
}

extension Store {
    public func subscribeNeverEqual<LocalState: Equatable>(
        _ toLocalState: @escaping (State) -> NeverEqual<LocalState>,
        instrumentation: Instrumentation = .shared
    ) -> Effect<LocalState> {
        subscribe(toLocalState, removeDuplicates: ==, instrumentation: instrumentation)
            .map(\.wrappedValue)
            .eraseToEffect()
    }
}

extension Store where State: Equatable {
    public func subscribe() -> Effect<State> {
        return relay.distinctUntilChanged().eraseToEffect()
    }
}

extension Store where State: Collection, State.Element: HashDiffable, State: Equatable, State.Element: Equatable {
    /**
     A version of scope that scope an collection of sub store.

     This is kinda a version of `ForEachStoreNode`, not composing `WithViewStore` but creates the sub store.

     ## Example
     ```
     struct AppState { var todos: [Todo] }
     struct AppAction { case todo(index: Int, action: TodoAction }

     store.subscribe(\.todos)
        .drive(onNext: { todos in
            self.todoNodes = zip(todos.indices, todos).map { (offset, _) in
                TodoNode(with: store.scope(
                    identifier: identifier,
                    action: Action.todo(index:action:)
                )
            }
        })
        .disposed(by: disposeBag)
     ```

     But with example above, you created the entire node again and again and it's not the efficient way.
     You can do some diffing and only creating spesific index, and rest is handle by diffing.

     - Parameters:
        - identifier: the identifier from `IdentifierType` make sure index is in bounds of the collection
        - action: A function to transform `LocalAction` to `Action`. `LocalAction` should have `(CollectionIndex, LocalAction)` signature.

     - Returns: A new store with its domain (state and domain) transformed based on the index you set
     */
    public func scope<LocalState, LocalAction>(
        state toLocalState: @escaping (State) -> LocalState,
        action fromLocalAction: @escaping (LocalAction) -> Action,
        instrumentation: Instrumentation = .shared
    ) -> Store<LocalState, LocalAction> {
        self.threadCheck(status: .scope)
        if useNewScope {
            var isSending = false
            let localStore = Store<LocalState, LocalAction>(
                initialState: toLocalState(state),
                reducer: Reducer { localState, localAction, _ in
                    isSending = true
                    defer { isSending = false }
                    self.send(fromLocalAction(localAction))
                    localState = toLocalState(self.state)
                    return .none
                },
                environment: (),
                useNewScope: useNewScope
            )
            
            relay
                .skip(1)
                .subscribe(onNext: { [weak localStore] newValue in
                    guard !isSending else { return }
                    let callbackInfo = Instrumentation.CallbackInfo<Self.Type, Any>(storeKind: Self.self, action: nil).eraseToAny()
                    instrumentation.callback?(callbackInfo, .pre, .storeToLocal)
                    let newState = toLocalState(newValue)
                    instrumentation.callback?(callbackInfo, .post, .storeToLocal)
                    localStore?.state = newState
                })
                .disposed(by: localStore.disposeBag)
            
            return localStore
        } else {
            let localStore = Store<LocalState, LocalAction>(
                initialState: toLocalState(state),
                reducer: Reducer { localState, localAction, _ in
                    self.send(fromLocalAction(localAction))
                    localState = toLocalState(self.state)
                    return .none
                },
                environment: (),
                useNewScope: useNewScope
            )

            relay
                .subscribe(onNext: { [weak localStore] newValue in
                    let callbackInfo = Instrumentation.CallbackInfo<Self.Type, Any>(storeKind: Self.self, action: nil).eraseToAny()
                    instrumentation.callback?(callbackInfo, .pre, .storeToLocal)
                    let newState = toLocalState(newValue)
                    instrumentation.callback?(callbackInfo, .post, .storeToLocal)
                    localStore?.state = newState
                })
                .disposed(by: localStore.disposeBag)

            return localStore
        }
    }
    public func scope<LocalAction>(
        at identifier: State.Element.IdentifierType,
        action fromLocalAction: @escaping (LocalAction) -> Action,
        instrumentation: Instrumentation = .shared
    ) -> Store<State.Element, LocalAction>? {
        self.threadCheck(status: .scope)
        let toLocalState: (State.Element.IdentifierType, State) -> State.Element? = { identifier, state in
            /**
             if current state is IdentifiedArray, use pre exist subscript by identifier, to improve performance
             */
            if let identifiedArray = state as? IdentifiedArrayOf<State.Element> {
                return identifiedArray[id: identifier]
            } else {
                return state.first(where: { $0.id == identifier })
            }
        }
        if useNewScope {
            var isSending = false
            // skip if element on parent state wasn't found
            guard let element = toLocalState(identifier, state) else { return nil }
            let localStore = Store<State.Element, LocalAction>(
                initialState: element,
                reducer: Reducer { localState, localAction, _ in
                    isSending = true
                    defer { isSending = false }
                    self.send(fromLocalAction(localAction))
                    guard let finalState = toLocalState(identifier, self.state) else {
                        return .none
                    }
                    localState = finalState
                    return .none
                },
                environment: (),
                useNewScope: useNewScope
            )
            
            relay
                .skip(1)
                .subscribe(onNext: { [weak localStore] newValue in
                    guard !isSending else { return }
                    let callbackInfo = Instrumentation.CallbackInfo<Self.Type, Any>(storeKind: Self.self, action: nil).eraseToAny()
                    instrumentation.callback?(callbackInfo, .pre, .storeToLocal)
                    guard let element = toLocalState(identifier, newValue) else {
                        instrumentation.callback?(callbackInfo, .post, .storeToLocal)
                        return
                    }
                    instrumentation.callback?(callbackInfo, .post, .storeToLocal)
                    localStore?.state = element
                })
                .disposed(by: localStore.disposeBag)
            
            return localStore
        } else {
            // skip if element on parent state wasn't found
            guard let element = toLocalState(identifier, state) else { return nil }

            let localStore = Store<State.Element, LocalAction>(
                initialState: element,
                reducer: Reducer { localState, localAction, _ in
                    self.send(fromLocalAction(localAction))
                    guard let finalState = toLocalState(identifier, self.state) else {
                        return .none
                    }

                    localState = finalState
                    return .none
                },
                environment: (),
                useNewScope: useNewScope
            )

            // reflect changes on store parent to local store
            relay
                .distinctUntilChanged()
                .flatMapLatest { newValue -> Observable<State.Element> in
                    let callbackInfo = Instrumentation.CallbackInfo<Self.Type, Any>(storeKind: Self.self, action: nil).eraseToAny()
                    instrumentation.callback?(callbackInfo, .pre, .storeToLocal)
                    
                    guard let newElement = toLocalState(identifier, newValue) else {
                        instrumentation.callback?(callbackInfo, .post, .storeToLocal)
                        return .empty()
                    }
                    instrumentation.callback?(callbackInfo, .post, .storeToLocal)
                    return .just(newElement)
                }
                .subscribe(onNext: { [weak localStore] newValue in
                    localStore?.state = newValue
                })
                .disposed(by: localStore.disposeBag)

            return localStore
        }
    }
}
