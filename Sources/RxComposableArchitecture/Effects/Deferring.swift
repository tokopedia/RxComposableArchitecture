//
//  Deffering.swift
//  RxComposableArchitecture
//
//  Created by Wendy Liga on 19/05/21.
//

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
        Observable.just(())
            .delay(dueTime, scheduler: scheduler)
            .flatMap { self.observeOn(scheduler) }
            .eraseToEffect()
    }
}
