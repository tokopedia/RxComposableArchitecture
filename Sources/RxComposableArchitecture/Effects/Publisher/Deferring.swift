import Combine

extension EffectPublisher {
  /// Returns an effect that will be executed after given `dueTime`.
  ///
  /// ```swift
  /// case let .textChanged(text):
  ///   return self.apiClient.search(text)
  ///     .deferred(for: 0.5, scheduler: self.mainQueue)
  ///     .map(Action.searchResponse)
  /// ```
  ///
  /// - Parameters:
  ///   - dueTime: The duration you want to defer for.
  ///   - scheduler: The scheduler you want to deliver the defer output to.
  ///   - options: Scheduler options that customize the effect's delivery of elements.
  /// - Returns: An effect that will be executed after `dueTime`
  @available(
    iOS, deprecated: 9999.0, message: "Use 'clock.sleep' in `Effect.task` or 'Effect.run', instead."
  )
  @available(
    macOS, deprecated: 9999.0,
    message: "Use 'clock.sleep' in `Effect.task` or 'Effect.run', instead."
  )
  @available(
    tvOS, deprecated: 9999.0,
    message: "Use 'clock.sleep' in `Effect.task` or 'Effect.run', instead."
  )
  @available(
    watchOS, deprecated: 9999.0,
    message: "Use 'clock.sleep' in `Effect.task` or 'Effect.run', instead."
  )
  public func deferred<S: Scheduler>(
    for dueTime: S.SchedulerTimeType.Stride,
    scheduler: S,
    options: S.SchedulerOptions? = nil
  ) -> Self {
    switch self.operation {
    case .none:
      return .none
    case .publisher, .run:
      return Self(
        operation: .publisher(
          Just(())
            .setFailureType(to: Failure.self)
            .delay(for: dueTime, scheduler: scheduler, options: options)
            .flatMap { self.publisher.receive(on: scheduler) }
            .eraseToAnyPublisher()
        )
      )
    }
  }
}

import RxSwift

extension Effect {
    /// Returns an effect that will be executed after given `dueTime`.
    ///
    /// ```swift
    /// case let .textChanged(text):
    ///   return environment.search(text)
    ///     .deferred(for: 0.5, scheduler: environment.mainQueue)
    ///     .map(Action.searchResponse)
    /// ```
    ///
    /// - Parameters:
    ///   - upstream: the effect you want to defer.
    ///   - dueTime: The duration you want to defer for.
    ///   - scheduler: The scheduler you want to deliver the defer output to.
    ///   - options: Scheduler options that customize the effect's delivery of elements.
    /// - Returns: An effect that will be executed after `dueTime`
    public func deferred(
        for dueTime: RxTimeInterval,
        scheduler: SchedulerType
    ) -> Effect<Element> {
        switch self.operation {
        case .none:
            return .none
        case .publisher, .run:
            let publisher = Just(())
                .asObservable()
                .delay(dueTime, scheduler: scheduler)
                .flatMap { self.asObservable().observeOn(scheduler)}
                .asPublisher()
                .catch { _ in Empty<Element, Never>(completeImmediately: true) } // Ignore errors
                .eraseToAnyPublisher()
            return Effect(operation: .publisher(publisher))
        }
    }
}

