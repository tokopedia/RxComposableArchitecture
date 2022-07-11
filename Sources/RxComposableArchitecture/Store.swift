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

    public var observable: Observable<State> {
        return relay.asObservable()
    }

    private init(
        initialState: State,
        reducer: @escaping (inout State, Action) -> Effect<Action>,
        useNewScope: Bool
    ) {
        relay = BehaviorRelay(value: initialState)
        self.reducer = reducer
        self.useNewScope = useNewScope
        state = initialState
    }

    public convenience init<Environment>(
        initialState: State,
        reducer: Reducer<State, Action, Environment>,
        environment: Environment,
        useNewScope: Bool = false
    ) {
        self.init(
            initialState: initialState,
            reducer: { reducer.callAsFunction(&$0, $1, environment) },
            useNewScope: useNewScope
        )
    }
    
    private func newSend(_ action: Action) {
        bufferedActions.append(action)
        guard !isSending else { return }
        
        isSending = true
        var currentState = state
        defer {
            self.isSending = false
            self.state = currentState
        }
        while !bufferedActions.isEmpty {
            let action = bufferedActions.removeFirst()
            let effect = reducer(&currentState, action)
            
            var didComplete = false
            var disposeKey: CompositeDisposable.DisposeKey?
            
            let effectDisposable = effect.subscribe(
                onNext: { [weak self] action in
                    self?.send(action)
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
            
            if !didComplete {
                disposeKey = effectDisposables.insert(effectDisposable)
            }
        }
    }

    public func send(_ action: Action) {
        guard !useNewScope else {
            newSend(action)
            return
        }
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
            let effect = reducer(&state, action)
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
        action fromLocalAction: @escaping (LocalAction) -> Action
    ) -> Store<LocalState, LocalAction> {
        if useNewScope {
            var isSending = false
            let localStore = Store<LocalState, LocalAction>(
                initialState: toLocalState(state),
                reducer: { localState, localAction in
                    isSending = true
                    defer { isSending = false }
                    self.send(fromLocalAction(localAction))
                    localState = toLocalState(self.state)
                    return .none
                },
                useNewScope: useNewScope
            )
            
            relay
                .skip(1)
                .subscribe(onNext: { [weak localStore] newValue in
                    guard !isSending else { return }
                    localStore?.state = toLocalState(newValue)
                })
                .disposed(by: localStore.disposeBag)
            
            return localStore
        } else {
            let localStore = Store<LocalState, LocalAction>(
                initialState: toLocalState(state),
                reducer: { localState, localAction in
                    self.send(fromLocalAction(localAction))
                    localState = toLocalState(self.state)
                    return .none
                },
                useNewScope: useNewScope
            )

            relay
                .subscribe(onNext: { [weak localStore] newValue in
                    localStore?.state = toLocalState(newValue)
                })
                .disposed(by: localStore.disposeBag)

            return localStore
        }
    }

    public func scope<LocalState>(
        state toLocalState: @escaping (State) -> LocalState
    ) -> Store<LocalState, Action> {
        scope(state: toLocalState, action: { $0 })
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
}

extension Store {
    public func subscribeNeverEqual<LocalState: Equatable>(
        _ toLocalState: @escaping (State) -> NeverEqual<LocalState>
    ) -> Effect<LocalState> {
        relay.map(toLocalState).distinctUntilChanged()
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
    public func scope<LocalAction>(
        at identifier: State.Element.IdentifierType,
        action fromLocalAction: @escaping (LocalAction) -> Action
    ) -> Store<State.Element, LocalAction>? {
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
                reducer: { localState, localAction in
                    isSending = true
                    defer { isSending = false }
                    self.send(fromLocalAction(localAction))
                    guard let finalState = toLocalState(identifier, self.state) else {
                        return .none
                    }
                    localState = finalState
                    return .none
                },
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
                reducer: { localState, localAction in
                    self.send(fromLocalAction(localAction))
                    guard let finalState = toLocalState(identifier, self.state) else {
                        return .none
                    }

                    localState = finalState
                    return .none
                },
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
