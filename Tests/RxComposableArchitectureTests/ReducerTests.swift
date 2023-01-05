import Foundation
import RxComposableArchitecture
import RxSwift
//import TestSupport
import XCTest

internal final class ReducerTests: XCTestCase {
    internal func testCallableAsFunction() {
        let reducer = AnyReducer<Int, Void, Void> { state, _, _ in
            state += 1
            return .none
        }

        var state = 0
        _ = reducer.run(&state, (), ())
        XCTAssertEqual(state, 1)
    }

    internal func testCombine_EffectsAreMerged() {
        typealias Scheduler = TestScheduler
        enum Action: Equatable {
            case increment
        }

        var fastValue: Int?
        let fastReducer = AnyReducer<Int, Action, Scheduler> { state, _, scheduler in
            state += 1
            return Effect.fireAndForget { fastValue = 42 }
                .delay(.seconds(1), scheduler: scheduler)
                .eraseToEffect()
        }

        var slowValue: Int?
        let slowReducer = AnyReducer<Int, Action, Scheduler> { state, _, scheduler in
            state += 1
            return Effect.fireAndForget { slowValue = 1729 }
                .delay(.seconds(2), scheduler: scheduler)
                .eraseToEffect()
        }

        let scheduler = TestScheduler(initialClock: 0)
        let store = TestStore(
            initialState: 0,
            reducer: .combine(fastReducer, slowReducer),
            environment: scheduler,
            useNewScope: true
        )

        store.send(.increment) {
            $0 = 2
        }
        // Waiting a second causes the fast effect to fire.
        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(fastValue, 42)
        // Waiting one more second causes the slow effect to fire. This proves that the effects
        // are merged together, as opposed to concatenated.
        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(fastValue, 42)
        XCTAssertEqual(slowValue, 1729)
    }

    internal func testCombine() {
        enum Action: Equatable {
            case increment
        }

        var childEffectExecuted = false
        let childReducer = AnyReducer<Int, Action, Void> { state, _, _ in
            state += 1
            return Effect.fireAndForget { childEffectExecuted = true }
        }

        var mainEffectExecuted = false
        let mainReducer = AnyReducer<Int, Action, Void> { state, _, _ in
            state += 1
            return Effect.fireAndForget { mainEffectExecuted = true }
        }
        .combined(with: childReducer)

        let store = TestStore(
            initialState: 0,
            reducer: mainReducer,
            environment: (),
            useNewScope: true
        )

        store.send(.increment) {
            $0 = 2
        }

        XCTAssertTrue(childEffectExecuted)
        XCTAssertTrue(mainEffectExecuted)
    }

    internal func testDefaultSignpost() {
        let disposeBag = DisposeBag()

        let reducer = AnyReducer<Int, Void, Void>.empty.signpost(log: .default)
        var n = 0

        // swiftformat:disable:next redundantParens
        let effect = reducer.run(&n, (), ())
        let expectation = self.expectation(description: "effect")
        effect
            .subscribe(onCompleted: { expectation.fulfill() })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 0.1)
    }

    internal func testDisabledSignpost() {
        let disposeBag = DisposeBag()

        let reducer = AnyReducer<Int, Void, Void>.empty.signpost(log: .disabled)
        var n = 0

        // swiftformat:disable:next redundantParens
        let effect = reducer.run(&n, (), ())
        let expectation = self.expectation(description: "effect")
        effect
            .subscribe(onCompleted: { expectation.fulfill() })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 0.1)
    }
}
