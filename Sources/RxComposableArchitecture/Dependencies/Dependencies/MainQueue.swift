import RxSwift
import Foundation

extension DependencyValues {
    /// The "main" queue.
    ///
    /// Introduce controllable timing to your features by using the ``Dependency`` property wrapper
    /// with a key path to this property. The wrapped value is a Combine scheduler with the time
    /// type and options of a dispatch queue. By default, `DispatchQueue.main` will be provided,
    /// with the exception of XCTest cases, in which an "unimplemented" scheduler will be provided.
    ///
    /// For example, you could introduce controllable timing to a Composable Architecture reducer
    /// that counts the number of seconds it's onscreen:
    ///
    /// ```
    /// struct TimerReducer: ReducerProtocol {
    ///   struct State {
    ///     var elapsed = 0
    ///   }
    ///
    ///   enum Action {
    ///     case task
    ///     case timerTicked
    ///   }
    ///
    ///   @Dependency(\.mainQueue) var mainQueue
    ///
    ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    ///     switch action {
    ///     case .task:
    ///       return .run { send in
    ///         for await _ in self.mainQueue.timer(interval: .seconds(1)) {
    ///           send(.timerTicked)
    ///         }
    ///       }
    ///
    ///     case .timerTicked:
    ///       state.elapsed += 1
    ///       return .none
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// And you could test this reducer by overriding its main queue with a test scheduler:
    ///
    /// ```
    /// let mainQueue = DispatchQueue.test
    ///
    /// let store = TestStore(
    ///   initialState: TimerReducer.State()
    ///   reducer: TimerReducer()
    ///     .dependency(\.mainQueue, mainQueue.eraseToAnyScheduler())
    /// )
    ///
    /// let task = store.send(.task)
    ///
    /// mainQueue.advance(by: .seconds(1)
    /// await store.receive(.timerTicked) {
    ///   $0.elapsed = 1
    /// }
    /// mainQueue.advance(by: .seconds(1)
    /// await store.receive(.timerTicked) {
    ///   $0.elapsed = 2
    /// }
    /// await task.cancel()
    /// ```
    public var mainQueue: SchedulerType {
        get { self[MainQueueKey.self] }
        set { self[MainQueueKey.self] = newValue }
    }
    
    fileprivate enum MainQueueKey: DependencyKey {
        static let liveValue: SchedulerType = MainScheduler.instance
    }
}

#if DEBUG
import XCTestDynamicOverlay
extension DependencyValues.MainQueueKey: TestDependencyKey {
    static let testValue: SchedulerType = UnimplementedSchedulerType()
}

internal final class UnimplementedSchedulerType: SchedulerType {
    internal var now: RxSwift.RxTime
    
    internal init() {
        XCTFail("mainQueue is unimplemented")
        self.now = Date()
    }
    
    internal func scheduleRelative<StateType>(_ state: StateType, dueTime: RxSwift.RxTimeInterval, action: @escaping (StateType) -> RxSwift.Disposable) -> RxSwift.Disposable {
        unimplemented("mainQueue is unimplemented", placeholder: Disposables.create())
    }
    
    internal func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> RxSwift.Disposable) -> RxSwift.Disposable {
        unimplemented("mainQueue is unimplemented", placeholder: Disposables.create())
    }
}
#endif
