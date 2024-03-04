//
//  StoreOldScopeTest.swift
//  
//
//  Created by andhika.setiadi on 14/11/22.
//

import RxSwift
import XCTest

@testable import RxComposableArchitecture

/// All Test cases in here using `useNewScope: false` and `old style reducer` on both Store(...) and TestStore(...)
///
internal final class StoreOldScopeTest: XCTestCase {
    private let disposeBag = DisposeBag()
    
    internal func testCancellableIsRemovedOnImmediatelyCompletingEffect() {
        let store = Store(
            initialState: (),
            reducer: AnyReducer<Void, Void, Void> { _, _, _ in .none },
            environment: (),
            useNewScope: false
        )
        
        XCTAssertEqual(store.effectDisposables.count, 0)
        
        _ = store.send(())
        
        XCTAssertEqual(store.effectDisposables.count, 0)
    }
    
    internal func testCancellableIsRemovedOnImmediatelyCompletingEffect_withUsingNewScope() {
        let store = Store(
            initialState: (),
            reducer: AnyReducer<Void, Void, Void> { _, _, _ in .none },
            environment: ()
        )
        
        XCTAssertEqual(store.effectDisposables.count, 0)
        
        _ = store.send(())
        
        XCTAssertEqual(store.effectDisposables.count, 0)
    }
    
    internal func testCancellableIsRemovedWhenEffectCompletes() {
        let scheduler = TestScheduler(initialClock: 0)
        let effect = Effect<Void>(value: ())
            .delay(.seconds(1), scheduler: scheduler)
            .eraseToEffect()
        
        enum Action { case start, end }
        
        let reducer = AnyReducer<Void, Action, Void>{ _, action, _ in
            switch action {
            case .start:
                return effect.map { .end }
            case .end:
                return .none
            }
        }
        
        let store = Store(
            initialState: (),
            reducer: reducer,
            environment: (),
            useNewScope: false
        )
        
        XCTAssertEqual(store.effectDisposables.count, 0)
        
        _ = store.send(.start)
        
        XCTAssertEqual(store.effectDisposables.count, 1)
        
        scheduler.advance(by: .seconds(2))
        
        XCTAssertEqual(store.effectDisposables.count, 0)
    }
    
    internal func testCancellableIsRemovedWhenEffectCompletes_withUsingNewScope() {
        let scheduler = TestScheduler(initialClock: 0)
        let effect = Effect<Void>(value: ())
            .delay(.seconds(1), scheduler: scheduler)
            .eraseToEffect()
        
        enum Action { case start, end }
        
        let reducer = AnyReducer<Void, Action, Void>{ _, action, _ in
            switch action {
            case .start:
                return effect.map { .end }
            case .end:
                return .none
            }
        }
        
        let store = Store(
            initialState: (),
            reducer: reducer,
            environment: ()
        )
        
        XCTAssertEqual(store.effectDisposables.count, 0)
        
        _ = store.send(.start)
        
        XCTAssertEqual(store.effectDisposables.count, 1)
        
        scheduler.advance(by: .seconds(2))
        
        XCTAssertEqual(store.effectDisposables.count, 0)
    }
    
    internal func testScopedStoreReceivesUpdatesFromParent() {
        let counterReducer = AnyReducer<Int, Void, Void>({ state, _, _ in
            state += 1
            return .none
        })
        
        let parentStore = Store(
            initialState: 0,
            reducer: counterReducer,
            environment: (),
            useNewScope: false
        )
        let childStore = parentStore.scope(state: String.init)
        
        var values: [String] = []
        childStore.subscribe { $0 }
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)
        
        XCTAssertEqual(values, ["0"])
        
        _ = parentStore.send(())
        
        XCTAssertEqual(values, ["0", "1"])
    }
    
    internal func testScopedStoreReceivesUpdatesFromParent_withUsingNewScope() {
        let counterReducer = AnyReducer<Int, Void, Void>({ state, _, _ in
            state += 1
            return .none
        })
        
        let parentStore = Store(
            initialState: 0,
            reducer: counterReducer,
            environment: ()
        )
        let childStore = parentStore.scope(state: String.init)
        
        var values: [String] = []
        childStore.subscribe { $0 }
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)
        
        XCTAssertEqual(values, ["0"])
        
        _ = parentStore.send(())
        
        XCTAssertEqual(values, ["0", "1"])
    }
    
    internal func testParentStoreReceivesUpdatesFromChild() {
        let counterReducer = AnyReducer<Int, Void, Void>({ state, _, _ in
            state += 1
            return .none
        })
        
        let parentStore = Store(
            initialState: 0,
            reducer: counterReducer,
            environment: (),
            useNewScope: false
        )
        let childStore = parentStore.scope(state: String.init)
        
        var values: [Int] = []
        
        parentStore.subscribe { $0 }
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)
        
        XCTAssertEqual(values, [0])
        
        _ = childStore.send(())
        
        XCTAssertEqual(values, [0, 1])
    }
    
    internal func testParentStoreReceivesUpdatesFromChild_withUsingNewScope() {
        let counterReducer = AnyReducer<Int, Void, Void>({ state, _, _ in
            state += 1
            return .none
        })
        
        let parentStore = Store(
            initialState: 0,
            reducer: counterReducer,
            environment: ()
        )
        let childStore = parentStore.scope(state: String.init)
        
        var values: [Int] = []
        
        parentStore.subscribe { $0 }
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)
        
        XCTAssertEqual(values, [0])
        
        _ = childStore.send(())
        
        XCTAssertEqual(values, [0, 1])
    }
    
    internal func testScopeCallCount() {
        let counterReducer = AnyReducer<Int, Void, Void>({ state, action, _ in
            state += 1
            return .none
        })
        
        var numCalls1 = 0
        _ = Store(
            initialState: 0,
            reducer: counterReducer,
            environment: (),
            useNewScope: false
        )
        .scope(state: { (count: Int) -> Int in
            numCalls1 += 1
            return count
        })
        
        XCTAssertEqual(numCalls1, 2)
    }
    
    internal func testScopeCallCount_withUsingNewScope() {
        let counterReducer = AnyReducer<Int, Void, Void>({ state, action, _ in
            state += 1
            return .none
        })
        
        var numCalls1 = 0
        _ = Store(
            initialState: 0,
            reducer: counterReducer,
            environment: ()
        )
        .scope(state: { (count: Int) -> Int in
            numCalls1 += 1
            return count
        })
        
        XCTAssertEqual(numCalls1, 1)
    }
    
    internal func testScopeCallCount2() {
        let counterReducer = AnyReducer<Int, Void, Void>({ state, _, _ in
            state += 1
            return .none
        })
        
        var numCalls1 = 0
        var numCalls2 = 0
        var numCalls3 = 0
        
        let store = Store(
            initialState: 0,
            reducer: counterReducer,
            environment: (),
            useNewScope: false
        )
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
        
        _ = store.send(())
        
        XCTAssertEqual(numCalls1, 4)
        XCTAssertEqual(numCalls2, 5)
        XCTAssertEqual(numCalls3, 6)
        
        _ = store.send(())
        
        XCTAssertEqual(numCalls1, 6)
        XCTAssertEqual(numCalls2, 8)
        XCTAssertEqual(numCalls3, 10)
        
        _ = store.send(())
        
        XCTAssertEqual(numCalls1, 8)
        XCTAssertEqual(numCalls2, 11)
        XCTAssertEqual(numCalls3, 14)
    }
    
    internal func testScopeCallCount2_withUsingNewScope() {
        let counterReducer = AnyReducer<Int, Void, Void>({ state, _, _ in
            state += 1
            return .none
        })
        
        var numCalls1 = 0
        var numCalls2 = 0
        var numCalls3 = 0
        
        let store = Store(
            initialState: 0,
            reducer: counterReducer,
            environment: ()
        )
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
        
        XCTAssertEqual(numCalls1, 1)
        XCTAssertEqual(numCalls2, 1)
        XCTAssertEqual(numCalls3, 1)
        
        _ = store.send(())
        
        XCTAssertEqual(numCalls1, 2)
        XCTAssertEqual(numCalls2, 2)
        XCTAssertEqual(numCalls3, 2)
        
        _ = store.send(())
        
        XCTAssertEqual(numCalls1, 3)
        XCTAssertEqual(numCalls2, 3)
        XCTAssertEqual(numCalls3, 3)
        
        _ = store.send(())
        
        XCTAssertEqual(numCalls1, 4)
        XCTAssertEqual(numCalls2, 4)
        XCTAssertEqual(numCalls3, 4)
    }
    
    internal func testScopeAtIndexCallCount2() {
        struct Item: Identifiable, Equatable {
            var id: Int
            var qty: Int
        }
        enum ItemAction {
            case didTap
        }
        enum Action {
            case item(id: Int, action: ItemAction)
        }
        let itemReducer = AnyReducer<IdentifiedArrayOf<Item>, Action, Void>({ state, action, _ in
            switch action {
            case let .item(id, .didTap):
                state[id: id]!.qty += 1
            }
            return .none
        })
        
        var numCalls1 = 0
        var numCalls2 = 0
        
        let mock = (1...3).map {
            Item(id: $0, qty: 1)
        }
        
        let store = Store(
            initialState: IdentifiedArrayOf(mock),
            reducer: itemReducer,
            environment: (),
            useNewScope: false
        )
        .scope(state: { (item: IdentifiedArrayOf<Item>) -> IdentifiedArrayOf<Item> in
            numCalls1 += 1
            return item
        })
        .scope(at: 1, action: Action.item)!
        .scope(state: { (item: Item) -> Item in
            numCalls2 += 1
            return item
        })
        
        _ = store.send((1, .didTap))
        XCTAssertEqual(numCalls1, 4)
        XCTAssertEqual(numCalls2, 5)
        XCTAssertEqual(store.state.qty, 2)
        
        _ = store.send((1, .didTap))
        XCTAssertEqual(numCalls1, 6)
        XCTAssertEqual(numCalls2, 8)
        XCTAssertEqual(store.state.qty, 3)
    }
    
    internal func testScopeAtIndexCallCount2_withUsingNewScope() {
        struct Item: Identifiable, Equatable {
            var id: Int
            var qty: Int
        }
        enum ItemAction {
            case didTap
        }
        enum Action {
            case item(id: Int, action: ItemAction)
        }
        let itemReducer = AnyReducer<IdentifiedArrayOf<Item>, Action, Void>({ state, action, _ in
            switch action {
            case let .item(id, .didTap):
                state[id: id]!.qty += 1
            }
            return .none
        })
        
        var numCalls1 = 0
        var numCalls2 = 0
        
        let mock = (1...3).map {
            Item(id: $0, qty: 1)
        }
        
        let store = Store(
            initialState: IdentifiedArrayOf(mock),
            reducer: itemReducer,
            environment: ()
        )
        .scope(state: { (item: IdentifiedArrayOf<Item>) -> IdentifiedArrayOf<Item> in
            numCalls1 += 1
            return item
        })
        .scope(at: 1, action: Action.item)!
        .scope(state: { (item: Item) -> Item in
            numCalls2 += 1
            return item
        })
        
        _ = store.send((1, .didTap))
        XCTAssertEqual(numCalls1, 2)
        XCTAssertEqual(numCalls2, 2)
        XCTAssertEqual(store.state.qty, 2)
        
        _ = store.send((1, .didTap))
        XCTAssertEqual(numCalls1, 3)
        XCTAssertEqual(numCalls2, 3)
        XCTAssertEqual(store.state.qty, 3)
    }
    
    internal func testSynchronousEffectsSentAfterSinking() {
        enum Action {
            case tap
            case next1
            case next2
            case end
        }
        var values: [Int] = []
        let counterReducer = AnyReducer<Void, Action, Void>({ state, action, _ in
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
        })
        
        let store = Store(
            initialState: (),
            reducer: counterReducer,
            environment: (),
            useNewScope: false
        )
        
        _ = store.send(.tap)
        
        XCTAssertEqual(values, [1, 2, 3, 4])
    }
    
    internal func testSynchronousEffectsSentAfterSinking_usingNewSend() {
        enum Action {
            case tap
            case next1
            case next2
            case end
        }
        var values: [Int] = []
        let counterReducer = AnyReducer<Void, Action, Void>({ state, action, _ in
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
        })
        
        let store = Store(
            initialState: (),
            reducer: counterReducer,
            environment: ()
        )
        
        _ = store.send(.tap)
        
        XCTAssertEqual(values, [1, 2, 3, 4])
    }
    
    internal func testLotsOfSynchronousActions() {
        enum Action { case incr, noop }
        let reducer = AnyReducer<Int, Action, Void>({ state, action, _ in
            switch action {
            case .incr:
                state += 1
                return state >= 10000 ? Effect(value: .noop) : Effect(value: .incr)
            case .noop:
                return .none
            }
        })
        
        let store = Store(
            initialState: 0,
            reducer: reducer,
            environment: (),
            useNewScope: false
        )
        _ = store.send(.incr)
        XCTAssertEqual(store.state, 10000)
    }
    
    internal func testLotsOfSynchronousActions_usingNewScope() {
        enum Action { case incr, noop }
        let reducer = AnyReducer<Int, Action, Void>({ state, action, _ in
            switch action {
            case .incr:
                state += 1
                return state >= 10000 ? Effect(value: .noop) : Effect(value: .incr)
            case .noop:
                return .none
            }
        })
        
        let store = Store(
            initialState: 0,
            reducer: reducer,
            environment: ()
        )
        _ = store.send(.incr)
        XCTAssertEqual(store.state, 10000)
    }
    
    internal func testIfLetAfterScope() {
        struct AppState {
            var count: Int?
        }
        
        let appReducer = AnyReducer<AppState, Int?, Void>({ state, action, _ in
            state.count = action
            return .none
        })
        
        let parentStore = Store(
            initialState: AppState(),
            reducer: appReducer,
            environment: (),
            useNewScope: false
        )
        
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
        
        _ = parentStore.send(1)
        XCTAssertEqual(outputs, [nil, 1])
        
        _ = parentStore.send(nil)
        XCTAssertEqual(outputs, [nil, 1, nil])
        
        _ = parentStore.send(1)
        XCTAssertEqual(outputs, [nil, 1, nil, 1])
        
        _ = parentStore.send(nil)
        XCTAssertEqual(outputs, [nil, 1, nil, 1, nil])
        
        _ = parentStore.send(1)
        XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1])
        
        _ = parentStore.send(nil)
        XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1, nil])
    }
    
    internal func testIfLetAfterScope_withUsingNewScope() {
        struct AppState {
            var count: Int?
        }
        
        let appReducer = AnyReducer<AppState, Int?, Void>({ state, action, _ in
            state.count = action
            return .none
        })
        
        let parentStore = Store(
            initialState: AppState(),
            reducer: appReducer,
            environment: ()
        )
        
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
        
        _ = parentStore.send(1)
        XCTAssertEqual(outputs, [nil, 1])
        
        _ = parentStore.send(nil)
        XCTAssertEqual(outputs, [nil, 1, nil])
        
        _ = parentStore.send(1)
        XCTAssertEqual(outputs, [nil, 1, nil, 1])
        
        _ = parentStore.send(nil)
        XCTAssertEqual(outputs, [nil, 1, nil, 1, nil])
        
        _ = parentStore.send(1)
        XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1])
        
        _ = parentStore.send(nil)
        XCTAssertEqual(outputs, [nil, 1, nil, 1, nil, 1, nil])
    }
    
    internal func testIfLetTwo() {
        let parentStore = Store(
            initialState: 0,
            reducer: AnyReducer<Int?, Bool, Void>({ state, action, _ in
                if action {
                    state? += 1
                    return .none
                } else {
                    return Observable.just(true)
                        .observeOn(MainScheduler.instance)
                        .eraseToEffect()
                }
            }),
            environment: (),
            useNewScope: false
        )
        
        parentStore.ifLet { childStore in
            childStore
                .observable
                .subscribe()
                .disposed(by: self.disposeBag)
            
            _ = childStore.send(false)
            _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
            _ = childStore.send(false)
            _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
            _ = childStore.send(false)
            _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
            XCTAssertEqual(childStore.state, 3)
        }
        .disposed(by: disposeBag)
    }
    
    internal func testIfLetTwo_withUsingNewScope() {
        let parentStore = Store(
            initialState: 0,
            reducer: AnyReducer<Int?, Bool, Void>({ state, action, _ in
                if action {
                    state? += 1
                    return .none
                } else {
                    return Observable.just(true)
                        .observeOn(MainScheduler.instance)
                        .eraseToEffect()
                }
            }),
            environment: ()
        )
        
        parentStore.ifLet { childStore in
            childStore
                .observable
                .subscribe()
                .disposed(by: self.disposeBag)
            
            _ = childStore.send(false)
            _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
            _ = childStore.send(false)
            _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
            _ = childStore.send(false)
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
            reducer: AnyReducer<Int, Action, Void>({ state, action, _ in
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
            }),
            environment: (),
            useNewScope: false
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
    
    internal func testActionQueuing_withUsingNewScope() {
        let subject = PublishSubject<Void>()
        
        enum Action: Equatable {
            case incrementTapped
            case initialize
            case doIncrement
        }
        
        let store = TestStore(
            initialState: 0,
            reducer: AnyReducer<Int, Action, Void>({ state, action, _ in
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
            }),
            environment: (),
            useNewScope: true
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
    
    internal func testCoalesceSynchronousActions() {
        let store = Store(
            initialState: 0,
            reducer: AnyReducer<Int, Int, Void>({ state, action, _ in
                switch action {
                case 0:
                    return .merge(
                        Effect(value: 1),
                        Effect(value: 2),
                        Effect(value: 3)
                    )
                default:
                    state = action
                    return .none
                }
            }),
            environment: (),
            useNewScope: false
        )
        
        var emissions: [Int] = []
        store.subscribe { $0 }
            .subscribe { emissions.append($0) }
            .disposed(by: disposeBag)
        
        XCTAssertEqual(emissions, [0])
        
        _ = store.send(0)
        
        XCTAssertEqual(emissions, [0, 1, 2, 3])
    }
    
    internal func testCoalesceSynchronousActions_withUsingNewScope() {
        let store = Store(
            initialState: 0,
            reducer: AnyReducer<Int, Int, Void>({ state, action, _ in
                switch action {
                case 0:
                    return .merge(
                        Effect(value: 1),
                        Effect(value: 2),
                        Effect(value: 3)
                    )
                default:
                    state = action
                    return .none
                }
            }),
            environment: ()
        )
        
        var emissions: [Int] = []
        store.subscribe { $0 }
            .subscribe { emissions.append($0) }
            .disposed(by: disposeBag)
        
        XCTAssertEqual(emissions, [0])
        
        _ = store.send(0)
        
        XCTAssertEqual(emissions, [0, 3])
    }
    
    internal func testSyncEffectsFromEnvironment() {
        enum Action: Equatable {
            // subscribes to a long living effect, potentially feeding data
            // back into the store
            case onAppear
            
            // Talks to the environment, eventually feeding data back into the store
            case onUserAction
            
            // External event coming in from the environment, updating state
            case externalAction
        }
        
        struct Environment {
            var externalEffects = PublishSubject<Action>()
        }
        
        let counterReducer = AnyReducer<Int, Action, Environment> { state, action, env in
            switch action {
            case .onAppear:
                return env.externalEffects.eraseToEffect()
            case .onUserAction:
                return .fireAndForget {
                    // This would actually do something async in the environment
                    // that feeds back eventually via the `externalEffectPublisher`
                    // Here we send an action sync, which could e.g. happen for an error case, ..
                    env.externalEffects.onNext(.externalAction)
                }
            case .externalAction:
                state += 1
            }
            return .none
        }
        let parentStore = Store(
            initialState: 1,
            reducer: counterReducer,
            environment: Environment(),
            useNewScope: false
        )
        
        // subscribes to a long living publisher of actions
        _ = parentStore.send(.onAppear)
        
        _ = parentStore.send(.onUserAction)
        
        // State should be at 2 now
        XCTAssertEqual(parentStore.state, 2)
    }
    
    internal func testSyncEffectsFromEnvironment_withUsingNewScope() {
        enum Action: Equatable {
            // subscribes to a long living effect, potentially feeding data
            // back into the store
            case onAppear
            
            // Talks to the environment, eventually feeding data back into the store
            case onUserAction
            
            // External event coming in from the environment, updating state
            case externalAction
        }
        
        struct Environment {
            var externalEffects = PublishSubject<Action>()
        }
        
        let counterReducer = AnyReducer<Int, Action, Environment> { state, action, env in
            switch action {
            case .onAppear:
                return env.externalEffects.eraseToEffect()
            case .onUserAction:
                return .fireAndForget {
                    // This would actually do something async in the environment
                    // that feeds back eventually via the `externalEffectPublisher`
                    // Here we send an action sync, which could e.g. happen for an error case, ..
                    env.externalEffects.onNext(.externalAction)
                }
            case .externalAction:
                state += 1
            }
            return .none
        }
        let parentStore = Store(
            initialState: 1,
            reducer: counterReducer,
            environment: Environment()
        )
        
        // subscribes to a long living publisher of actions
        _ = parentStore.send(.onAppear)
        
        _ = parentStore.send(.onUserAction)
        
        // State should be at 2 now
        XCTAssertEqual(parentStore.state, 2)
    }
    
    internal func testBufferedActionProcessing() {
        struct ChildState: Equatable {
          var count: Int?
        }

        struct ParentState: Equatable {
          var count: Int?
          var child: ChildState?
        }

        enum ParentAction: Equatable {
          case button
          case child(Int?)
        }

        var handledActions: [ParentAction] = []
        let parentReducer = AnyReducer.combine(
            AnyReducer<ChildState, Int, Void>{ state, action, _ in
                state.count = action
                return .none
            }
            .optional()
            .pullback(
                state: \ParentState.child,
                action: /ParentAction.child,
                environment: {}
            ),
            AnyReducer<ParentState, ParentAction, Void>({ state, action, _ in
              handledActions.append(action)

              switch action {
              case .button:
                state.child = .init(count: nil)
                return .none

              case .child(let childCount):
                state.count = childCount
                return .none
              }
            })
        )

        let parentStore = Store<ParentState, ParentAction>(
          initialState: ParentState(),
          reducer: parentReducer,
          environment: (),
          useNewScope: false
        )

        parentStore
          .scope(
            state: \ParentState.child,
            action: ParentAction.child
          )
          .ifLet { childStore in
              childStore.send(2)
          }
          .disposed(by: disposeBag)

        XCTAssertEqual(handledActions, [])

        _ = parentStore.send(ParentAction.button)
        
        XCTAssertEqual(
          handledActions,
          [
            .button,
            .child(2),
          ])
      }
    
    internal func testBufferedActionProcessing_withUsingNewScope() {
        struct ChildState: Equatable {
          var count: Int?
        }

        struct ParentState: Equatable {
          var count: Int?
          var child: ChildState?
        }

        enum ParentAction: Equatable {
          case button
          case child(Int?)
        }

        var handledActions: [ParentAction] = []
        let parentReducer = AnyReducer.combine(
            AnyReducer<ChildState, Int, Void>{ state, action, _ in
                state.count = action
                return .none
            }
            .optional()
            .pullback(
                state: \ParentState.child,
                action: /ParentAction.child,
                environment: {}
            ),
            AnyReducer<ParentState, ParentAction, Void>({ state, action, _ in
              handledActions.append(action)

              switch action {
              case .button:
                state.child = .init(count: nil)
                return .none

              case .child(let childCount):
                state.count = childCount
                return .none
              }
            })
        )

        let parentStore = Store<ParentState, ParentAction>(
          initialState: ParentState(),
          reducer: parentReducer,
          environment: ()
        )

        parentStore
          .scope(
            state: \ParentState.child,
            action: ParentAction.child
          )
          .ifLet { childStore in
              childStore.send(2)
          }
          .disposed(by: disposeBag)

        XCTAssertEqual(handledActions, [])

        _ = parentStore.send(ParentAction.button)
        
        XCTAssertEqual(
          handledActions,
          [
            .button,
            .child(2),
          ])
      }
}
