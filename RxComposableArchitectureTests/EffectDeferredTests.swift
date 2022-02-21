//
//  EffectDeferredTests.swift
//  RxComposableArchitectureTests
//
//  Created by Wendy Liga on 18/06/21.
//

import Foundation
import RxSwift
import TestSupport
import XCTest

internal final class EffectDeferredTests: XCTestCase {
    private let disposeBag = DisposeBag()

    internal func testDeferred() {
        let scheduler = TestScheduler(initialClock: 0)
        var values: [Int] = []

        func runDeferredEffect(value: Int) {
            Observable.just(value)
                .eraseToEffect()
                .deferred(for: .seconds(1), scheduler: scheduler)
                .subscribe(onNext: { values.append($0) })
                .disposed(by: disposeBag)
        }

        runDeferredEffect(value: 1)

        // Nothing emits right away.
        XCTAssertEqual(values, [])

        // Waiting half the time also emits nothing
        scheduler.advance(by: .milliseconds(500))
        XCTAssertEqual(values, [])

        // Run another deferred effect.
        runDeferredEffect(value: 2)

        // Waiting half the time emits first deferred effect received.
        scheduler.advance(by: .milliseconds(500))
        XCTAssertEqual(values, [1])

        // Run another deferred effect.
        runDeferredEffect(value: 3)

        // Waiting half the time emits second deferred effect received.
        scheduler.advance(by: .milliseconds(500))
        XCTAssertEqual(values, [1, 2])

        // Waiting the rest of the time emits the final effect value.
        scheduler.advance(by: .milliseconds(500))
        XCTAssertEqual(values, [1, 2, 3])

        // Running out the scheduler
        scheduler.run()
        XCTAssertEqual(values, [1, 2, 3])
    }

    internal func testDeferredIsLazy() {
        let scheduler = TestScheduler(initialClock: 0)
        var values: [Int] = []
        var effectRuns = 0

        func runDeferredEffect(value: Int) {
            Observable.deferred { () -> Observable<Int> in
                effectRuns += 1
                return .just(value)
            }
            .eraseToEffect()
            .deferred(for: .seconds(1), scheduler: scheduler)
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)
        }

        runDeferredEffect(value: 1)

        XCTAssertEqual(values, [])
        XCTAssertEqual(effectRuns, 0)

        scheduler.advance(by: .milliseconds(500))

        XCTAssertEqual(values, [])
        XCTAssertEqual(effectRuns, 0)

        scheduler.advance(by: .milliseconds(500))

        XCTAssertEqual(values, [1])
        XCTAssertEqual(effectRuns, 1)
    }
}
