//import Foundation
//
//extension TestStore where ScopedState: Equatable {
//    /// Sends an action to the store and asserts when state changes.
//    ///
//    /// This method suspends in order to allow any effects to start. For example, if you
//    /// track an analytics event in a ``Effect/fireAndForget(priority:_:)`` when an action is sent,
//    /// you can assert on that behavior immediately after awaiting `store.send`:
//    ///
//    /// ```swift
//    /// @MainActor
//    /// func testAnalytics() async {
//    ///   let events = ActorIsolated<[String]>([])
//    ///   let analytics = AnalyticsClient(
//    ///     track: { event in
//    ///       await events.withValue { $0.append(event) }
//    ///     }
//    ///   )
//    ///
//    ///   let store = TestStore(
//    ///     initialState: State(),
//    ///     reducer: reducer,
//    ///     environment: Environment(analytics: analytics)
//    ///   )
//    ///
//    ///   await store.send(.buttonTapped)
//    ///
//    ///   await events.withValue { XCTAssertEqual($0, ["Button Tapped"]) }
//    /// }
//    /// ```
//    ///
//    /// This method suspends only for the duration until the effect _starts_ from sending the
//    /// action. It does _not_ suspend for the duration of the effect.
//    ///
//    /// In order to suspend for the duration of the effect you can use its return value, a
//    /// ``TestStoreTask``, which represents the lifecycle of the effect started from sending an
//    /// action. You can use this value to suspend until the effect finishes, or to force the
//    /// cancellation of the effect, which is helpful for effects that are tied to a view's lifecycle
//    /// and not torn down when an action is sent, such as actions sent in SwiftUI's `task` view
//    /// modifier.
//    ///
//    /// For example, if your feature kicks off a long-living effect when the view appears by using
//    /// SwiftUI's `task` view modifier, then you can write a test for such a feature by explicitly
//    /// canceling the effect's task after you make all assertions:
//    ///
//    /// ```swift
//    /// let store = TestStore(...)
//    ///
//    /// // emulate the view appearing
//    /// let task = await store.send(.task)
//    ///
//    /// // assertions
//    ///
//    /// // emulate the view disappearing
//    /// await task.cancel()
//    /// ```
//    ///
//    /// - Parameters:
//    ///   - action: An action.
//    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
//    ///     store. The mutable state sent to this closure must be modified to match the state of the
//    ///     store after processing the given action. Do not provide a closure if no change is
//    ///     expected.
//    /// - Returns: A ``TestStoreTask`` that represents the lifecycle of the effect executed when
//    ///   sending the action.
//    @available(iOS 13.0, *)
//    @MainActor
//    @discardableResult
//    public func send(
//        _ action: ScopedAction,
//        _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
//        file: StaticString = #file,
//        line: UInt = #line
//    ) async -> TestStoreTask {
//        if !self.reducer.receivedActions.isEmpty {
//            var actions = ""
//            customDump(self.reducer.receivedActions.map(\.action), to: &actions)
//            XCTFail(
//          """
//          Must handle \(self.reducer.receivedActions.count) received \
//          action\(self.reducer.receivedActions.count == 1 ? "" : "s") before sending an action: …
//
//          Unhandled actions: \(actions)
//          """,
//          file: file, line: line
//            )
//        }
//        var expectedState = self.toScopedState(self.state)
//        let previousState = self.reducer.state
//        let task: Task<Void, Never>? = self.store
//            .send(.init(origin: .send(self.fromScopedAction(action)), file: file, line: line))
//        await Task.megaYield()
//        do {
//            let currentState = self.state
//            self.reducer.state = previousState
//            defer { self.reducer.state = currentState }
//
//            try self.expectedStateShouldMatch(
//                expected: &expectedState,
//                actual: self.toScopedState(currentState),
//                modify: updateExpectingResult,
//                file: file,
//                line: line
//            )
//        } catch {
//            XCTFail("Threw error: \(error)", file: file, line: line)
//        }
//        if "\(self.file)" == "\(file)" {
//            self.line = line
//        }
//        await Task.megaYield()
//        return .init(rawValue: task, timeout: self.timeout)
//    }
//    
//    /// Sends an action to the store and asserts when state changes.
//    ///
//    /// This method returns a ``TestStoreTask``, which represents the lifecycle of the effect
//    /// started from sending an action. You can use this value to force the cancellation of the
//    /// effect, which is helpful for effects that are tied to a view's lifecycle and not torn
//    /// down when an action is sent, such as actions sent in SwiftUI's `task` view modifier.
//    ///
//    /// For example, if your feature kicks off a long-living effect when the view appears by using
//    /// SwiftUI's `task` view modifier, then you can write a test for such a feature by explicitly
//    /// canceling the effect's task after you make all assertions:
//    ///
//    /// ```swift
//    /// let store = TestStore(...)
//    ///
//    /// // emulate the view appearing
//    /// let task = await store.send(.task)
//    ///
//    /// // assertions
//    ///
//    /// // emulate the view disappearing
//    /// await task.cancel()
//    /// ```
//    ///
//    /// - Parameters:
//    ///   - action: An action.
//    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
//    ///     store. The mutable state sent to this closure must be modified to match the state of the
//    ///     store after processing the given action. Do not provide a closure if no change is
//    ///     expected.
//    /// - Returns: A ``TestStoreTask`` that represents the lifecycle of the effect executed when
//    ///   sending the action.
//    @available(iOS, introduced: 13.0, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
//    @available(macOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
//    @available(tvOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
//    @available(watchOS, deprecated: 9999.0, message: "Call the async-friendly 'send' instead.")
//    @discardableResult
//    public func send(
//        _ action: ScopedAction,
//        _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
//        file: StaticString = #file,
//        line: UInt = #line
//    ) -> TestStoreTask {
//        if !self.reducer.receivedActions.isEmpty {
//            var actions = ""
//            customDump(self.reducer.receivedActions.map(\.action), to: &actions)
//            XCTFail(
//          """
//          Must handle \(self.reducer.receivedActions.count) received \
//          action\(self.reducer.receivedActions.count == 1 ? "" : "s") before sending an action: …
//
//          Unhandled actions: \(actions)
//          """,
//          file: file, line: line
//            )
//        }
//        var expectedState = self.toScopedState(self.state)
//        let previousState = self.state
//        let task: Task<Void, Never>? = self.store
//            .send(.init(origin: .send(self.fromScopedAction(action)), file: file, line: line))
//        do {
//            let currentState = self.state
//            self.reducer.state = previousState
//            defer { self.reducer.state = currentState }
//
//            try self.expectedStateShouldMatch(
//                expected: &expectedState,
//                actual: self.toScopedState(currentState),
//                modify: updateExpectingResult,
//                file: file,
//                line: line
//            )
//        } catch {
//            XCTFail("Threw error: \(error)", file: file, line: line)
//        }
//        if "\(self.file)" == "\(file)" {
//            self.line = line
//        }
//
//        return .init(rawValue: task, timeout: self.timeout)
//    }
//}


//extension TestStore where ScopedState: Equatable, Reducer.Action: Equatable {
//    /// Asserts an action was received from an effect and asserts when state changes.
//    ///
//    /// - Parameters:
//    ///   - expectedAction: An action expected from an effect.
//    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
//    ///     store. The mutable state sent to this closure must be modified to match the state of the
//    ///     store after processing the given action. Do not provide a closure if no change is
//    ///     expected.
//    @available(iOS, introduced: 13.0, deprecated: 9999.0, message: "Call the async-friendly 'receive' instead.")
//    @available(macOS, deprecated: 9999.0, message: "Call the async-friendly 'receive' instead.")
//    @available(tvOS, deprecated: 9999.0, message: "Call the async-friendly 'receive' instead.")
//    @available(watchOS, deprecated: 9999.0, message: "Call the async-friendly 'receive' instead.")
//    public func receive(
//        _ expectedAction: Reducer.Action,
//        _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
//        file: StaticString = #file,
//        line: UInt = #line
//    ) {
//        guard !self.reducer.receivedActions.isEmpty else {
//            XCTFail(
//          """
//          Expected to receive an action, but received none.
//          """,
//          file: file, line: line
//            )
//            return
//        }
//        let (receivedAction, state) = self.reducer.receivedActions.removeFirst()
//        if expectedAction != receivedAction {
//            let difference = TaskResultDebugging.$emitRuntimeWarnings.withValue(false) {
//                diff(expectedAction, receivedAction, format: .proportional)
//                    .map { "\($0.indent(by: 4))\n\n(Expected: −, Received: +)" }
//                ?? """
//            Expected:
//            \(String(describing: expectedAction).indent(by: 2))
//
//            Received:
//            \(String(describing: receivedAction).indent(by: 2))
//            """
//            }
//
//            XCTFail(
//          """
//          Received unexpected action: …
//
//          \(difference)
//          """,
//          file: file, line: line
//            )
//        }
//        var expectedState = self.toScopedState(self.state)
//        do {
//            try expectedStateShouldMatch(
//                expected: &expectedState,
//                actual: self.toScopedState(state),
//                modify: updateExpectingResult,
//                file: file,
//                line: line
//            )
//        } catch {
//            XCTFail("Threw error: \(error)", file: file, line: line)
//        }
//        self.reducer.state = state
//        if "\(self.file)" == "\(file)" {
//            self.line = line
//        }
//    }
//
//#if swift(>=5.7)
//    /// Asserts an action was received from an effect and asserts how the state changes.
//    ///
//    /// - Parameters:
//    ///   - expectedAction: An action expected from an effect.
//    ///   - duration: The amount of time to wait for the expected action.
//    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to
//    ///     the store. The mutable state sent to this closure must be modified to match the state
//    ///     of the store after processing the given action. Do not provide a closure if no change
//    ///     is expected.
//    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
//    @MainActor
//    public func receive(
//        _ expectedAction: Reducer.Action,
//        timeout duration: Duration,
//        _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
//        file: StaticString = #file,
//        line: UInt = #line
//    ) async {
//        await self.receive(
//            expectedAction,
//            timeout: duration.nanoseconds,
//            updateExpectingResult,
//            file: file,
//            line: line
//        )
//    }
//#endif
//
//    /// Asserts an action was received from an effect and asserts how the state changes.
//    ///
//    /// - Parameters:
//    ///   - expectedAction: An action expected from an effect.
//    ///   - nanoseconds: The amount of time to wait for the expected action.
//    ///   - updateExpectingResult: A closure that asserts state changed by sending the action to the
//    ///     store. The mutable state sent to this closure must be modified to match the state of the
//    ///     store after processing the given action. Do not provide a closure if no change is
//    ///     expected.
//    @available(iOS 13.0, *)
//    @MainActor
//    public func receive(
//        _ expectedAction: Reducer.Action,
//        timeout nanoseconds: UInt64? = nil,
//        _ updateExpectingResult: ((inout ScopedState) throws -> Void)? = nil,
//        file: StaticString = #file,
//        line: UInt = #line
//    ) async {
//        let nanoseconds = nanoseconds ?? self.timeout
//
//        guard !self.reducer.inFlightEffects.isEmpty
//        else {
//            { self.receive(expectedAction, updateExpectingResult, file: file, line: line) }()
//            return
//        }
//
//        await Task.megaYield()
//        let start = DispatchTime.now().uptimeNanoseconds
//        while !Task.isCancelled {
//            await Task.detached(priority: .low) { await Task.yield() }.value
//
//            guard self.reducer.receivedActions.isEmpty
//            else { break }
//
//            guard start.distance(to: DispatchTime.now().uptimeNanoseconds) < nanoseconds
//            else {
//                let suggestion: String
//                if self.reducer.inFlightEffects.isEmpty {
//                    suggestion = """
//              There are no in-flight effects that could deliver this action. Could the effect you \
//              expected to deliver this action have been cancelled?
//              """
//                } else {
//                    let timeoutMessage =
//                    nanoseconds != self.timeout
//                    ? #"try increasing the duration of this assertion's "timeout""#
//                    : #"configure this assertion with an explicit "timeout""#
//                    suggestion = """
//              There are effects in-flight. If the effect that delivers this action uses a \
//              scheduler (via "receive(on:)", "delay", "debounce", etc.), make sure that you wait \
//              enough time for the scheduler to perform the effect. If you are using a test \
//              scheduler, advance the scheduler so that the effects may complete, or consider using \
//              an immediate scheduler to immediately perform the effect instead.
//
//              If you are not yet using a scheduler, or can not use a scheduler, \(timeoutMessage).
//              """
//                }
//                XCTFail(
//            """
//            Expected to receive an action, but received none\
//            \(nanoseconds > 0 ? " after \(Double(nanoseconds)/Double(NSEC_PER_SEC)) seconds" : "").
//
//            \(suggestion)
//            """,
//            file: file,
//            line: line
//                )
//                return
//            }
//        }
//
//        guard !Task.isCancelled
//        else { return }
//
//        { self.receive(expectedAction, updateExpectingResult, file: file, line: line) }()
//        await Task.megaYield()
//    }
//}

/// The type returned from ``TestStore/send(_:_:file:line:)-3pf4p`` that represents the lifecycle
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
/// See ``TestStore/finish(timeout:file:line:)-53gi5`` for the ability to await all in-flight
/// effects in the test store.
///
/// See ``ViewStoreTask`` for the analog provided to ``ViewStore``.
//@available(iOS 13.0, *)
//public struct TestStoreTask: Hashable, Sendable {
//    fileprivate let rawValue: Task<Void, Never>?
//    fileprivate let timeout: UInt64
//
//    /// Cancels the underlying task and waits for it to finish.
//    public func cancel() async {
//        self.rawValue?.cancel()
//        await self.rawValue?.cancellableValue
//    }
//
//#if swift(>=5.7)
//    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
//    /// Asserts the underlying task finished.
//    ///
//    /// - Parameter duration: The amount of time to wait before asserting.
//    public func finish(
//        timeout duration: Duration,
//        file: StaticString = #file,
//        line: UInt = #line
//    ) async {
//        await self.finish(timeout: duration.nanoseconds, file: file, line: line)
//    }
//#endif
    
    /// Asserts the underlying task finished.
    ///
    /// - Parameter nanoseconds: The amount of time to wait before asserting.
//    public func finish(
//        timeout nanoseconds: UInt64? = nil,
//        file: StaticString = #file,
//        line: UInt = #line
//    ) async {
//        let nanoseconds = nanoseconds ?? self.timeout
//        await Task.megaYield()
//        do {
//            try await withThrowingTaskGroup(of: Void.self) { group in
//                group.addTask { await self.rawValue?.cancellableValue }
//                group.addTask {
//                    try await Task.sleep(nanoseconds: nanoseconds)
//                    throw CancellationError()
//                }
//                try await group.next()
//                group.cancelAll()
//            }
//        } catch {
//            let timeoutMessage =
//            nanoseconds != self.timeout
//            ? #"try increasing the duration of this assertion's "timeout""#
//            : #"configure this assertion with an explicit "timeout""#
//            let suggestion = """
//          If this task delivers its action using a scheduler (via "sleep(for:)", \
//          "timer(interval:)", etc.), make sure that you wait enough time for the scheduler to \
//          perform its work. If you are using a test scheduler, advance the scheduler so that the \
//          effects may complete, or consider using an immediate scheduler to immediately perform \
//          the effect instead.
//
//          If you are not yet using a scheduler, or can not use a scheduler, \(timeoutMessage).
//          """
//
//            XCTFail(
//          """
//          Expected task to finish, but it is still in-flight\
//          \(nanoseconds > 0 ? " after \(Double(nanoseconds)/Double(NSEC_PER_SEC)) seconds" : "").
//
//          \(suggestion)
//          """,
//          file: file,
//          line: line
//            )
//        }
//    }
    
    /// A Boolean value that indicates whether the task should stop executing.
    ///
    /// After the value of this property becomes `true`, it remains `true` indefinitely. There is
    /// no way to uncancel a task.
//    public var isCancelled: Bool {
//        self.rawValue?.isCancelled ?? true
//    }
//}

//@available(iOS 13.0, *)
//extension Task where Success == Never, Failure == Never {
//    static func megaYield(count: Int = 3) async {
//        for _ in 1...count {
//            await Task<Void, Never>.detached(priority: .low) { await Task.yield() }.value
//        }
//    }
//}
//
//#if swift(>=5.7)
//@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
//extension Duration {
//    fileprivate var nanoseconds: UInt64 {
//        UInt64(self.components.seconds) * NSEC_PER_SEC
//        + UInt64(self.components.attoseconds) / 1_000_000_000
//    }
//}
//#endif
//#endif
