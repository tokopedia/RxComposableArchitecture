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
    ///     case let .textChanged(text):
    ///       struct SearchId: Hashable {}
    ///
    ///     case let .textChanged(text):
    ///       struct SearchId: Hashable {}
    ///
    ///       return environment.search(text)
    ///         .map(Action.searchResponse)
    ///         .deferred(for: .milliseconds(500), scheduler: environment.mainQueue)
    ///
    /// - Parameters:
    ///   - for: The duration you want to deferred for.
    ///   - scheduler: The scheduler you want to deliver the deferred output to.
    /// - Returns: An effect that will be executed after `dueTime`
    public func deferred(
        for dueTime: RxTimeInterval,
        scheduler: SchedulerType
    ) -> Effect<Element> {
        Observable.just(())
            .delay(dueTime, scheduler: scheduler)
            .flatMap { self }
            .eraseToEffect()
    }
}
