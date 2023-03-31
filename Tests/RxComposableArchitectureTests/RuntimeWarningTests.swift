#if DEBUG
import RxComposableArchitecture
import RxSwift
import XCTest

final class RuntimeWarningTests: XCTestCase {
    func testStoreCreationMainThread() {
        XCTExpectFailure {
            $0.compactDescription == """
          A store initialized on a non-main thread. …
          
          The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
          (including all of its scopes and derived view stores) must be done on the main thread.
          """
        }
        
        Task {
            _ = Store<Int, Void>(initialState: 0, reducer: EmptyReducer())
        }
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.5)
    }
    
    func testEffectFinishedMainThread() {
        XCTExpectFailure {
            $0.compactDescription == """
          An effect completed on a non-main thread. …
          
            Effect returned from:
              RuntimeWarningTests.Action.tap
          
          Make sure to use ".receive(on:)" on any effects that execute on background threads to \
          receive their output on the main thread.
          
          The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
          (including all of its scopes and derived view stores) must be done on the main thread.
          """
        }
        
        enum Action { case tap, response }
        let store = Store(
            initialState: 0,
            reducer: Reduce<Int, Action> { state, action in
                switch action {
                case .tap:
                    return Observable<Action>.empty()
                        .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                        .eraseToEffect()
                case .response:
                    return .none
                }
            }
        )
        store.send(.tap)
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.5)
    }
    
    func testStoreScopeMainThread() {
        XCTExpectFailure {
            [
          """
          "Store.scope" was called on a non-main thread. …
          
          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """,
          """
          A store initialized on a non-main thread. …
          
          The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
          (including all of its scopes and derived view stores) must be done on the main thread.
          """,
            ].contains($0.compactDescription)
        }
        
        let store = Store<Int, Void>(initialState: 0, reducer: EmptyReducer())
        Task {
            _ = store.scope(state: { $0 })
        }
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.5)
    }
    
    func testStoreSendMainThread() {
        XCTExpectFailure {
            $0.compactDescription == """
          "Store.send/ViewStore.send" was called on a non-main thread with: () …
          
          The "Store" class is not thread-safe, and so all interactions with an instance of "Store" (including all of its scopes and derived view stores) must be done on the main thread.
          """
        }
        
        let store = Store<Int, Void>(initialState: 0, reducer: EmptyReducer())
        Task {
            store.send(())
        }
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.5)
    }
}
#endif
