//
//  Timer.swift
//  RxComposableArchitecture_RxComposableArchitecture
//
//  Created by Jefferson Setiawan on 02/02/21.
//

import RxSwift

extension Effect where Action: RxAbstractInteger {
    /// Returns an effect that repeatedly emits the current time of the given scheduler on the given
    /// interval.
    ///
    /// While it is possible to use Foundation's `Timer.publish(every:tolerance:on:in:options:)` API
    /// to create a timer in the Composable Architecture, it is not advisable. This API only allows
    /// creating a timer on a run loop, which means when writing tests you will need to explicitly
    /// wait for time to pass in order to see how the effect evolves in your feature.
    ///
    /// In the Composable Architecture we test time-based effects like this by using the
    /// `TestScheduler`, which allows us to explicitly and immediately advance time forward so that
    /// we can see how effects emit. However, because `Timer.publish` takes a concrete `RunLoop` as
    /// its scheduler, we can't substitute in a `TestScheduler` during tests`.
    ///
    /// That is why we provide `Effect.timer`. It allows you to create a timer that works with any
    /// scheduler, not just a run loop, which means you can use a `DispatchQueue` or `RunLoop` when
    /// running your live app, but use a `TestScheduler` in tests.
    ///
    /// To start and stop a timer in your feature you can create the timer effect from an action
    /// and then use the ``Effect/cancel(id:)-iun1`` effect to stop the timer:
    ///
    /// ```swift
    /// struct Feature: ReducerProtocol {
    ///   struct State { var count = 0 }
    ///   enum Action { case startButtonTapped, stopButtonTapped, timerTicked }
    ///   @Dependency(\.mainQueue) var mainQueue
    ///   struct TimerID: Hashable {}
    ///
    ///   func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    ///     switch action {
    ///     case .startButtonTapped:
    ///       return Effect.timer(id: TimerID(), every: 1, on: self.mainQueue)
    ///         .map { _ in .timerTicked }
    ///
    ///     case .stopButtonTapped:
    ///       return .cancel(id: TimerID())
    ///
    ///     case let .timerTicked:
    ///       state.count += 1
    ///       return .none
    ///   }
    /// }
    /// ```
    ///
    /// Then to test the timer in this feature you can use a test scheduler to advance time:
    ///
    /// ```swift
    /// @MainActor
    /// func testTimer() async {
    ///   let mainQueue = DispatchQueue.test
    ///
    ///   let store = TestStore(
    ///     initialState: Feature.State(),
    ///     reducer: Feature()
    ///   )
    ///
    ///   store.dependencies.mainQueue = mainQueue.eraseToAnyScheduler()
    ///
    ///   await store.send(.startButtonTapped)
    ///
    ///   await mainQueue.advance(by: .seconds(1))
    ///   await store.receive(.timerTicked) { $0.count = 1 }
    ///
    ///   await mainQueue.advance(by: .seconds(5))
    ///   await store.receive(.timerTicked) { $0.count = 2 }
    ///   await store.receive(.timerTicked) { $0.count = 3 }
    ///   await store.receive(.timerTicked) { $0.count = 4 }
    ///   await store.receive(.timerTicked) { $0.count = 5 }
    ///   await store.receive(.timerTicked) { $0.count = 6 }
    ///
    ///   await store.send(.stopButtonTapped)
    /// }
    /// ```
    ///
    /// - Note: This effect is only meant to be used with features built in the Composable
    ///   Architecture, and returned from a reducer. If you want a testable alternative to
    ///   Foundation's `Timer.publish` you can use the publisher `Publishers.Timer` that is included
    ///   in this library via the
    ///   [`CombineSchedulers`](https://github.com/pointfreeco/combine-schedulers) module.
    ///
    /// - Parameters:
    ///   - id: The effect's identifier.
    ///   - interval: The time interval on which to publish events. For example, a value of `0.5`
    ///     publishes an event approximately every half-second.
    ///   - scheduler: The scheduler on which the timer runs.
    ///   - tolerance: The allowed timing variance when emitting events. Defaults to `nil`, which
    ///     allows any variance.
    ///   - options: Scheduler options passed to the timer. Defaults to `nil`.
    @available(iOS, deprecated: 9999.0, message: "Use 'scheduler.timer' in 'Effect.run', instead.")
    public static func timer(
        id: AnyHashable,
        every interval: RxTimeInterval,
        on scheduler: SchedulerType
    ) -> Effect {
        Observable
            .interval(interval, scheduler: scheduler)
            .eraseToEffect()
            .cancellable(id: id, cancelInFlight: true)
    }
    
    /// Returns an effect that repeatedly emits the current time of the given scheduler on the given
    /// interval.
    ///
    /// A convenience for calling ``Effect/timer(id:every:tolerance:on:options:)-4exe6`` with a
    /// static type as the effect's unique identifier.
    ///
    /// - Parameters:
    ///   - id: A unique type identifying the effect.
    ///   - interval: The time interval on which to publish events. For example, a value of `0.5`
    ///     publishes an event approximately every half-second.
    ///   - scheduler: The scheduler on which the timer runs.
    ///   - tolerance: The allowed timing variance when emitting events. Defaults to `nil`, which
    ///     allows any variance.
    ///   - options: Scheduler options passed to the timer. Defaults to `nil`.
    @available(iOS, deprecated: 9999.0, message: "Use 'scheduler.timer' in 'Effect.run', instead.")
    public static func timer(
        id: Any.Type,
        every interval: RxTimeInterval,
        on scheduler: SchedulerType
    ) -> Self {
        self.timer(
            id: ObjectIdentifier(id),
            every: interval,
            on: scheduler
        )
    }
}
