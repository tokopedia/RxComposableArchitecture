import Foundation
import RxSwift

/// Turns an effect into one that can be debounced.
///
/// To turn an effect into a debounce-able one you must provide an identifier, which is used to
/// determine which in-flight effect should be canceled in order to start a new effect. Any
/// hashable value can be used for the identifier, such as a string, but you can add a bit of
/// protection against typos by defining a new type that conforms to `Hashable`, such as an empty
/// struct:
///
///     case let .textChanged(text):
///       struct SearchId: Hashable {}
///
///       return environment.search(text)
///         .map(Action.searchResponse)
///         .debounce(id: SearchId(), for: 0.5, scheduler: environment.mainQueue)
///
/// - Parameters:
///   - id: The effect's identifier.
///   - dueTime: The duration you want to debounce for.
///     scheduler: The scheduler you want to deliver the debounced output to.
/// - Returns: An effect that publishes events only after a specified time elapses.

extension Effect {
    public func debounce(
        id: AnyHashable,
        for dueTime: RxTimeInterval,
        scheduler: SchedulerType
    ) -> Effect<Element> {
        Observable.just(())
            .delay(dueTime, scheduler: scheduler)
            .flatMap { self.observeOn(scheduler) }
            .eraseToEffect()
            .cancellable(id: id, cancelInFlight: true)
    }

    /// Turns an effect into one that can be debounced.
    ///
    /// A convenience for calling ``Effect/debounce(id:for:scheduler:options:)-76yye`` with a static
    /// type as the effect's unique identifier.
    ///
    /// - Parameters:
    ///   - id: A unique type identifying the effect.
    ///   - dueTime: The duration you want to debounce for.
    ///   - scheduler: The scheduler you want to deliver the debounced output to.
    ///   - options: Scheduler options that customize the effect's delivery of elements.
    /// - Returns: An effect that publishes events only after a specified time elapses.
    public func debounce(
        id: Any.Type,
        for dueTime: RxTimeInterval,
        scheduler: SchedulerType
    ) -> Effect<Element> {
        self.debounce(id: ObjectIdentifier(id), for: dueTime, scheduler: scheduler)
    }
}
