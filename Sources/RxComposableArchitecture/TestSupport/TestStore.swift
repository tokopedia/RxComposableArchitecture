#if DEBUG
import Foundation
import RxSwift
import XCTestDynamicOverlay

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
public final class TestStore<State, Action, ScopedState, ScopedAction, Environment> {
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
    public var environment: Environment {
      _read { yield self._environment.wrappedValue }
      _modify { yield &self._environment.wrappedValue }
    }
    
    /// The current state.
    ///
    /// When read from a trailing closure assertion in ``send(_:_:file:line:)-6s1gq`` or
    /// ``receive(_:timeout:_:file:line:)``, it will equal the `inout` state passed to the closure.
    public var state: State {
      self.reducer.state
    }
    
    /// The timeout to await for in-flight effects.
    ///
    /// This is the default timeout used in all methods that take an optional timeout, such as
    /// ``receive(_:timeout:_:file:line:)`` and ``finish(timeout:file:line:)``.
    public var timeout: UInt64
    
    private var _environment: Box<Environment>
    private let file: StaticString
    private let fromScopedAction: (ScopedAction) -> Action
    private var line: UInt
//    let reducer: TestReducer<State, Action>
//    private let store: Store<State, TestReducer<State, Action>.TestAction>
    private let toScopedState: (State) -> ScopedState
    
    private let failingWhenNothingChange: Bool
    private let useNewScope: Bool

    public var stateDiffMode: DiffMode = .distinct
    public var actionDiffMode: DiffMode = .distinct
    
    private init(
        environment: Environment,
        file: StaticString,
        fromLocalAction: @escaping (ScopedAction) -> Action,
        initialState: State,
        line: UInt,
        reducer: Reducer<State, Action, Environment>,
        toLocalState: @escaping (State) -> ScopedState,
        failingWhenNothingChange: Bool,
        useNewScope: Bool
    ) {
        self.environment = environment
        self.file = file
        self.fromLocalAction = fromLocalAction
        self.line = line
        self.reducer = reducer
        state = initialState
        self.toLocalState = toLocalState
        self.failingWhenNothingChange = failingWhenNothingChange
        self.useNewScope = useNewScope
        
        store = Store(
            initialState: initialState,
            reducer: Reducer<State, TestAction, Void> { [unowned self] state, action, _ in
                let effects: Effect<Action>
                switch action.origin {
                case let .send(localAction):
                    effects = self.reducer.run(&state, self.fromLocalAction(localAction), self.environment)
                    self.state = state
                    
                case let .receive(action):
                    effects = self.reducer.run(&state, action, self.environment)
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
            },
            environment: (),
            useNewScope: useNewScope
        )
    }
    
    deinit {
        self.completed()
    }
    
    private func completed() {
        if !receivedActions.isEmpty {
            var actions = ""
            customDump(self.receivedActions.map(\.action), to: &actions)
            XCTFail(
                """
                The store received \(receivedActions.count) unexpected \
                action\(receivedActions.count == 1 ? "" : "s") after this one: …
                
                Unhandled actions: \(actions)
                """,
                file: file, line: line
            )
        }
        for effect in inFlightEffects {
            XCTFail(
                """
                An effect returned for this action is still running. It must complete before the end of \
                the test. …
                
                To fix, inspect any effects the reducer returns for this action and ensure that all of \
                them complete by the end of the test. There are a few reasons why an effect may not have \
                completed:
                
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
    
    private struct LongLivingEffect: Hashable {
        let id = UUID()
        let file: StaticString
        let line: UInt
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            id.hash(into: &hasher)
        }
    }
    
    private struct TestAction: CustomDebugStringConvertible {
        let origin: Origin
        let file: StaticString
        let line: UInt
        
        enum Origin {
            case send(ScopedAction)
            case receive(Action)
        }
        
        var debugDescription: String {
            switch self.origin {
            case let .send(action):
                return debugCaseOutput(action)
                
            case let .receive(action):
                return debugCaseOutput(action)
            }
        }
    }
}

extension TestStore where State == ScopedState, Action == ScopedAction {
    /// Initializes a test store from an initial state, a reducer, and an initial environment.
    ///
    /// - Parameters:
    ///   - initialState: The state to start the test from.
    ///   - reducer: A reducer.
    ///   - environment: The environment to start the test from.
    ///   - failingWhenNothingChange: Flag to failing the test if the trailing closure on send and receive  is provided but nothing is changed
    ///   - useNewScope: Use improved store.
    public convenience init(
        initialState: State,
        reducer: Reducer<State, Action, Environment>,
        environment: Environment,
        failingWhenNothingChange: Bool = true,
        useNewScope: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        self.init(
            environment: environment,
            file: file,
            fromLocalAction: { $0 },
            initialState: initialState,
            line: line,
            reducer: reducer,
            toLocalState: { $0 },
            failingWhenNothingChange: failingWhenNothingChange,
            useNewScope: useNewScope
        )
    }
}

extension TestStore where ScopedState: Equatable {
    public func send(
        _ action: ScopedAction,
        file: StaticString = #file,
        line: UInt = #line,
        _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil
    ) {
        if !receivedActions.isEmpty {
            var actions = ""
            customDump(self.receivedActions.map(\.action), to: &actions)
            XCTFail(
                """
                Must handle \(receivedActions.count) received \
                action\(receivedActions.count == 1 ? "" : "s") before sending an action: …
                
                Unhandled actions: \(action)
                """,
                file: file, line: line
            )
        }
        var expectedState = toLocalState(self.state)
        let previousState = self.state
        self.store.send(.init(origin: .send(action), file: file, line: line))
        do {
            let currentState = self.state
            self.state = previousState
            defer { self.state = currentState }
            try expectedStateShouldMatch(
                expected: &expectedState,
                actual: toLocalState(currentState),
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
            
            let messageHeading = modify != nil
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
        } else if expected == current && modify != nil && failingWhenNothingChange {
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

extension TestStore where ScopedState: Equatable, Action: Equatable {
    /// Asserts an action was received from an effect and asserts when state changes.
    ///
    /// - Parameters:
    ///   - expectedAction: An action expected from an effect.
    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
    ///     store. The mutable state sent to this closure must be modified to match the state of the
    ///     store after processing the given action. Do not provide a closure if no change is
    ///     expected.
    public func receive(
        _ expectedAction: Action,
        file: StaticString = #file,
        line: UInt = #line,
        _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil
    ) {
        guard !receivedActions.isEmpty else {
            XCTFail(
                """
                Expected to receive an action, but received none.
                """,
                file: file, line: line
            )
            return
        }
        let (receivedAction, state) = receivedActions.removeFirst()
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
        var expectedState = toLocalState(self.state)
        do {
            try expectedStateShouldMatch(
                expected: &expectedState,
                actual: toLocalState(state),
                modify: updateExpectingResult,
                file: file,
                line: line
            )
        } catch {
            XCTFail("Threw error: \(error)", file: file, line: line)
        }
        
        self.state = state
        if "\(self.file)" == "\(file)" {
            self.line = line
        }
    }
    
    /// Asserts against a script of actions.
    public func assert(
        _ steps: Step...,
        groupLevel: Int = 0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assert(steps, groupLevel: groupLevel, file: file, line: line)
    }
    
    /// Asserts against an array of actions.
    public func assert(
        _ steps: [Step],
        groupLevel: Int = 0,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        func assert(step: Step) {
            switch step.type {
            case let .send(action, update):
                self.send(action, file: step.file, line: step.line, update)
            case let .receive(expectedAction, update):
                self.receive(expectedAction, file: step.file, line: step.line, update)
            case let .environment(work):
                if !self.receivedActions.isEmpty {
                    var actions = ""
                    customDump(self.receivedActions.map(\.action), to: &actions)
                    XCTFail(
                        """
                        Must handle \(self.receivedActions.count) received \
                        action\(self.receivedActions.count == 1 ? "" : "s") before performing this work: …
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
                if !self.receivedActions.isEmpty {
                    var actions = ""
                    customDump(self.receivedActions.map(\.action), to: &actions)
                    XCTFail(
                        """
                        Must handle \(self.receivedActions.count) received \
                        action\(self.receivedActions.count == 1 ? "" : "s") before performing this work: …
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
            case let .group(_, steps):
                if steps.count > 0 {
                    self.assert(
                        steps,
                        groupLevel: groupLevel + 1,
                        file: step.file,
                        line: step.line
                    )
                }
                return
            }
        }
        
        steps.forEach(assert(step:))
        
        self.completed()
    }
}

extension TestStore {
    /// Scopes a store to assert against more local state and actions.
    ///
    /// Useful for testing view store-specific state and actions.
    ///
    /// - Parameters:
    ///   - toLocalState: A function that transforms the reducer's state into more local state. This
    ///     state will be asserted against as it is mutated by the reducer. Useful for testing view
    ///     store state transformations.
    ///   - fromLocalAction: A function that wraps a more local action in the reducer's action.
    ///     Local actions can be "sent" to the store, while any reducer action may be received.
    ///     Useful for testing view store action transformations.
    public func scope<S, A>(
        state toLocalState: @escaping (ScopedState) -> S,
        action fromLocalAction: @escaping (A) -> ScopedAction
    ) -> TestStore<State, S, Action, A, Environment> {
        .init(
            environment: environment,
            file: file,
            fromLocalAction: { self.fromLocalAction(fromLocalAction($0)) },
            initialState: store.state,
            line: line,
            reducer: reducer,
            toLocalState: { toLocalState(self.toLocalState($0)) },
            failingWhenNothingChange: failingWhenNothingChange,
            useNewScope: useNewScope
        )
    }
    
    /// Scopes a store to assert against more local state.
    ///
    /// Useful for testing view store-specific state.
    ///
    /// - Parameter toLocalState: A function that transforms the reducer's state into more local
    ///   state. This state will be asserted against as it is mutated by the reducer. Useful for
    ///   testing view store state transformations.
    public func scope<S>(
        state toLocalState: @escaping (ScopedState) -> S
    ) -> TestStore<State, S, Action, ScopedAction, Environment> {
        scope(state: toLocalState, action: { $0 })
    }
    
    /// Deprecated
    /// A single step of a `TestStore` assertion.
    public struct Step {
        internal let type: StepType
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
        
        /// A step that describes an action sent to a store and asserts against how the store's state
        /// is expected to change.
        ///
        /// - Parameters:
        ///   - action: An action to send to the test store.
        ///   - update: A function that describes how the test store's state is expected to change.
        /// - Returns: A step that describes an action sent to a store and asserts against how the
        ///   store's state is expected to change.
        public static func send(
            _ action: ScopedAction,
            _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
            file: StaticString = #file,
            line: UInt = #line
        ) -> Step {
            Step(.send(action, updateExpectingResult), file: file, line: line)
        }
        
        /// A step that describes an action received by an effect and asserts against how the store's
        /// state is expected to change.
        ///
        /// - Parameters:
        ///   - action: An action the test store should receive by evaluating an effect.
        ///   - update: A function that describes how the test store's state is expected to change.
        /// - Returns: A step that describes an action received by an effect and asserts against how
        ///   the store's state is expected to change.
        public static func receive(
            _ action: Action,
            _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
            file: StaticString = #file,
            line: UInt = #line
        ) -> Step {
            Step(.receive(action, updateExpectingResult), file: file, line: line)
        }
        
        /// A step that updates a test store's environment.
        ///
        /// - Parameter update: A function that updates the test store's environment for subsequent
        ///   steps.
        /// - Returns: A step that updates a test store's environment.
        public static func environment(
            file: StaticString = #file,
            line: UInt = #line,
            _ update: @escaping (inout Environment) throws -> Void
        ) -> Step {
            Step(.environment(update), file: file, line: line)
        }
        
        /// A step that captures some work to be done between assertions
        ///
        /// - Parameter work: A function that is called between steps.
        /// - Returns: A step that captures some work to be done between assertions.
        public static func `do`(
            file: StaticString = #file,
            line: UInt = #line,
            _ work: @escaping () throws -> Void
        ) -> Step {
            Step(.do(work), file: file, line: line)
        }
        
        /// A step that captures a sub-sequence of steps.
        ///
        /// - Parameter steps: An array of `Step`
        /// - Returns: A step that captures a sub-sequence of steps.
        public static func group(
            _ name: String,
            file: StaticString = #file,
            line: UInt = #line,
            _ steps: Step...
        ) -> Step {
            Step(.group(name, steps), file: file, line: line)
        }
        
        internal enum StepType {
            case send(ScopedAction, ((inout ScopedState) throws -> Void)?)
            case receive(Action, ((inout ScopedState) throws -> Void)?)
            case environment((inout Environment) throws -> Void)
            case `do`(() throws -> Void)
            case group(String, [Step])
        }
    }
    
    public struct Annotating {
        public typealias StepResultCallback = (Bool) -> Void
        
        public var annotate: (Step, Int, @escaping (@escaping StepResultCallback) -> Void) -> Void
        
        public init(annotate: @escaping (Step, Int, @escaping (@escaping StepResultCallback) -> Void) -> Void) {
            self.annotate = annotate
        }
        
        public static func combine(_ annotatings: Annotating...) -> Self {
            return Annotating { step, groupLevel, callback in
                var combinedCallbacks: [StepResultCallback] = []
                
                for annotating in annotatings {
                    annotating.annotate(step, groupLevel) { resultCallback in
                        combinedCallbacks.append(resultCallback)
                    }
                }
                
                callback { stepResult in
                    for callback in combinedCallbacks {
                        callback(stepResult)
                    }
                }
            }
        }
        
        public static var none: Self {
            Self { _, _, callback in
                callback { _ in }
            }
        }
    }
}

/// The type returned from ``TestStore/send(_:_:file:line:)-6s1gq`` that represents the lifecycle
/// of the effect started from sending an action.
///
/// You can use this value in tests to cancel the effect started from sending an action:
///
/// ```swift
/// // Simulate the "task" view modifier invoking some async work
/// let task = store.send(.task)
///
/// // Simulate the view cancelling this work on dismissal
/// await task.cancel()
/// ```
///
/// You can also explicitly wait for an effect to finish:
///
/// ```swift
/// store.send(.startTimerButtonTapped)
///
/// await mainQueue.advance(by: .seconds(1))
/// await store.receive(.timerTick) { $0.elapsed = 1 }
///
/// // Wait for cleanup effects to finish before completing the test
/// await store.send(.stopTimerButtonTapped).finish()
/// ```
///
/// See ``TestStore/finish(timeout:file:line:)`` for the ability to await all in-flight effects in
/// the test store.
///
/// See ``ViewStoreTask`` for the analog provided to ``ViewStore``.
public struct TestStoreTask: Hashable, Sendable {
  fileprivate let rawValue: Task<Void, Never>?
  fileprivate let timeout: UInt64

  /// Cancels the underlying task and waits for it to finish.
  public func cancel() async {
    self.rawValue?.cancel()
    await self.rawValue?.cancellableValue
  }

  // NB: Only needed until Xcode ships a macOS SDK that uses the 5.7 standard library.
  // See: https://forums.swift.org/t/xcode-14-rc-cannot-specialize-protocol-type/60171/15
  #if swift(>=5.7) && !os(macOS) && !targetEnvironment(macCatalyst)
    /// Asserts the underlying task finished.
    ///
    /// - Parameter duration: The amount of time to wait before asserting.
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func finish(
      timeout duration: Duration? = nil,
      file: StaticString = #file,
      line: UInt = #line
    ) async {
      await self.finish(timeout: duration?.nanoseconds, file: file, line: line)
    }
  #endif

  /// Asserts the underlying task finished.
  ///
  /// - Parameter nanoseconds: The amount of time to wait before asserting.
  @_disfavoredOverload
  public func finish(
    timeout nanoseconds: UInt64? = nil,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    let nanoseconds = nanoseconds ?? self.timeout
    await Task.megaYield()
    do {
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { await self.rawValue?.cancellableValue }
        group.addTask {
          try await Task.sleep(nanoseconds: nanoseconds)
          throw CancellationError()
        }
        try await group.next()
        group.cancelAll()
      }
    } catch {
      let timeoutMessage =
        nanoseconds != self.timeout
        ? #"try increasing the duration of this assertion's "timeout""#
        : #"configure this assertion with an explicit "timeout""#
      let suggestion = """
        If this task delivers its action using a scheduler (via "sleep(for:)", \
        "timer(interval:)", etc.), make sure that you wait enough time for the scheduler to \
        perform its work. If you are using a test scheduler, advance the scheduler so that the \
        effects may complete, or consider using an immediate scheduler to immediately perform \
        the effect instead.

        If you are not yet using a scheduler, or can not use a scheduler, \(timeoutMessage).
        """

      XCTFail(
        """
        Expected task to finish, but it is still in-flight\
        \(nanoseconds > 0 ? " after \(Double(nanoseconds)/Double(NSEC_PER_SEC)) seconds" : "").

        \(suggestion)
        """,
        file: file,
        line: line
      )
    }
  }

  /// A Boolean value that indicates whether the task should stop executing.
  ///
  /// After the value of this property becomes `true`, it remains `true` indefinitely. There is
  /// no way to uncancel a task.
  public var isCancelled: Bool {
    self.rawValue?.isCancelled ?? true
  }
}

//class TestReducer<State, Action>: ReducerProtocol {
//  let base: Reduce<State, Action>
//  var dependencies = { () -> DependencyValues in
//    var dependencies = DependencyValues()
//    dependencies.context = .test
//    return dependencies
//  }()
//  let effectDidSubscribe = AsyncStream<Void>.streamWithContinuation()
//  var inFlightEffects: Set<LongLivingEffect> = []
//  var receivedActions: [(action: Action, state: State)] = []
//  var state: State
//
//  init(
//    _ base: Reduce<State, Action>,
//    initialState: State
//  ) {
//    self.base = base
//    self.state = initialState
//  }
//
//  func reduce(into state: inout State, action: TestAction) -> Effect<TestAction> {
//    let reducer = self.base.dependency(\.self, self.dependencies)
//
//    let effects: Effect<Action, Never>
//    switch action.origin {
//    case let .send(action):
//      effects = reducer.reduce(into: &state, action: action)
//      self.state = state
//
//    case let .receive(action):
//      effects = reducer.reduce(into: &state, action: action)
//      self.receivedActions.append((action, state))
//    }
//
//    switch effects.operation {
//    case .none:
//      self.effectDidSubscribe.continuation.yield()
//      return .none
//
//    case .publisher, .run:
//      let effect = LongLivingEffect(file: action.file, line: action.line)
//      return
//        effects
//        .handleEvents(
//          receiveSubscription: { [effectDidSubscribe, weak self] _ in
//            self?.inFlightEffects.insert(effect)
//            Task {
//              await Task.megaYield()
//              effectDidSubscribe.continuation.yield()
//            }
//          },
//          receiveCompletion: { [weak self] _ in self?.inFlightEffects.remove(effect) },
//          receiveCancel: { [weak self] in self?.inFlightEffects.remove(effect) }
//        )
//        .map { .init(origin: .receive($0), file: action.file, line: action.line) }
//        .eraseToEffect()
//    }
//  }
//
//  struct LongLivingEffect: Hashable {
//    let id = UUID()
//    let file: StaticString
//    let line: UInt
//
//    static func == (lhs: Self, rhs: Self) -> Bool {
//      lhs.id == rhs.id
//    }
//
//    func hash(into hasher: inout Hasher) {
//      self.id.hash(into: &hasher)
//    }
//  }
//
//  struct TestAction {
//    let origin: Origin
//    let file: StaticString
//    let line: UInt
//
//    enum Origin {
//      case send(Action)
//      case receive(Action)
//    }
//  }
//}

extension Task where Success == Never, Failure == Never {
  @_spi(Internals) public static func megaYield(count: Int = 10) async {
    for _ in 1...count {
      await Task<Void, Never>.detached(priority: .low) { await Task.yield() }.value
    }
  }
}

#endif
