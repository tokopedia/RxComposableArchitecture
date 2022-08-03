import RxSwift
import XCTest

@testable import RxComposableArchitecture

internal final class StoreTests: XCTestCase {
    private let disposeBag = DisposeBag()

    internal func testCancellableIsRemovedOnImmediatelyCompletingEffect() {
        let reducer = Reducer<Void, Void, Void> { _, _, _ in .none }
        let store = Store(initialState: (), reducer: reducer, environment: ())

        XCTAssertEqual(store.effectDisposables.count, 0)

        store.send(())

        XCTAssertEqual(store.effectDisposables.count, 0)
    }

    internal func testCancellableIsRemovedWhenEffectCompletes() {
        let scheduler = TestScheduler(initialClock: 0)
        let effect = Effect<Void>(value: ())
            .delay(.seconds(1), scheduler: scheduler)
            .eraseToEffect()

        enum Action { case start, end }

        let reducer = Reducer<Void, Action, Void> { _, action, _ in
            switch action {
            case .start:
                return effect.map { .end }
            case .end:
                return .none
            }
        }
        let store = Store(initialState: (), reducer: reducer, environment: ())

        XCTAssertEqual(store.effectDisposables.count, 0)

        store.send(.start)

        XCTAssertEqual(store.effectDisposables.count, 1)

        scheduler.advance(by: .seconds(2))

        XCTAssertEqual(store.effectDisposables.count, 0)
    }

    internal func testScopedStoreReceivesUpdatesFromParent() {
        let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
            state += 1
            return .none
        }

        let parentStore = Store(initialState: 0, reducer: counterReducer, environment: ())
        let childStore = parentStore.scope(state: String.init)

        var values: [String] = []
        childStore.subscribe { $0 }
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        XCTAssertEqual(values, ["0"])

        parentStore.send(())

        XCTAssertEqual(values, ["0", "1"])
    }

    internal func testParentStoreReceivesUpdatesFromChild() {
        let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
            state += 1
            return .none
        }

        let parentStore = Store(initialState: 0, reducer: counterReducer, environment: ())
        let childStore = parentStore.scope(state: String.init)

        var values: [Int] = []

        parentStore.subscribe { $0 }
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        XCTAssertEqual(values, [0])

        childStore.send(())

        XCTAssertEqual(values, [0, 1])
    }

    internal func testScopeWithPublisherTransform() {
        let counterReducer = Reducer<Int, Int, Void> { state, action, _ in
            state = action
            return .none
        }
        let parentStore = Store(initialState: 0, reducer: counterReducer, environment: ())

        var outputs: [String] = []

        parentStore
            .scope(state: { $0.map { "\($0)" }.distinctUntilChanged() })
            .subscribe(onNext: { childStore in
                childStore.observable
                    .subscribe(onNext: { outputs.append($0) })
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)

        parentStore.send(0)
        XCTAssertEqual(outputs, ["0"])
        parentStore.send(0)
        XCTAssertEqual(outputs, ["0"])
        parentStore.send(1)
        XCTAssertEqual(outputs, ["0", "1"])
        parentStore.send(1)
        XCTAssertEqual(outputs, ["0", "1"])
        parentStore.send(2)
        XCTAssertEqual(outputs, ["0", "1", "2"])
    }

    internal func testScopeCallCount() {
        let counterReducer = Reducer<Int, Void, Void> { state, _, _ in state += 1
            return .none
        }

        var numCalls1 = 0
        _ = Store(initialState: 0, reducer: counterReducer, environment: ())
            .scope(state: { (count: Int) -> Int in
                numCalls1 += 1
                return count
            })

        XCTAssertEqual(numCalls1, 2)
    }

    internal func testScopeCallCount2() {
        let counterReducer = Reducer<Int, Void, Void> { state, _, _ in
            state += 1
            return .none
        }

        var numCalls1 = 0
        var numCalls2 = 0
        var numCalls3 = 0

        let store = Store(initialState: 0, reducer: counterReducer, environment: ())
            .scope(state: { (count: Int) -> Int in
                numCalls1 += 1
                return count
            })
            .scope(state: { (count: Int) -> Int in
                numCalls2 += 1
                return count
            })
            .scope(state: { (count: Int) -> Int in
                numCalls3 += 1
                return count
            })

        XCTAssertEqual(numCalls1, 2)
        XCTAssertEqual(numCalls2, 2)
        XCTAssertEqual(numCalls3, 2)

        store.send(())

        XCTAssertEqual(numCalls1, 4)
        XCTAssertEqual(numCalls2, 5)
        XCTAssertEqual(numCalls3, 6)

        store.send(())

        XCTAssertEqual(numCalls1, 6)
        XCTAssertEqual(numCalls2, 8)
        XCTAssertEqual(numCalls3, 10)

        store.send(())

        XCTAssertEqual(numCalls1, 8)
        XCTAssertEqual(numCalls2, 11)
        XCTAssertEqual(numCalls3, 14)
    }

    internal func testSynchronousEffectsSentAfterSinking() {
        enum Action {
            case tap
            case next1
            case next2
            case end
        }
        var values: [Int] = []
        let counterReducer = Reducer<Void, Action, Void> { _, action, _ in
            switch action {
            case .tap:
                return .merge(
                    Effect(value: .next1),
                    Effect(value: .next2),
                    .fireAndForget { values.append(1) }
                )
            case .next1:
                return .merge(
                    Effect(value: .end),
                    .fireAndForget { values.append(2) }
                )
            case .next2:
                return .fireAndForget { values.append(3) }
            case .end:
                return .fireAndForget { values.append(4) }
            }
        }

        let store = Store(initialState: (), reducer: counterReducer, environment: ())

        store.send(.tap)

        XCTAssertEqual(values, [1, 2, 3, 4])
    }

    internal func testLotsOfSynchronousActions() {
        enum Action { case incr, noop }
        let reducer = Reducer<Int, Action, Void> { state, action, _ in
            switch action {
            case .incr:
                state += 1
                return state >= 10000 ? Effect(value: .noop) : Effect(value: .incr)
            case .noop:
                return .none
            }
        }

        let store = Store(initialState: 0, reducer: reducer, environment: ())
        store.send(.incr)
        XCTAssertEqual(store.state, 10000)
    }

    internal func testPublisherScope() {
        let appReducer = Reducer<Int, Bool, Void> { state, action, _ in
            state += action ? 1 : 0
            return .none
        }

        let parentStore = Store(initialState: 0, reducer: appReducer, environment: ())

        var outputs: [Int] = []

        parentStore
            .scope(state: { $0.distinctUntilChanged() })
            .subscribe(onNext: { childStore in
                childStore.observable
                    .subscribe(onNext: { outputs.append($0) })
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)

        XCTAssertEqual(outputs, [0])

        parentStore.send(true)
        XCTAssertEqual(outputs, [0, 1])

        parentStore.send(false)
        XCTAssertEqual(outputs, [0, 1])
        parentStore.send(false)
        XCTAssertEqual(outputs, [0, 1])
        parentStore.send(false)
        XCTAssertEqual(outputs, [0, 1])
        parentStore.send(false)
        XCTAssertEqual(outputs, [0, 1])
    }

    internal func testIfLetAfterScope() {
        struct AppState {
            var count: Int?
        }

        let appReducer = Reducer<AppState, Int?, Void> { state, action, _ in
            state.count = action
            return .none
        }

        let parentStore = Store(initialState: AppState(), reducer: appReducer, environment: ())

        // NB: This test needs to hold a strong reference to the emitted stores
        var outputs: [Int?] = []
        var stores: [Any] = []

        parentStore
            .scope(state: { $0.count })
            .ifLet(
                then: { store in
                    stores.append(store)
                    outputs.append(store.state)
                },
                else: {
                    outputs.append(nil)
                }
            )
            .disposed(by: disposeBag)

        XCTAssertEqual(outputs, [nil])

        parentStore.send(1)
        XCTAssertEqual(outputs, [nil, 1])

        parentStore.send(nil)
        XCTAssertEqual(outputs, [nil, 1, nil])

        parentStore.send(1)
        XCTAssertEqual(outputs, [nil, 1, nil, 1])

        parentStore.send(nil)
        XCTAssertEqual(outputs, [nil, 1, nil, 1, nil])

        parentStore.send(1)
        XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1])

        parentStore.send(nil)
        XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1, nil])
    }

    internal func testIfLetTwo() {
        let parentStore = Store(
            initialState: 0,
            reducer: Reducer<Int?, Bool, Void> { state, action, _ in
                if action {
                    state? += 1
                    return .none
                } else {
                    return Observable.just(true)
                        .observeOn(MainScheduler.instance)
                        .eraseToEffect()
                }
            },
            environment: ()
        )

        parentStore.ifLet { childStore in
            childStore
                .observable
                .subscribe()
                .disposed(by: self.disposeBag)

            childStore.send(false)
            _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
            childStore.send(false)
            _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
            childStore.send(false)
            _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
            XCTAssertEqual(childStore.state, 3)
        }
        .disposed(by: disposeBag)
    }

    internal func testActionQueuing() {
        let subject = PublishSubject<Void>()

        enum Action: Equatable {
            case incrementTapped
            case initialize
            case doIncrement
        }

        let store = TestStore(
            initialState: 0,
            reducer: Reducer<Int, Action, Void> { state, action, _ in
                switch action {
                case .incrementTapped:
                    subject.onNext(())
                    return .none

                case .initialize:
                    return subject.map { .doIncrement }.eraseToEffect()

                case .doIncrement:
                    state += 1
                    return .none
                }
            },
            environment: ()
        )
        store.send(.initialize)
        store.send(.incrementTapped)
        store.receive(.doIncrement) {
            $0 = 1
        }
        store.send(.incrementTapped)
        store.receive(.doIncrement) {
            $0 = 2
        }
        subject.onCompleted()
    }
}
