//
//  Timer.swift
//  RxComposableArchitecture_RxComposableArchitecture
//
//  Created by Jefferson Setiawan on 02/02/21.
//

import RxSwift

extension Effect where Output: RxAbstractInteger {
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
    /// That is why we provide the `Effect.timer` effect. It allows you to create a timer that works
    /// with any scheduler, not just a run loop, which means you can use a `DispatchQueue` or
    /// `RunLoop` when running your live app, but use a `TestScheduler` in tests.
    ///
    /// To start and stop a timer in your feature you can create the timer effect from an action
    /// and then use the `.cancel(id:)` effect to stop the timer:
    ///
    ///     struct AppState {
    ///       var count = 0
    ///     }
    ///
    ///     enum AppAction {
    ///       case startButtonTapped, stopButtonTapped, timerTicked
    ///     }
    ///
    ///     struct AppEnvironment {
    ///       var mainQueue: AnySchedulerOf<DispatchQueue>
    ///     }
    ///
    ///     let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
    ///       struct TimerId: Hashable {}
    ///
    ///       switch action {
    ///       case .startButtonTapped:
    ///         return Effect.timer(id: TimerId(), every: 1, on: env.mainQueue)
    ///           .map { _ in .timerTicked }
    ///
    ///       case .stopButtonTapped:
    ///         return .cancel(id: TimerId())
    ///
    ///       case let .timerTicked:
    ///         state.count += 1
    ///         return .none
    ///     }
    ///
    /// Then to test the timer in this feature you can use a test scheduler to advance time:
    ///
    ///   func testTimer() {
    ///     let scheduler = DispatchQueue.testScheduler
    ///
    ///     let store = TestStore(
    ///       initialState: .init(),
    ///       reducer: appReducer,
    ///       envirnoment: .init(
    ///         mainQueue: scheduler.eraseToAnyScheduler()
    ///       )
    ///     )
    ///
    ///     store.assert(
    ///       .send(.startButtonTapped),
    ///
    ///       .do { scheduler.advance(by: .seconds(1)) },
    ///       .receive(.timerTicked) { $0.count = 1 },
    ///
    ///       .do { scheduler.advance(by: .seconds(5)) },
    ///       .receive(.timerTicked) { $0.count = 2 },
    ///       .receive(.timerTicked) { $0.count = 3 },
    ///       .receive(.timerTicked) { $0.count = 4 },
    ///       .receive(.timerTicked) { $0.count = 5 },
    ///       .receive(.timerTicked) { $0.count = 6 },
    ///
    ///       .send(.stopButtonTapped)
    ///     )
    ///   }
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
    public static func timer(
        id: AnyHashable,
        every interval: RxTimeInterval,
        on scheduler: SchedulerType
    ) -> Effect {
        Observable
            .interval(interval, scheduler: scheduler)
            .eraseToEffect()
            .cancellable(id: id)
    }
}
