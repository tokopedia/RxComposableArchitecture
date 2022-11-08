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

    #if swift(>=5.7)
        private let reducer: any ReducerProtocol<State, Action>
    #else
        private let reducer: (inout State, Action) -> Effect<Action>
        fileprivate var scope: AnyStoreScope?
    #endif
    
    internal let disposeBag = DisposeBag()
    internal var effectDisposables = CompositeDisposable()
    internal let relay: BehaviorRelay<State>
    
    fileprivate let useNewScope: Bool
    fileprivate let cancelsEffectsOnDeinit: Bool
    
    #if DEBUG
    private let mainThreadChecksEnabled: Bool
    #endif

    public var observable: Observable<State> {
        return relay.asObservable()
    }
    
    public init<R: ReducerProtocol>(
        initialState: R.State,
        reducer: R,
        useNewScope: Bool = StoreConfig.default.useNewScope(),
        mainThreadChecksEnabled: Bool = StoreConfig.default.mainThreadChecksEnabled(),
        cancelsEffectsOnDeinit: Bool = StoreConfig.default.cancelsEffectsOnDeinit()
    ) where R.State == State, R.Action == Action {
        self.relay = BehaviorRelay(value: initialState)
        self.cancelsEffectsOnDeinit = cancelsEffectsOnDeinit
        self.useNewScope = useNewScope
        #if swift(>=5.7)
            self.reducer = reducer
        #else
            self.reducer = reducer.reduce
        #endif
        #if DEBUG
            self.mainThreadChecksEnabled = mainThreadChecksEnabled
        #endif
        self.threadCheck(status: .`init`)
        self.state = initialState
        
        if cancelsEffectsOnDeinit {
            effectDisposables.disposed(by: disposeBag)
        }
    }
    
    /// Scopes the store to one that exposes child state and actions.
    ///
    /// This can be useful for deriving new stores to hand to child views in an application. For
    /// example:
    ///
    /// ```swift
    /// // Application state made from child states.
    /// struct State { var login: LoginState, ... }
    /// enum Action { case login(LoginAction), ... }
    ///
    /// // A store that runs the entire application.
    /// let store = Store(
    ///   initialState: AppReducer.State(),
    ///   reducer: AppReducer()
    /// )
    ///
    /// // Construct a login view by scoping the store to one that works with only login domain.
    /// LoginView(
    ///   store: store.scope(
    ///     state: \.login,
    ///     action: AppReducer.Action.login
    ///   )
    /// )
    /// ```
    ///
    /// Scoping in this fashion allows you to better modularize your application. In this case,
    /// `LoginView` could be extracted to a module that has no access to `App.State` or `App.Action`.
    ///
    /// Scoping also gives a view the opportunity to focus on just the state and actions it cares
    /// about, even if its feature domain is larger.
    ///
    /// For example, the above login domain could model a two screen login flow: a login form followed
    /// by a two-factor authentication screen. The second screen's domain might be nested in the
    /// first:
    ///
    /// ```swift
    /// struct LoginState: Equatable {
    ///   var email = ""
    ///   var password = ""
    ///   var twoFactorAuth: TwoFactorAuthState?
    /// }
    ///
    /// enum LoginAction: Equatable {
    ///   case emailChanged(String)
    ///   case loginButtonTapped
    ///   case loginResponse(Result<TwoFactorAuthState, LoginError>)
    ///   case passwordChanged(String)
    ///   case twoFactorAuth(TwoFactorAuthAction)
    /// }
    /// ```
    ///
    /// The login view holds onto a store of this domain:
    ///
    /// ```swift
    /// struct LoginView: View {
    ///   let store: Store<LoginState, LoginAction>
    ///
    ///   var body: some View { ... }
    /// }
    /// ```
    ///
    /// If its body were to use a view store of the same domain, this would introduce a number of
    /// problems:
    ///
    /// * The login view would be able to read from `twoFactorAuth` state. This state is only intended
    ///   to be read from the two-factor auth screen.
    ///
    /// * Even worse, changes to `twoFactorAuth` state would now cause SwiftUI to recompute
    ///   `LoginView`'s body unnecessarily.
    ///
    /// * The login view would be able to send `twoFactorAuth` actions. These actions are only
    ///   intended to be sent from the two-factor auth screen (and reducer).
    ///
    /// * The login view would be able to send non user-facing login actions, like `loginResponse`.
    ///   These actions are only intended to be used in the login reducer to feed the results of
    ///   effects back into the store.
    ///
    /// To avoid these issues, one can introduce a view-specific domain that slices off the subset of
    /// state and actions that a view cares about:
    ///
    /// ```swift
    /// extension LoginView {
    ///   struct State: Equatable {
    ///     var email: String
    ///     var password: String
    ///   }
    ///
    ///   enum Action: Equatable {
    ///     case emailChanged(String)
    ///     case loginButtonTapped
    ///     case passwordChanged(String)
    ///   }
    /// }
    /// ```
    ///
    /// One can also introduce a couple helpers that transform feature state into view state and
    /// transform view actions into feature actions.
    ///
    /// ```swift
    /// extension LoginState {
    ///   var view: LoginView.State {
    ///     .init(email: self.email, password: self.password)
    ///   }
    /// }
    ///
    /// extension LoginView.Action {
    ///   var feature: LoginAction {
    ///     switch self {
    ///     case let .emailChanged(email)
    ///       return .emailChanged(email)
    ///     case .loginButtonTapped:
    ///       return .loginButtonTapped
    ///     case let .passwordChanged(password)
    ///       return .passwordChanged(password)
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// With these helpers defined, `LoginView` can now scope its store's feature domain into its view
    /// domain:
    ///
    /// ```swift
    ///  var body: some View {
    ///    WithViewStore(
    ///      self.store, observe: \.view, send: \.feature
    ///    ) { viewStore in
    ///      ...
    ///    }
    ///  }
    /// ```
    ///
    /// This view store is now incapable of reading any state but view state (and will not recompute
    /// when non-view state changes), and is incapable of sending any actions but view actions.
    ///
    /// - Parameters:
    ///   - toChildState: A function that transforms `State` into `ChildState`.
    ///   - fromChildAction: A function that transforms `ChildAction` into `Action`.
    /// - Returns: A new store with its domain (state and action) transformed.
    public func scope<ChildState, ChildAction>(
        state toChildState: @escaping (State) -> ChildState,
        action fromChildAction: @escaping (ChildAction) -> Action
    ) -> Store<ChildState, ChildAction> {
        self.threadCheck(status: .scope)
        
        #if swift(>=5.7)
            return self.reducer.rescope(self, state: toChildState, action: fromChildAction)
        #else
            return (self.scope ?? StoreScope(root: self))
                .rescope(self, state: toChildState, action: fromChildAction)
        #endif
    }
    
    /// Scopes the store to one that exposes child state.
    ///
    /// A version of ``scope(state:action:)`` that leaves the action type unchanged.
    ///
    /// - Parameter toChildState: A function that transforms `State` into `ChildState`.
    /// - Returns: A new store with its domain (state and action) transformed.
    public func scope<ChildState>(
        state toChildState: @escaping (State) -> ChildState
    ) -> Store<ChildState, Action> {
        self.scope(state: toChildState, action: { $0 })
    }
    
    @discardableResult
    public func send(_ action: Action, originatingFrom originatingAction: Action? = nil) -> Task<Void, Never>? {
        self._send(action, originatingFrom: action)
    }
    
    func _send(
        _ action: Action,
        originatingFrom originatingAction: Action? = nil
    ) -> Task<Void, Never>? {
        guard useNewScope else {
            oldSend(action, originatingFrom: originatingAction)
            return nil
        }
        self.threadCheck(status: .send(action, originatingAction: originatingAction))
        
        self.bufferedActions.append(action)
        guard !self.isSending else { return nil }
        
        self.isSending = true
        var currentState = self.state
        let tasks = TaskBox<[Task<Void, Never>]>(wrappedValue: [])
        defer {
            withExtendedLifetime(self.bufferedActions) {
                self.bufferedActions.removeAll()
            }
            self.state = currentState
            self.isSending = false
            if !self.bufferedActions.isEmpty {
                if let task = self.send(
                    self.bufferedActions.removeLast(), originatingFrom: originatingAction
                ) {
                    tasks.wrappedValue.append(task)
                }
            }
        }
        
        var index = self.bufferedActions.startIndex
        while index < self.bufferedActions.endIndex {
            defer { index += 1 }
            let action = self.bufferedActions[index]
            #if swift(>=5.7)
                let effect = self.reducer.reduce(into: &currentState, action: action)
            #else
                let effect = self.reducer(&currentState, action)
            #endif
            
            switch effect.operation {
            case .none:
                break
            case let .observable(observable):
                var didComplete = false
                let boxedTask = TaskBox<Task<Void, Never>?>(wrappedValue: nil)
                var disposeKey: CompositeDisposable.DisposeKey?
                let effectDisposable = observable
                    .do(onDispose: { [weak self] in
                        self?.threadCheck(status: .effectCompletion(action))
                        if let disposeKey = disposeKey {
                            self?.effectDisposables.remove(for: disposeKey)
                        }
                    })
                    .subscribe(
                        onNext: { [weak self] effectAction in
                            if let task = self?.send(effectAction, originatingFrom: action) {
                                tasks.wrappedValue.append(task)
                            }
                        },
                        onError: {
                            assertionFailure("Error during effect handling: \($0.localizedDescription)")
                        },
                        onCompleted: { [weak self] in
                            self?.threadCheck(status: .effectCompletion(action))
                            boxedTask.wrappedValue?.cancel()
                            didComplete = true
                            if let disposeKey = disposeKey {
                                self?.effectDisposables.remove(for: disposeKey)
                            }
                        }
                    )
                
                if !didComplete {
                    let task = Task<Void, Never> { @MainActor in
                        for await _ in AsyncStream<Void>.never {}
                        effectDisposable.dispose()
                    }
                    boxedTask.wrappedValue = task
                    tasks.wrappedValue.append(task)
                    disposeKey = effectDisposables.insert(effectDisposable)
                }
            
            case let .run(priority, operation):
                tasks.wrappedValue.append(
                    Task(priority: priority) {
                        await operation(
                            Send {
                                if let task = self.send($0, originatingFrom: action) {
                                    tasks.wrappedValue.append(task)
                                }
                            }
                        )
                    }
                )
            }
        }
        
        guard !tasks.wrappedValue.isEmpty else { return nil }
        return Task {
            await withTaskCancellationHandler {
                var index = tasks.wrappedValue.startIndex
                while index < tasks.wrappedValue.endIndex {
                    defer { index += 1 }
                    await tasks.wrappedValue[index].value
                }
            } onCancel: {
                var index = tasks.wrappedValue.startIndex
                while index < tasks.wrappedValue.endIndex {
                    defer { index += 1 }
                    tasks.wrappedValue[index].cancel()
                }
            }
        }
    }
    
    /// Returns a "stateless" store by erasing state to `Void`.
    public var stateless: Store<Void, Action> {
        self.scope(state: { _ in () })
    }
    
    /// Returns an "actionless" store by erasing action to `Never`.
    public var actionless: Store<State, Never> {
        func absurd<A>(_ never: Never) -> A {}
        return self.scope(state: { $0 }, action: absurd)
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
            runtimeWarn(
                """
                An effect completed on a non-main thread. …
                
                  Effect returned from:
                    "\(debugCaseOutput(action))"
                
                Make sure to use ".receive(on:)" on any effects that execute on background threads to \
                receive their output on the main thread, or create your store via "Store.unchecked" to \
                opt out of the main thread checker.
                
                The "Store" class is not thread-safe, and so all interactions with an instance of \
                "Store" (including all of its scopes and derived view stores) must be done on the same \
                thread.
                """
            )
            
        case .`init`:
            runtimeWarn(
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
            runtimeWarn(
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
            runtimeWarn(
                """
                "Store.send" was called on a non-main thread with: "\(debugCaseOutput(action))"
                
                Make sure that "store.send" is always called on the main thread, or create your \
                store via "Store.unchecked" to opt out of the main thread checker.
                
                The "Store" class is not thread-safe, and so all interactions with an instance of \
                "Store" (including all of its scopes and derived view stores) must be done on the same \
                thread.
                """
            )
            
        case let .send(action, originatingAction: .some(originatingAction)):
            runtimeWarn(
                """
                An effect published an action on a non-main thread. …
                
                  Effect published:
                    %@
                    "\(debugCaseOutput(action))"

                  Effect returned from:
                    "\(debugCaseOutput(originatingAction))"
                
                Make sure to use ".receive(on:)" on any effects that execute on background threads to \
                receive their output on the main thread, or create this store via "Store.unchecked" to \
                disable the main thread checker.
                
                The "Store" class is not thread-safe, and so all interactions with an instance of \
                "Store" (including all of its scopes and derived view stores) must be done on the same \
                thread.
                """
            )
        }
      #endif
    }

    public func subscribe<LocalState>(
        _ toLocalState: @escaping (State) -> LocalState,
        removeDuplicates isDuplicate: @escaping (LocalState, LocalState) -> Bool
    ) -> Effect<LocalState> {
        return relay.map(toLocalState).distinctUntilChanged(isDuplicate).eraseToEffect()
    }

    public func subscribe<LocalState: Equatable>(
        _ toLocalState: @escaping (State) -> LocalState
    ) -> Effect<LocalState> {
        return relay.map(toLocalState).distinctUntilChanged().eraseToEffect()
    }
    
    private func oldSend(_ action: Action, originatingFrom originatingAction: Action? = nil) {
        self.threadCheck(status: .send(action, originatingAction: originatingAction))
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

            isSending = true
            #if swift(>=5.7)
                let effect = self.reducer.reduce(into: &state, action: action)
            #else
                let effect = self.reducer(&state, action)
            #endif
            isSending = false

            var didComplete = false
            var isProcessingEffects = true
            var disposeKey: CompositeDisposable.DisposeKey?
            
            switch effect.operation {
            case .none, .run: break
            case let .observable(observable):
                let effectDisposable = observable.subscribe(
                    onNext: { [weak self] effectAction in
                        if isProcessingEffects {
                            self?.synchronousActionsToSend.append(effectAction)
                        } else {
                            self?.send(effectAction, originatingFrom: action)
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
    }
}

extension Store {
    public func subscribeNeverEqual<LocalState: Equatable>(
        _ toLocalState: @escaping (State) -> NeverEqual<LocalState>
    ) -> Effect<LocalState> {
        relay.map(toLocalState).distinctUntilChanged()
            .map(\.wrappedValue)
            .eraseToEffect()
    }
    
    fileprivate var isMainThreadChecksEnabled: Bool {
        #if DEBUG
        return mainThreadChecksEnabled
        #else
        return false
        #endif
    }
}

extension Store where State: Equatable {
    public func subscribe() -> Effect<State> {
        return relay.distinctUntilChanged().eraseToEffect()
    }
}

/// A convenience type alias for referring to a store of a given reducer's domain.
///
/// Instead of specifying two generics:
///
/// ```swift
/// let store: Store<Feature.State, Feature.Action>
/// ```
///
/// You can specify a single generic:
///
/// ```swift
/// let store: StoreOf<Feature>
/// ```
public typealias StoreOf<R: ReducerProtocol> = Store<R.State, R.Action>


// MARK: - Old Store function pre reducer protocol
#if swift(<5.7)
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
    public func scope<LocalAction>(
        at identifier: State.Element.IdentifierType,
        action fromLocalAction: @escaping (LocalAction) -> Action
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
                    guard let element = toLocalState(identifier, newValue) else { return }
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
                    guard let newElement = toLocalState(identifier, newValue) else {
                        return .empty()
                    }

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

private protocol AnyStoreScope {
    func rescope<ScopedState, ScopedAction, RescopedState, RescopedAction>(
        _ store: Store<ScopedState, ScopedAction>,
        state toRescopedState: @escaping (ScopedState) -> RescopedState,
        action fromRescopedAction: @escaping (RescopedAction) -> ScopedAction
    ) -> Store<RescopedState, RescopedAction>
}

private struct StoreScope<RootState, RootAction>: AnyStoreScope {
    let root: Store<RootState, RootAction>
    let fromScopedAction: Any
    
    init(root: Store<RootState, RootAction>) {
        self.init(root: root, fromScopedAction: { $0 })
    }
    
    private init<ScopedAction>(
        root: Store<RootState, RootAction>,
        fromScopedAction: @escaping (ScopedAction) -> RootAction
    ) {
        self.root = root
        self.fromScopedAction = fromScopedAction
    }
    
    func rescope<ScopedState, ScopedAction, RescopedState, RescopedAction>(
        _ scopedStore: Store<ScopedState, ScopedAction>,
        state toRescopedState: @escaping (ScopedState) -> RescopedState,
        action fromRescopedAction: @escaping (RescopedAction) -> ScopedAction
    ) -> Store<RescopedState, RescopedAction> {
        let fromScopedAction = self.fromScopedAction as! (ScopedAction) -> RootAction
        
        var isSending = false
        let rescopedStore = Store<RescopedState, RescopedAction>(
            initialState: toRescopedState(scopedStore.state),
            reducer: Reducer { rescopedState, rescopedAction, _ in
                isSending = true
                defer { isSending = false }
                self.root.send(fromScopedAction(fromRescopedAction(rescopedAction)))
                rescopedState = toRescopedState(scopedStore.state)
                return .none
            },
            environment: (),
            useNewScope: root.useNewScope
        )
        
        scopedStore.relay
            .skip(1)
            .subscribe(onNext: { [weak rescopedStore] newValue in
                guard !isSending else { return }
                rescopedStore?.relay.accept(toRescopedState(newValue))
            })
            .disposed(by: rescopedStore.disposeBag)
        
        rescopedStore.scope = StoreScope<RootState, RootAction>(
            root: self.root,
            fromScopedAction: { fromScopedAction(fromRescopedAction($0)) }
        )
        return rescopedStore
    }
}
#endif

// MARK: - Reducer protocol Swift >=5.7
#if swift(>=5.7)
extension ReducerProtocol {
    fileprivate func rescope<ChildState, ChildAction>(
        _ store: Store<State, Action>,
        state toChildState: @escaping (State) -> ChildState,
        action fromChildAction: @escaping (ChildAction) -> Action
    ) -> Store<ChildState, ChildAction> {
        (self as? any AnyScopedReducer ?? ScopedReducer(rootStore: store))
            .rescope(store, state: toChildState, action: fromChildAction)
    }
}

private final class ScopedReducer<RootState, RootAction, ScopedState, ScopedAction>: ReducerProtocol {
    let rootStore: Store<RootState, RootAction>
    let toScopedState: (RootState) -> ScopedState
    private let parentStores: [Any]
    let fromScopedAction: (ScopedAction) -> RootAction
    private(set) var isSending = false
    
    @inlinable
    init(rootStore: Store<RootState, RootAction>)
    where RootState == ScopedState, RootAction == ScopedAction {
        self.rootStore = rootStore
        self.toScopedState = { $0 }
        self.parentStores = []
        self.fromScopedAction = { $0 }
    }
    
    @inlinable
    init(
        rootStore: Store<RootState, RootAction>,
        state toScopedState: @escaping (RootState) -> ScopedState,
        action fromScopedAction: @escaping (ScopedAction) -> RootAction,
        parentStores: [Any]
    ) {
        self.rootStore = rootStore
        self.toScopedState = toScopedState
        self.fromScopedAction = fromScopedAction
        self.parentStores = parentStores
    }
    
    @inlinable
    func reduce(
        into state: inout ScopedState, action: ScopedAction
    ) -> Effect<ScopedAction> {
        self.isSending = true
        defer {
            state = self.toScopedState(self.rootStore.state)
            self.isSending = false
        }
        if let task = self.rootStore.send(self.fromScopedAction(action)) {
            return .fireAndForget { await task.cancellableValue }
        } else {
            return .none
        }
    }
}

protocol AnyScopedReducer {
    func rescope<ScopedState, ScopedAction, RescopedState, RescopedAction>(
        _ store: Store<ScopedState, ScopedAction>,
        state toRescopedState: @escaping (ScopedState) -> RescopedState,
        action fromRescopedAction: @escaping (RescopedAction) -> ScopedAction
    ) -> Store<RescopedState, RescopedAction>
}

extension ScopedReducer: AnyScopedReducer {
    @inlinable
    func rescope<ScopedState, ScopedAction, RescopedState, RescopedAction>(
        _ store: Store<ScopedState, ScopedAction>,
        state toRescopedState: @escaping (ScopedState) -> RescopedState,
        action fromRescopedAction: @escaping (RescopedAction) -> ScopedAction
    ) -> Store<RescopedState, RescopedAction> {
        let fromScopedAction = self.fromScopedAction as! (ScopedAction) -> RootAction
        let reducer = ScopedReducer<RootState, RootAction, RescopedState, RescopedAction>(
            rootStore: self.rootStore,
            state: { _ in toRescopedState(store.state) },
            action: { fromScopedAction(fromRescopedAction($0)) },
            parentStores: self.parentStores + [store]
        )
        let childStore = Store<RescopedState, RescopedAction>(
            initialState: toRescopedState(store.state),
            reducer: reducer
        )
        store.relay
            .skip(1)
            .subscribe(onNext: { [weak childStore] newValue in
                guard !reducer.isSending else { return }
                childStore?.relay.accept(toRescopedState(newValue))
            })
            .disposed(by: store.disposeBag)
        return childStore
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
    public func scope<LocalAction>(
        at identifier: State.Element.IdentifierType,
        action fromLocalAction: @escaping (LocalAction) -> Action
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
        
        var isSending = false
        // skip if element on parent state wasn't found
        guard let element = toLocalState(identifier, state) else { return nil }
        
        let localStore = Store<State.Element, LocalAction>.init(
            initialState: element,
            reducer: Reduce(internal: { localState, localAction in
                isSending = true
                defer { isSending = false }
                if let task = self.send(fromLocalAction(localAction)) {
                    return .fireAndForget {
                        await task.cancellableValue
                    }
                } else {
                    guard let finalState = toLocalState(identifier, self.state) else {
                        return .none
                    }
                    localState = finalState
                    return .none
                }
            })
        )
        
        relay
            .skip(1)
            .subscribe(onNext: { [weak localStore] newValue in
                guard !isSending else { return }
                guard let element = toLocalState(identifier, newValue) else { return }
                localStore?.state = element
            })
            .disposed(by: localStore.disposeBag)
        
        return localStore
    }
}
#endif

/// A convenience type alias for referring to a store of a given reducer's domain.
///
/// Instead of specifying two generics:
///
/// ```swift
/// let store: Store<Feature.State, Feature.Action>
/// ```
///
/// You can specify a single generic:
///
/// ```swift
/// let store: StoreOf<Feature>
/// ```
public typealias StoreOf<R: ReducerProtocol> = Store<R.State, R.Action>
