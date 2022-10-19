import RxSwift
import SwiftUI

extension Effect {
    /// Wraps the emission of each element with SwiftUI's `withAnimation`.
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   return .task {
    ///     .activityResponse(await self.apiClient.fetchActivity())
    ///   }
    ///   .animation()
    /// ```
    ///
    /// - Parameter animation: An animation.
    /// - Returns: A publisher.
    public func animation(_ animation: Animation? = .default) -> Self {
        switch self.operation {
        case .none:
            return .none
        case let .observable(observable):
            return Self(
                operation: .observable(
                    AnimatedPublisher(upstream: observable, animation: animation).asObservable()
                )
            )
        case let .run(priority, operation):
            return Self(
                operation: .run(priority) { send in
                    await operation(
                        Send { value in
                            withAnimation(animation) {
                                send(value)
                            }
                        }
                    )
                }
            )
        }
    }
}

private struct AnimatedPublisher<Upstream: ObservableType>: ObservableType {
    public typealias Element = Upstream.Element
    
    var upstream: Upstream
    var animation: Animation?
    
    func subscribe<Observer>(_ observer: Observer) -> Disposable where Observer : ObserverType, Element == Observer.Element {
        let conduit = Subscriber(downstream: observer, animation: self.animation)
        return self.upstream.subscribe(conduit)
    }
    
    private final class Subscriber<Downstream: ObserverType>: ObserverType {
        public typealias Element = Downstream.Element
        
        let downstream: Downstream
        let animation: Animation?
        
        init(downstream: Downstream, animation: Animation?) {
            self.downstream = downstream
            self.animation = animation
        }
        
        func on(_ event: RxSwift.Event<Downstream.Element>) {
            withAnimation {
                self.downstream.on(event)
            }
        }
        
    }
}
