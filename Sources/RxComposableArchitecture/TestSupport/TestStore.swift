#if DEBUG
import Foundation
import RxSwift

/// A testable runtime for a reducer.
///
/// This object aids in writing expressive and exhaustive tests for features built in the
/// Composable Architecture. It allows you to send a sequence of actions to the store, and each
/// step of the way you must assert exactly how state changed, and how effect emissions were fed
/// back into the system.
///
/// There are multiple ways the test store forces you to exhaustively assert on how your feature
/// behaves:
///
///   * After each action is sent you must describe precisely how the state changed from before
///     the action was sent to after it was sent.
///
///     If even the smallest piece of data differs the test will fail. This guarantees that you
///     are proving you know precisely how the state of the system changes.
///
///   * Sending an action can sometimes cause an effect to be executed, and if that effect emits
///     an action that is fed back into the system, you **must** explicitly assert that you expect
///     to receive that action from the effect, _and_ you must assert how state changed as a
///     result.
///
///     If you try to send another action before you have handled all effect emissions the
///     assertion will fail. This guarantees that you do not accidentally forget about an effect
///     emission, and that the sequence of steps you are describing will mimic how the application
///     behaves in reality.
///
///   * All effects must complete by the time the assertion has finished running the steps you
///     specify.
///
///     If at the end of the assertion there is still an in-flight effect running, the assertion
///     will fail. This helps exhaustively prove that you know what effects are in flight and
///     forces you to prove that effects will not cause any future changes to your state.
///
/// For example, given a simple counter reducer:
///
/// ```swift
/// struct Counter: ReducerProtocol {
///   struct State: Equatable {
///     var count = 0
///   }
///
///   enum Action {
///     case decrementButtonTapped
///     case incrementButtonTapped
///   }
///
///   func reduce(
///     into state: inout State, action: Action
///   ) -> Effect<Action, Never> {
///     switch action {
///     case .decrementButtonTapped:
///       state.count -= 1
///       return .none
///
///     case .incrementButtonTapped:
///       state.count += 1
///       return .none
///     }
///   }
/// }
/// ```
///
/// One can assert against its behavior over time:
///
/// ```swift
/// @MainActor
/// class CounterTests: XCTestCase {
///   func testCounter() async {
///     let store = TestStore(
///       // Given a counter state of 0
///       initialState: Counter.State(count: 0),
///       reducer: Counter()
///     )
///
///     // When the increment button is tapped
///     await store.send(.incrementButtonTapped) {
///       // Then the count should be 1
///       $0.count = 1
///     }
///   }
/// }
/// ```
///
/// Note that in the trailing closure of `.send(.incrementButtonTapped)` we are given a single
/// mutable value of the state before the action was sent, and it is our job to mutate the value
/// to match the state after the action was sent. In this case the `count` field changes to `1`.
///
/// For a more complex example, consider the following bare-bones search feature that uses a
/// scheduler and cancel token to debounce requests:
///
/// ```swift
/// struct Search: ReducerProtocol {
///   struct State: Equatable {
///     var query = ""
///     var results: [String] = []
///   }
///
///   enum Action: Equatable {
///     case queryChanged(String)
///     case response([String])
///   }
///
///   @Dependency(\.apiClient) var apiClient
///   @Dependency(\.mainQueue) var mainQueue
///
///   func reduce(
///     into state: inout State, action: Action
///   ) -> Effect<Action, Never> {
///     switch action {
///     case let .queryChanged(query):
///       enum SearchID {}
///
///       state.query = query
///       return .run { send in
///         try await self.mainQueue.sleep(for: 0.5)
///
///         guard let results = try? await self.apiClient.search(query)
///         else { return }
///
///         await send(.response(results))
///       }
///       .cancellable(id: SearchID.self, cancelInFlight: true)
///
///     case let .response(results):
///       state.results = results
///       return .none
///     }
///   }
/// }
/// ```
///
/// It can be fully tested by overriding the `mainQueue` and `apiClient` dependencies with values
/// that are fully controlled and deterministic:
///
/// ```swift
/// let store = TestStore(
///   initialState: Search.State(),
///   reducer: Search
/// )
///
/// // Create a test dispatch scheduler to control the timing of effects
/// let mainQueue = DispatchQueue.test
/// store.dependencies.mainQueue = mainQueue.eraseToAnyScheduler()
///
/// // Simulate a search response with one item
/// store.dependencies.mainQueue.apiClient.search = { _ in
///   ["Composable Architecture"]
/// }
///
/// // Change the query
/// await store.send(.searchFieldChanged("c") {
///   // Assert that state updates accordingly
///   $0.query = "c"
/// }
///
/// // Advance the queue by a period shorter than the debounce
/// await mainQueue.advance(by: 0.25)
///
/// // Change the query again
/// await store.send(.searchFieldChanged("co") {
///   $0.query = "co"
/// }
///
/// // Advance the queue by a period shorter than the debounce
/// await mainQueue.advance(by: 0.25)
/// // Advance the scheduler to the debounce
/// await scheduler.advance(by: 0.25)
///
/// // Assert that the expected response is received
/// await store.receive(.response(["Composable Architecture"])) {
///   // Assert that state updates accordingly
///   $0.results = ["Composable Architecture"]
/// }
/// ```
///
/// This test is proving that the debounced network requests are correctly canceled when we do not
/// wait longer than the 0.5 seconds, because if it wasn't and it delivered an action when we did
/// not expect it would cause a test failure.
public final class TestStore<Reducer: ReducerProtocol, ScopedState, ScopedAction, Context> {
    /// The current dependencies.
    ///
    /// The dependencies define the execution context that your feature runs in. They can be
    /// modified throughout the test store's lifecycle in order to influence how your feature
    /// produces effects.
    public var dependencies: DependencyValues {
        _read { yield self.reducer.dependencies }
        _modify { yield &self.reducer.dependencies }
    }
    
    /// The current environment.
    ///
    /// The environment can be modified throughout a test store's lifecycle in order to influence
    /// how it produces effects. This can be handy for testing flows that require a dependency to
    /// start in a failing state and then later change into a succeeding state:
    ///
    /// ```swift
    /// // Start dependency endpoint in a failing state
    /// store.environment.client.fetch = { _ in throw FetchError() }
    /// await store.send(.buttonTapped)
    /// await store.receive(.response(.failure(FetchError())) {
    ///   …
    /// }
    ///
    /// // Change dependency endpoint into a succeeding state
    /// await store.environment.client.fetch = { "Hello \($0)!" }
    /// await store.send(.buttonTapped)
    /// await store.receive(.response(.success("Hello Blob!"))) {
    ///   …
    /// }
    /// ```
    public var environment: Context {
        _read { yield self._environment.wrappedValue }
        _modify { yield &self._environment.wrappedValue }
    }
    
    /// The current state.
    ///
    /// When read from a trailing closure assertion in ``send(_:_:file:line:)-3pf4p`` or
    /// ``receive(_:timeout:_:file:line:)-1fjua``, it will equal the `inout` state passed to the
    /// closure.
    public var state: Reducer.State {
        self.reducer.state
    }
    
    /// The timeout to await for in-flight effects.
    ///
    /// This is the default timeout used in all methods that take an optional timeout, such as
    /// ``send(_:_:file:line:)-3pf4p``, ``receive(_:timeout:_:file:line:)-1fjua`` and
    /// ``finish(timeout:file:line:)-53gi5``.
    public var timeout: UInt64
    
    private var _environment: Box<Context>
    private let file: StaticString
    private let fromScopedAction: (ScopedAction) -> Reducer.Action
    private var line: UInt
    let reducer: TestReducer<Reducer>
    private var store: Store<Reducer.State, TestReducer<Reducer>.Action>!
    private let toScopedState: (Reducer.State) -> ScopedState
    
    public init(
        initialState: Reducer.State,
        reducer: Reducer,
        file: StaticString = #file,
        line: UInt = #line
    )
    where
    Reducer.State == ScopedState,
    Reducer.Action == ScopedAction,
    Context == Void
    {
        let reducer = TestReducer(reducer, initialState: initialState)
        self._environment = .init(wrappedValue: ())
        self.file = file
        self.fromScopedAction = { $0 }
        self.line = line
        self.reducer = reducer
        self.store = Store(initialState: initialState, reducer: reducer)
        self.timeout = 100 * NSEC_PER_MSEC
        self.toScopedState = { $0 }
    }
    
    // NB: Can't seem to define this as a convenience initializer in 'ReducerCompatibility.swift'.
    @available(iOS, deprecated: 9999.0, message: "Use 'ReducerProtocol' instead.")
    @available(macOS, deprecated: 9999.0, message: "Use 'ReducerProtocol' instead.")
    @available(tvOS, deprecated: 9999.0, message: "Use 'ReducerProtocol' instead.")
    @available(watchOS, deprecated: 9999.0, message: "Use 'ReducerProtocol' instead.")
    public init(
        initialState: ScopedState,
        reducer: AnyReducer<ScopedState, ScopedAction, Context>,
        environment: Context,
        file: StaticString = #file,
        line: UInt = #line
    )
    where
    Reducer == Reduce<ScopedState, ScopedAction>
    {
        let environment = Box(wrappedValue: environment)
        let reducer = TestReducer(
            Reduce(
                reducer.pullback(state: \.self, action: .self, environment: { $0.wrappedValue }),
                environment: environment
            ),
            initialState: initialState
        )
        self._environment = environment
        self.file = file
        self.fromScopedAction = { $0 }
        self.line = line
        self.reducer = reducer
        self.store = Store(initialState: initialState, reducer: reducer)
        self.timeout = 100 * NSEC_PER_MSEC
        self.toScopedState = { $0 }
    }
    
    init(
        _environment: Box<Context>,
        file: StaticString,
        fromScopedAction: @escaping (ScopedAction) -> Reducer.Action,
        line: UInt,
        reducer: TestReducer<Reducer>,
        store: Store<Reducer.State, TestReducer<Reducer>.Action>,
        timeout: UInt64 = 100 * NSEC_PER_MSEC,
        toScopedState: @escaping (Reducer.State) -> ScopedState
    ) {
        self._environment = _environment
        self.file = file
        self.fromScopedAction = fromScopedAction
        self.line = line
        self.reducer = reducer
        self.store = store
        self.timeout = timeout
        self.toScopedState = toScopedState
    }
    
//#if swift(>=5.7)
//    /// Suspends until all in-flight effects have finished, or until it times out.
//    ///
//    /// Can be used to assert that all effects have finished.
//    ///
//    /// - Parameter duration: The amount of time to wait before asserting.
//    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
//    @MainActor
//    public func finish(
//        timeout duration: Duration,
//        file: StaticString = #file,
//        line: UInt = #line
//    ) async {
//        await self.finish(timeout: duration.nanoseconds, file: file, line: line)
//    }
//#endif
//
//    /// Suspends until all in-flight effects have finished, or until it times out.
//    ///
//    /// Can be used to assert that all effects have finished.
//    ///
//    /// - Parameter nanoseconds: The amount of time to wait before asserting.
//    @available(iOS 13.0, *)
//    @MainActor
//    public func finish(
//        timeout nanoseconds: UInt64? = nil,
//        file: StaticString = #file,
//        line: UInt = #line
//    ) async {
//        let nanoseconds = nanoseconds ?? self.timeout
//        let start = DispatchTime.now().uptimeNanoseconds
//        await Task.megaYield()
//        while !self.reducer.inFlightEffects.isEmpty {
//            guard start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds
//            else {
//                let timeoutMessage =
//                nanoseconds != self.self.timeout
//                ? #"try increasing the duration of this assertion's "timeout""#
//                : #"configure this assertion with an explicit "timeout""#
//                let suggestion = """
//            There are effects in-flight. If the effect that delivers this action uses a \
//            scheduler (via "receive(on:)", "delay", "debounce", etc.), make sure that you wait \
//            enough time for the scheduler to perform the effect. If you are using a test \
//            scheduler, advance the scheduler so that the effects may complete, or consider using \
//            an immediate scheduler to immediately perform the effect instead.
//
//            If you are not yet using a scheduler, or can not use a scheduler, \(timeoutMessage).
//            """
//
//                XCTFail(
//            """
//            Expected effects to finish, but there are still effects in-flight\
//            \(nanoseconds > 0 ? " after \(Double(nanoseconds)/Double(NSEC_PER_SEC)) seconds" : "").
//
//            \(suggestion)
//            """,
//            file: file,
//            line: line
//                )
//                return
//            }
//            await Task.yield()
//        }
//    }
    
    deinit {
        self.completed()
    }
    
    func completed() {
        if !self.reducer.receivedActions.isEmpty {
            var actions = ""
            customDump(self.reducer.receivedActions.map(\.action), to: &actions)
            XCTFail(
          """
          The store received \(self.reducer.receivedActions.count) unexpected \
          action\(self.reducer.receivedActions.count == 1 ? "" : "s") after this one: …
          
          Unhandled actions: \(actions)
          """,
          file: self.file, line: self.line
            )
        }
        for effect in self.reducer.inFlightEffects {
            XCTFail(
          """
          An effect returned for this action is still running. It must complete before the end of \
          the test. …
          
          To fix, inspect any effects the reducer returns for this action and ensure that all of \
          them complete by the end of the test. There are a few reasons why an effect may not have \
          completed:
          
          • If using async/await in your effect, it may need a little bit of time to properly \
          finish. To fix you can simply perform "await store.finish()" at the end of your test.
          
          • If an effect uses a scheduler (via "receive(on:)", "delay", "debounce", etc.), make \
          sure that you wait enough time for the scheduler to perform the effect. If you are using \
          a test scheduler, advance the scheduler so that the effects may complete, or consider \
          using an immediate scheduler to immediately perform the effect instead.
          
          • If you are returning a long-living effect (timers, notifications, subjects, etc.), \
          then make sure those effects are torn down by marking the effect ".cancellable" and \
          returning a corresponding cancellation effect ("Effect.cancel") from another action, or, \
          if your effect is driven by a Combine subject, send it a completion.
          """,
          file: effect.file,
          line: effect.line
            )
        }
    }
}

extension TestStore where ScopedState: Equatable {
    public func send(
        _ action: ScopedAction,
        _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if !self.reducer.receivedActions.isEmpty {
            var actions = ""
            customDump(self.reducer.receivedActions.map(\.action), to: &actions)
            XCTFail(
                """
                Must handle \(reducer.receivedActions.count) received \
                action\(reducer.receivedActions.count == 1 ? "" : "s") before sending an action: …
                
                Unhandled actions: \(action)
                """,
                file: file, line: line
            )
        }
        var expectedState = toScopedState(self.state)
        let previousState = self.state
        self.store.send(.init(origin: .send(fromScopedAction(action)), file: file, line: line))
        do {
            let currentState = self.state
            self.reducer.state = previousState
            defer { self.reducer.state = currentState }
            try expectedStateShouldMatch(
                expected: &expectedState,
                actual: toScopedState(currentState),
                modify: updateExpectingResult,
                file: file,
                line: line
            )
        } catch {
            XCTFail("Threw error: \(error)", file: file, line: line)
        }
        
        if "\(self.file)" == "\(file)" {
            self.line = line
        }
    }
    
    private func expectedStateShouldMatch(
        expected: inout ScopedState,
        actual: ScopedState,
        modify: ((inout ScopedState) throws -> Void)? = nil,
        file: StaticString,
        line: UInt
    ) throws {
        let current = expected
        if let modify = modify {
            try modify(&expected)
        }
        
        if expected != actual {
            let difference =
            diff(expected, actual, format: .proportional)
                .map { "\($0.indent(by: 4))\n\n(Expected: −, Actual: +)" }
            ?? """
          Expected:
          \(String(describing: expected).indent(by: 2))
          
          Actual:
          \(String(describing: actual).indent(by: 2))
          """
            
            let messageHeading =
            modify != nil
            ? "A state change does not match expectation"
            : "State was not expected to change, but a change occurred"
            XCTFail(
          """
          \(messageHeading): …
          
          \(difference)
          """,
          file: file,
          line: line
            )
        } else if expected == current && modify != nil {
            XCTFail(
          """
          Expected state to change, but no change occurred.
          
          The trailing closure made no observable modifications to state. If no change to state is \
          expected, omit the trailing closure.
          """,
          file: file, line: line
            )
        }
    }
}

extension TestStore where ScopedState: Equatable, Reducer.Action: Equatable {
    /// Asserts an action was received from an effect and asserts when state changes.
    ///
    /// - Parameters:
    ///   - expectedAction: An action expected from an effect.
    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
    ///     store. The mutable state sent to this closure must be modified to match the state of the
    ///     store after processing the given action. Do not provide a closure if no change is
    ///     expected.
    public func receive(
        _ expectedAction: Reducer.Action,
        _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard !reducer.receivedActions.isEmpty else {
            XCTFail(
                """
                Expected to receive an action, but received none.
                """,
                file: file, line: line
            )
            return
        }
        let (receivedAction, state) = reducer.receivedActions.removeFirst()
        if expectedAction != receivedAction {
            let difference =
            diff(expectedAction, receivedAction, format: .proportional)
                .map { "\($0.indent(by: 4))\n\n(Expected: −, Received: +)" }
            ?? """
            Expected:
            \(String(describing: expectedAction).indent(by: 2))
            
            Received:
            \(String(describing: receivedAction).indent(by: 2))
            """
            
            XCTFail(
                """
                Received unexpected action: …
                
                \(difference)
                """,
                file: file, line: line
            )
        }
        var expectedState = toScopedState(self.state)
        do {
            try expectedStateShouldMatch(
                expected: &expectedState,
                actual: toScopedState(state),
                modify: updateExpectingResult,
                file: file,
                line: line
            )
        } catch {
            XCTFail("Threw error: \(error)", file: file, line: line)
        }
        
        self.reducer.state = state
        if "\(self.file)" == "\(file)" {
            self.line = line
        }
    }
}

extension TestStore {
    /// Scopes a store to assert against scoped state and actions.
    ///
    /// Useful for testing view store-specific state and actions.
    ///
    /// - Parameters:
    ///   - toScopedState: A function that transforms the reducer's state into scoped state. This
    ///     state will be asserted against as it is mutated by the reducer. Useful for testing view
    ///     store state transformations.
    ///   - fromScopedAction: A function that wraps a more scoped action in the reducer's action.
    ///     Scoped actions can be "sent" to the store, while any reducer action may be received.
    ///     Useful for testing view store action transformations.
    public func scope<S, A>(
        state toScopedState: @escaping (ScopedState) -> S,
        action fromScopedAction: @escaping (A) -> ScopedAction
    ) -> TestStore<Reducer, S, A, Context> {
        .init(
            _environment: self._environment,
            file: self.file,
            fromScopedAction: { self.fromScopedAction(fromScopedAction($0)) },
            line: self.line,
            reducer: self.reducer,
            store: self.store,
            timeout: self.timeout,
            toScopedState: { toScopedState(self.toScopedState($0)) }
        )
    }
    
    /// Scopes a store to assert against scoped state.
    ///
    /// Useful for testing view store-specific state.
    ///
    /// - Parameter toScopedState: A function that transforms the reducer's state into scoped state.
    ///   This state will be asserted against as it is mutated by the reducer. Useful for testing
    ///   view store state transformations.
    public func scope<S>(
        state toScopedState: @escaping (ScopedState) -> S
    ) -> TestStore<Reducer, S, ScopedAction, Context> {
        self.scope(state: toScopedState, action: { $0 })
    }
}

#if DEBUG
extension TestStore where ScopedState: Equatable, Reducer.Action: Equatable {
    @available(
        *, deprecated, message: "Use 'TestStore.send' and 'TestStore.receive' directly, instead."
    )
    public func assert(
        _ steps: Step...,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assert(steps, file: file, line: line)
    }
    
    @available(
        *, deprecated, message: "Use 'TestStore.send' and 'TestStore.receive' directly, instead."
    )
    public func assert(
        _ steps: [Step],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        
        func assert(step: Step) {
            switch step.type {
            case let .send(action, update):
                self.send(action, update, file: step.file, line: step.line)
                
            case let .receive(expectedAction, update):
                self.receive(expectedAction, update, file: step.file, line: step.line)
                
            case let .environment(work):
                if !self.reducer.receivedActions.isEmpty {
                    var actions = ""
                    customDump(self.reducer.receivedActions.map(\.action), to: &actions)
                    XCTFail(
              """
              Must handle \(self.reducer.receivedActions.count) received \
              action\(self.reducer.receivedActions.count == 1 ? "" : "s") before performing this \
              work: …
              
              Unhandled actions: \(actions)
              """,
              file: step.file, line: step.line
                    )
                }
                do {
                    try work(&self.environment)
                } catch {
                    XCTFail("Threw error: \(error)", file: step.file, line: step.line)
                }
                
            case let .do(work):
                if !self.reducer.receivedActions.isEmpty {
                    var actions = ""
                    customDump(self.reducer.receivedActions.map(\.action), to: &actions)
                    XCTFail(
              """
              Must handle \(self.reducer.receivedActions.count) received \
              action\(self.reducer.receivedActions.count == 1 ? "" : "s") before performing this \
              work: …
              
              Unhandled actions: \(actions)
              """,
              file: step.file, line: step.line
                    )
                }
                do {
                    try work()
                } catch {
                    XCTFail("Threw error: \(error)", file: step.file, line: step.line)
                }
                
            case let .sequence(subSteps):
                subSteps.forEach(assert(step:))
            }
        }
        
        steps.forEach(assert(step:))
        
        self.completed()
    }
    
    public struct Step {
        fileprivate let type: StepType
        fileprivate let file: StaticString
        fileprivate let line: UInt
        
        private init(
            _ type: StepType,
            file: StaticString = #file,
            line: UInt = #line
        ) {
            self.type = type
            self.file = file
            self.line = line
        }
        
        @available(*, deprecated, message: "Call 'TestStore.send' directly, instead.")
        public static func send(
            _ action: ScopedAction,
            file: StaticString = #file,
            line: UInt = #line,
            _ update: ((inout ScopedState) throws -> Void)? = nil
        ) -> Step {
            Step(.send(action, update), file: file, line: line)
        }
        
        @available(*, deprecated, message: "Call 'TestStore.receive' directly, instead.")
        public static func receive(
            _ action: Reducer.Action,
            file: StaticString = #file,
            line: UInt = #line,
            _ update: ((inout ScopedState) throws -> Void)? = nil
        ) -> Step {
            Step(.receive(action, update), file: file, line: line)
        }
        
        @available(*, deprecated, message: "Mutate 'TestStore.environment' directly, instead.")
        public static func environment(
            file: StaticString = #file,
            line: UInt = #line,
            _ update: @escaping (inout Context) throws -> Void
        ) -> Step {
            Step(.environment(update), file: file, line: line)
        }
        
        @available(*, deprecated, message: "Perform this work directly in your test, instead.")
        public static func `do`(
            file: StaticString = #file,
            line: UInt = #line,
            _ work: @escaping () throws -> Void
        ) -> Step {
            Step(.do(work), file: file, line: line)
        }
        
        @available(*, deprecated, message: "Perform this work directly in your test, instead.")
        public static func sequence(
            _ steps: [Step],
            file: StaticString = #file,
            line: UInt = #line
        ) -> Step {
            Step(.sequence(steps), file: file, line: line)
        }
        
        @available(*, deprecated, message: "Perform this work directly in your test, instead.")
        public static func sequence(
            _ steps: Step...,
            file: StaticString = #file,
            line: UInt = #line
        ) -> Step {
            Step(.sequence(steps), file: file, line: line)
        }
        
        fileprivate indirect enum StepType {
            case send(ScopedAction, ((inout ScopedState) throws -> Void)?)
            case receive(Reducer.Action, ((inout ScopedState) throws -> Void)?)
            case environment((inout Context) throws -> Void)
            case `do`(() throws -> Void)
            case sequence([Step])
        }
    }
}
#endif

class TestReducer<Base: ReducerProtocol>: ReducerProtocol {
    let base: Base
    var dependencies = { () -> DependencyValues in
        var dependencies = DependencyValues()
        dependencies.context = .test
        return dependencies
    }()
    var inFlightEffects: Set<LongLivingEffect> = []
    var receivedActions: [(action: Base.Action, state: Base.State)] = []
    var state: Base.State
    
    init(
        _ base: Base,
        initialState: Base.State
    ) {
        self.base = base
        self.state = initialState
    }
    
    func reduce(into state: inout Base.State, action: Action) -> Effect<Action> {
        let reducer = self.base.dependency(\.self, self.dependencies)
        
        let effects: Effect<Base.Action>
        switch action.origin {
        case let .send(action):
            effects = reducer.reduce(into: &state, action: action)
            self.state = state
            
        case let .receive(action):
            effects = reducer.reduce(into: &state, action: action)
            self.receivedActions.append((action, state))
        }
        
        let effect = LongLivingEffect(file: action.file, line: action.line)
        return effects
            .do(
                onCompleted: { [weak self] in self?.inFlightEffects.remove(effect) },
                onSubscribe: { [weak self] in self?.inFlightEffects.insert(effect) },
                onDispose: { [weak self] in self?.inFlightEffects.remove(effect) }
            )
            .map { .init(origin: .receive($0), file: action.file, line: action.line) }
            .eraseToEffect()
    }
    
    struct LongLivingEffect: Hashable {
        let id = UUID()
        let file: StaticString
        let line: UInt
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            self.id.hash(into: &hasher)
        }
    }
    
    struct Action {
        let origin: Origin
        let file: StaticString
        let line: UInt
        
        enum Origin {
            case send(Base.Action)
            case receive(Base.Action)
        }
    }
}
#endif
