//
//  TestStoreOldScopeTests.swift
//  
//
//  Created by andhika.setiadi on 14/11/22.
//

import RxSwift
import XCTest

@testable import RxComposableArchitecture

/// All Test cases in here using `useNewScope: false` on both Store(...) and TestStore(...)
///
internal class TestStoreOldScopeTests: XCTestCase {
    private let disposeBag = DisposeBag()
    
    internal func testEffectConcatenation() {
        struct CancelID: Hashable {}
        struct State: Equatable {}
        
        enum Action: Equatable {
            case a, b1, b2, b3, c1, c2, c3, d
        }
        
        let mainQueue = TestScheduler(initialClock: 0)
        
        let reducer = Reduce<State, Action>({ _, action in
            switch action {
            case .a:
                return .merge(
                    Effect.concatenate(
                        .init(value: .b1),
                        .init(value: .c1)
                    )
                    .delay(.seconds(1), scheduler: mainQueue)
                    .eraseToEffect(),
                    
                    Observable<Action>.never()
                        .eraseToEffect()
                        .cancellable(id: CancelID())
                )
            case .b1:
                return Effect.concatenate(.init(value: .b2), .init(value: .b3))
            case .c1:
                return Effect
                    .concatenate(
                        .init(value: .c2),
                        .init(value: .c3)
                    )
            case .b2, .b3, .c2, .c3:
                return .none
                
            case .d:
                return .cancel(id: CancelID())
            }
        })
        
        let store = TestStore(
            initialState: State(),
            reducer: reducer
        )
        
        _ = store.send(Action.a)
        
        mainQueue.advance(by: .seconds(1))
        
        store.receive(Action.b1)
        store.receive(Action.b2)
        store.receive(Action.b3)
        
        store.receive(Action.c1)
        store.receive(Action.c2)
        store.receive(Action.c3)
        
        _ = store.send(Action.d)
    }
    
    #if DEBUG
        internal func testExpectedStateEquality() {
            struct State: Equatable {
                var count: Int = 0
                var isChanging: Bool = false
            }
            
            enum Action: Equatable {
                case increment
                case changed(from: Int, to: Int)
            }
            
            let reducer = Reduce<State, Action>({ state, action in
                switch action {
                case .increment:
                    state.isChanging = true
                    return Effect(value: .changed(from: state.count, to: state.count + 1))
                case .changed(let from, let to):
                    state.isChanging = false
                    if state.count == from {
                        state.count = to
                    }
                    return .none
                }
            })
            
            let store = TestStore(
                initialState: State(),
                reducer: reducer
            )
            
            store.send(.increment) {
                $0.isChanging = true
            }
            
            store.receive(.changed(from: 0, to: 1)) {
                $0.isChanging = false
                $0.count = 1
            }
            
            XCTExpectFailure {
                _ = store.send(.increment) {
                    $0.isChanging = false
                }
            }
            XCTExpectFailure {
                store.receive(.changed(from: 1, to: 2)) {
                    $0.isChanging = true
                    $0.count = 1100
                }
            }
        }
    
        internal func testExpectedStateEqualityMustModify() {
            struct State: Equatable {
                var count: Int = 0
            }
            
            enum Action: Equatable {
                case noop, finished
            }
            
            let reducer = Reduce<State, Action>({ state, action in
                switch action {
                case .noop:
                    return Effect(value: .finished)
                case .finished:
                    return .none
                }
            })
            
            let store = TestStore(
                initialState: State(),
                reducer: reducer
            )
            
            store.send(.noop)
            store.receive(.finished)
            
            XCTExpectFailure {
                _ = store.send(.noop) {
                    $0.count = 0
                }
            }
            
            XCTExpectFailure {
                store.receive(.finished) {
                    $0.count = 0
                }
            }
        }
    #endif
    
    internal func testStateAccess() {
        enum Action { case a, b, c, d }
        
        let store = TestStore(
            initialState: 0,
            reducer: Reduce<Int, Action>({ count, action in
                switch action {
                case .a:
                    count += 1
                    return .merge(.init(value: .b), .init(value: .c), .init(value: .d))
                case .b, .c, .d:
                    count += 1
                    return .none
                }
            })
        )
        
        store.send(.a) {
            $0 = 1
            XCTAssertEqual(store.state, 0)
        }
        XCTAssertEqual(store.state, 1)
        
        store.receive(.b) {
            $0 = 2
            XCTAssertEqual(store.state, 1)
        }
        XCTAssertEqual(store.state, 2)
        
        store.receive(.c) {
            $0 = 3
            XCTAssertEqual(store.state, 2)
        }
        XCTAssertEqual(store.state, 3)
        
        store.receive(.d) {
            $0 = 4
            XCTAssertEqual(store.state, 3)
        }
        
        XCTAssertEqual(store.state, 4)
    }
}

