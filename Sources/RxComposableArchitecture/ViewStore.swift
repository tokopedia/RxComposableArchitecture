import Combine
import SwiftUI
import RxSwift
import RxRelay
import OSLog

@dynamicMemberLookup
public final class ViewStore<ViewState, ViewAction>: ObservableObject {
    public private(set) lazy var objectWillChange = ObservableObjectPublisher()
    private let _send: (ViewAction) -> Task<Void, Never>?
    fileprivate let _state: BehaviorRelay<ViewState>
    private var viewDisposable = DisposeBag()
    public var observable: Observable<ViewState> {
        self._state.asObservable()
    }
    
    /// Initializes a view store from a store which observes changes to state.
    ///
    /// It is recommended that the `observe` argument transform the store's state into the bare
    /// minimum of data needed for the feature to do its job in order to not hinder performance.
    /// This is especially true for root level features, and less important for leaf features.
    ///
    /// To read more about this performance technique, read the <doc:Performance> article.
    ///
    /// - Parameters:
    ///   - store: A store.
    ///   - toViewState: A transformation of `ViewState` to the state that will be observed for
    ///   changes.
    ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
    ///   equal, repeat view computations are removed.
    public init<State>(
        _ store: Store<State, ViewAction>,
        observe toViewState: @escaping (_ state: State) -> ViewState,
        removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
    ) {
        self._send = { store.send($0, originatingFrom: nil) }
        self._state = BehaviorRelay(value: toViewState(store.state))
        store.observable
            .map(toViewState)
            .distinctUntilChanged(isDuplicate)
            .subscribe(onNext: { [weak objectWillChange = self.objectWillChange, weak _state = self._state] in
                guard let objectWillChange = objectWillChange, let _state = _state else { return }
                objectWillChange.send()
                _state.accept($0)
            })
            .disposed(by: self.viewDisposable)
    }
    
    /// Initializes a view store from a store which observes changes to state.
    ///
    /// It is recommended that the `observe` argument transform the store's state into the bare
    /// minimum of data needed for the feature to do its job in order to not hinder performance.
    /// This is especially true for root level features, and less important for leaf features.
    ///
    /// To read more about this performance technique, read the <doc:Performance> article.
    ///
    /// - Parameters:
    ///   - store: A store.
    ///   - toViewState: A transformation of `ViewState` to the state that will be observed for
    ///   changes.
    ///   - fromViewAction: A transformation of `ViewAction` that describes what actions can be sent.
    ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
    ///   equal, repeat view computations are removed.
    public init<State, Action>(
        _ store: Store<State, Action>,
        observe toViewState: @escaping (_ state: State) -> ViewState,
        send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
        removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
    ) {
        self._send = { store.send(fromViewAction($0), originatingFrom: nil) }
        self._state = BehaviorRelay(value: toViewState(store.state))
        store.observable
            .map(toViewState)
            .distinctUntilChanged(isDuplicate)
            .subscribe(onNext: { [weak objectWillChange = self.objectWillChange, weak _state = self._state] in
                guard let objectWillChange = objectWillChange, let _state = _state else { return }
                objectWillChange.send()
                _state.accept($0)
            })
            .disposed(by: self.viewDisposable)
    }
    
    public init(
        _ store: Store<ViewState, ViewAction>,
        removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
    ) {
        self._send = { store.send($0, originatingFrom: nil) }
        self._state = BehaviorRelay(value: store.state)
        store.observable
            .distinctUntilChanged(isDuplicate)
            .subscribe(onNext: { [weak objectWillChange = self.objectWillChange, weak _state = self._state] in
                guard let objectWillChange = objectWillChange, let _state = _state else { return }
                objectWillChange.send()
                _state.accept($0)
            })
            .disposed(by: self.viewDisposable)
    }
    
    init(_ viewStore: ViewStore<ViewState, ViewAction>) {
        self._send = viewStore._send
        self._state = viewStore._state
        self.objectWillChange = viewStore.objectWillChange
        self.viewDisposable = viewStore.viewDisposable
    }
    
    deinit {
        print("viewStore deinit")
    }
    
    
    /// A publisher that emits when state changes.
    ///
    /// This publisher supports dynamic member lookup so that you can pluck out a specific field in
    /// the state:
    ///
    /// ```swift
    /// viewStore.publisher.alert
    ///   .sink { ... }
    /// ```
    ///
    /// When the emission happens the ``ViewStore``'s state has been updated, and so the following
    /// precondition will pass:
    ///
    /// ```swift
    /// viewStore.publisher
    ///   .sink { precondition($0 == viewStore.state) }
    /// ```
    ///
    /// This means you can either use the value passed to the closure or you can reach into
    /// `viewStore.state` directly.
    ///
    /// - Note: Due to a bug in Combine (or feature?), the order you `.sink` on a publisher has no
    ///   bearing on the order the `.sink` closures are called. This means the work performed inside
    ///   `viewStore.publisher.sink` closures should be completely independent of each other. Later
    ///   closures cannot assume that earlier ones have already run.
    /// public var publisher: StorePublisher<ViewState> {
    ///     StorePublisher(viewStore: self)
    /// }
    
    public var state: ViewState {
        self._state.value
    }
    
    /// Returns the resulting value of a given key path.
    public subscript<Value>(dynamicMember keyPath: KeyPath<ViewState, Value>) -> Value {
        self._state.value[keyPath: keyPath]
    }
    
    /// Sends an action to the store.
    ///
    /// This method returns a ``StoreTask``, which represents the lifecycle of the effect started
    /// from sending an action. You can use this value to tie the effect's lifecycle _and_
    /// cancellation to an asynchronous context, such as SwiftUI's `task` view modifier:
    ///
    /// ```swift
    /// .task { await viewStore.send(.task).finish() }
    /// ```
    ///
    /// > Important: ``ViewStore`` is not thread safe and you should only send actions to it from the
    /// > main thread. If you want to send actions on background threads due to the fact that the
    /// > reducer is performing computationally expensive work, then a better way to handle this is to
    /// > wrap that work in an ``EffectTask`` that is performed on a background thread so that the
    /// > result can be fed back into the store.
    ///
    /// - Parameter action: An action.
    /// - Returns: A ``StoreTask`` that represents the lifecycle of the effect executed when
    ///   sending the action.
    @discardableResult
    public func send(_ action: ViewAction) -> StoreTask {
        .init(rawValue: self._send(action))
    }
    
    /// Sends an action to the store with a given animation.
    ///
    /// See ``ViewStore/send(_:)`` for more info.
    ///
    /// - Parameters:
    ///   - action: An action.
    ///   - animation: An animation.
    @discardableResult
    public func send(_ action: ViewAction, animation: Animation?) -> StoreTask {
        send(action, transaction: Transaction(animation: animation))
    }
    
    /// Sends an action to the store with a given transaction.
    ///
    /// See ``ViewStore/send(_:)`` for more info.
    ///
    /// - Parameters:
    ///   - action: An action.
    ///   - transaction: A transaction.
    @discardableResult
    public func send(_ action: ViewAction, transaction: Transaction) -> StoreTask {
        withTransaction(transaction) {
            self.send(action)
        }
    }
    
    /// Sends an action into the store and then suspends while a piece of state is `true`.
    ///
    /// This method can be used to interact with async/await code, allowing you to suspend while work
    /// is being performed in an effect. One common example of this is using SwiftUI's `.refreshable`
    /// method, which shows a loading indicator on the screen while work is being performed.
    ///
    /// For example, suppose we wanted to load some data from the network when a pull-to-refresh
    /// gesture is performed on a list. The domain and logic for this feature can be modeled like so:
    ///
    /// ```swift
    /// struct Feature: ReducerProtocol {
    ///   struct State: Equatable {
    ///     var isLoading = false
    ///     var response: String?
    ///   }
    ///   enum Action {
    ///     case pulledToRefresh
    ///     case receivedResponse(TaskResult<String>)
    ///   }
    ///   @Dependency(\.fetch) var fetch
    ///
    ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    ///     switch action {
    ///     case .pulledToRefresh:
    ///       state.isLoading = true
    ///       return .run { send in
    ///         await send(.receivedResponse(TaskResult { try await self.fetch() }))
    ///       }
    ///
    ///     case let .receivedResponse(result):
    ///       state.isLoading = false
    ///       state.response = try? result.value
    ///       return .none
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// Note that we keep track of an `isLoading` boolean in our state so that we know exactly when
    /// the network response is being performed.
    ///
    /// The view can show the fact in a `List`, if it's present, and we can use the `.refreshable`
    /// view modifier to enhance the list with pull-to-refresh capabilities:
    ///
    /// ```swift
    /// struct MyView: View {
    ///   let store: Store<State, Action>
    ///
    ///   var body: some View {
    ///     WithViewStore(self.store, observe: { $0 }) { viewStore in
    ///       List {
    ///         if let response = viewStore.response {
    ///           Text(response)
    ///         }
    ///       }
    ///       .refreshable {
    ///         await viewStore.send(.pulledToRefresh, while: \.isLoading)
    ///       }
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// Here we've used the ``send(_:while:)`` method to suspend while the `isLoading` state is
    /// `true`. Once that piece of state flips back to `false` the method will resume, signaling to
    /// `.refreshable` that the work has finished which will cause the loading indicator to disappear.
    ///
    /// - Parameters:
    ///   - action: An action.
    ///   - predicate: A predicate on `ViewState` that determines for how long this method should
    ///     suspend.
    @MainActor
    public func send(
        _ action: ViewAction,
        while predicate: @escaping (_ state: ViewState) -> Bool
    ) async {
        let task = self.send(action)
        await withTaskCancellationHandler {
            await self.yield(while: predicate)
        } onCancel: {
            task.rawValue?.cancel()
        }
    }
    
    /// Sends an action into the store and then suspends while a piece of state is `true`.
    ///
    /// See the documentation of ``send(_:while:)`` for more information.
    ///
    /// - Parameters:
    ///   - action: An action.
    ///   - animation: The animation to perform when the action is sent.
    ///   - predicate: A predicate on `ViewState` that determines for how long this method should
    ///     suspend.
    @MainActor
    public func send(
        _ action: ViewAction,
        animation: Animation?,
        while predicate: @escaping (_ state: ViewState) -> Bool
    ) async {
        let task = withAnimation(animation) { self.send(action) }
        await withTaskCancellationHandler {
            await self.yield(while: predicate)
        } onCancel: {
            task.rawValue?.cancel()
        }
    }
    
    /// Suspends the current task while a predicate on state is `true`.
    ///
    /// If you want to suspend at the same time you send an action to the view store, use
    /// ``send(_:while:)``.
    ///
    /// - Parameter predicate: A predicate on `ViewState` that determines for how long this method
    ///   should suspend.
    @MainActor
    public func yield(while predicate: @escaping (_ state: ViewState) -> Bool) async {
        let cancellable = TaskBox<Disposable?>(wrappedValue: nil)
        try? await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            try await withUnsafeThrowingContinuation {
                (continuation: UnsafeContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                cancellable.wrappedValue = self._state.asObservable()
                    .filter { !predicate($0) }
                    .take(1)
                    .subscribe(onNext: { _ in
                        continuation.resume()
                        _ = cancellable
                    })
            }
        }, onCancel: {
            cancellable.wrappedValue?.dispose()
        })
    }
    
    /// Derives a binding from the store that prevents direct writes to state and instead sends
    /// actions to the store.
    ///
    /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
    /// since the ``Store`` does not allow directly writing its state; it only allows reading state
    /// and sending actions.
    ///
    /// For example, a text field binding can be created like this:
    ///
    /// ```swift
    /// struct State { var name = "" }
    /// enum Action { case nameChanged(String) }
    ///
    /// TextField(
    ///   "Enter name",
    ///   text: viewStore.binding(
    ///     get: { $0.name },
    ///     send: { Action.nameChanged($0) }
    ///   )
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - get: A function to get the state for the binding from the view store's full state.
    ///   - valueToAction: A function that transforms the binding's value into an action that can be
    ///     sent to the store.
    /// - Returns: A binding.
    public func binding<Value>(
        get: @escaping (_ state: ViewState) -> Value,
        send valueToAction: @escaping (_ value: Value) -> ViewAction
    ) -> Binding<Value> {
        ObservedObject(wrappedValue: self)
            .projectedValue[get: .init(rawValue: get), send: .init(rawValue: valueToAction)]
    }
    
    @_disfavoredOverload
    func binding<Value>(
        get: @escaping (_ state: ViewState) -> Value,
        compactSend valueToAction: @escaping (_ value: Value) -> ViewAction?
    ) -> Binding<Value> {
        ObservedObject(wrappedValue: self)
            .projectedValue[get: .init(rawValue: get), send: .init(rawValue: valueToAction)]
    }
    
    /// Derives a binding from the store that prevents direct writes to state and instead sends
    /// actions to the store.
    ///
    /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
    /// since the ``Store`` does not allow directly writing its state; it only allows reading state
    /// and sending actions.
    ///
    /// For example, an alert binding can be dealt with like this:
    ///
    /// ```swift
    /// struct State { var alert: String? }
    /// enum Action { case alertDismissed }
    ///
    /// .alert(
    ///   item: viewStore.binding(
    ///     get: { $0.alert },
    ///     send: .alertDismissed
    ///   )
    /// ) { alert in Alert(title: Text(alert.message)) }
    /// ```
    ///
    /// - Parameters:
    ///   - get: A function to get the state for the binding from the view store's full state.
    ///   - action: The action to send when the binding is written to.
    /// - Returns: A binding.
    public func binding<Value>(
        get: @escaping (_ state: ViewState) -> Value,
        send action: ViewAction
    ) -> Binding<Value> {
        self.binding(get: get, send: { _ in action })
    }
    
    /// Derives a binding from the store that prevents direct writes to state and instead sends
    /// actions to the store.
    ///
    /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
    /// since the ``Store`` does not allow directly writing its state; it only allows reading state
    /// and sending actions.
    ///
    /// For example, a text field binding can be created like this:
    ///
    /// ```swift
    /// typealias State = String
    /// enum Action { case nameChanged(String) }
    ///
    /// TextField(
    ///   "Enter name",
    ///   text: viewStore.binding(
    ///     send: { Action.nameChanged($0) }
    ///   )
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - valueToAction: A function that transforms the binding's value into an action that can be
    ///     sent to the store.
    /// - Returns: A binding.
    public func binding(
        send valueToAction: @escaping (_ state: ViewState) -> ViewAction
    ) -> Binding<ViewState> {
        self.binding(get: { $0 }, send: valueToAction)
    }
    
    /// Derives a binding from the store that prevents direct writes to state and instead sends
    /// actions to the store.
    ///
    /// The method is useful for dealing with SwiftUI components that work with two-way `Binding`s
    /// since the ``Store`` does not allow directly writing its state; it only allows reading state
    /// and sending actions.
    ///
    /// For example, an alert binding can be dealt with like this:
    ///
    /// ```swift
    /// typealias State = String
    /// enum Action { case alertDismissed }
    ///
    /// .alert(
    ///   item: viewStore.binding(
    ///     send: .alertDismissed
    ///   )
    /// ) { title in Alert(title: Text(title)) }
    /// ```
    ///
    /// - Parameters:
    ///   - action: The action to send when the binding is written to.
    /// - Returns: A binding.
    public func binding(send action: ViewAction) -> Binding<ViewState> {
        self.binding(send: { _ in action })
    }
    
    private subscript<Value>(
        get fromState: HashableWrapper<(ViewState) -> Value>,
        send toAction: HashableWrapper<(Value) -> ViewAction?>
    ) -> Value {
        get { fromState.rawValue(self.state) }
        set {
            BindingLocal.$isActive.withValue(true) {
                if let action = toAction.rawValue(newValue) {
                    self.send(action)
                }
            }
        }
    }
}

/// A convenience type alias for referring to a view store of a given reducer's domain.
///
/// Instead of specifying two generics:
///
/// ```swift
/// let viewStore: ViewStore<Feature.State, Feature.Action>
/// ```
///
/// You can specify a single generic:
///
/// ```swift
/// let viewStore: ViewStoreOf<Feature>
/// ```
public typealias ViewStoreOf<R: ReducerProtocol> = ViewStore<R.State, R.Action>

extension ViewStore where ViewState: Equatable {
    /// Initializes a view store from a store which observes changes to state.
    ///
    /// It is recommended that the `observe` argument transform the store's state into the bare
    /// minimum of data needed for the feature to do its job in order to not hinder performance.
    /// This is especially true for root level features, and less important for leaf features.
    ///
    /// To read more about this performance technique, read the <doc:Performance> article.
    ///
    /// - Parameters:
    ///   - store: A store.
    ///   - toViewState: A transformation of `ViewState` to the state that will be observed for
    ///   changes.
    public convenience init<State>(
        _ store: Store<State, ViewAction>,
        observe toViewState: @escaping (_ state: State) -> ViewState
    ) {
        self.init(store, observe: toViewState, removeDuplicates: ==)
    }
    
    /// Initializes a view store from a store which observes changes to state.
    ///
    /// It is recommended that the `observe` argument transform the store's state into the bare
    /// minimum of data needed for the feature to do its job in order to not hinder performance.
    /// This is especially true for root level features, and less important for leaf features.
    ///
    /// To read more about this performance technique, read the <doc:Performance> article.
    ///
    /// - Parameters:
    ///   - store: A store.
    ///   - toViewState: A transformation of `ViewState` to the state that will be observed for
    ///   changes.
    ///   - fromViewAction: A transformation of `ViewAction` that describes what actions can be sent.
    public convenience init<State, Action>(
        _ store: Store<State, Action>,
        observe toViewState: @escaping (_ state: State) -> ViewState,
        send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action
    ) {
        self.init(store, observe: toViewState, send: fromViewAction, removeDuplicates: ==)
    }
}

private struct HashableWrapper<Value>: Hashable {
    let rawValue: Value
    static func == (lhs: Self, rhs: Self) -> Bool { false }
    func hash(into hasher: inout Hasher) {}
}

enum BindingLocal {
    @TaskLocal static var isActive = false
}

@dynamicMemberLookup
public struct StorePublisher<State>: ObservableType {
    public typealias Element = State
    public let upstream: Observable<State>
    
    public func subscribe<Observer>(_ observer: Observer) -> Disposable
    where Observer: ObserverType, Element == Observer.Element {
        upstream.subscribe(observer)
    }
    
    init(_ upstream: Observable<State>) {
        self.upstream = upstream
    }
    
    /// Returns the resulting publisher of a given key path.
    public subscript<LocalState>(
        dynamicMember keyPath: KeyPath<State, LocalState>
    ) -> StorePublisher<LocalState>
    where LocalState: Equatable {
        .init(self.upstream.map { $0[keyPath: keyPath] }.distinctUntilChanged())
    }
}
