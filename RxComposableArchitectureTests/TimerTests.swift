//
//  TimerTests.swift
//  RxComposableArchitecture_RxComposableArchitectureTests
//
//  Created by Jefferson Setiawan on 02/02/21.
//

import RxComposableArchitecture
import RxSwift
import TestSupport
import XCTest

internal final class TimerTests: XCTestCase {
    private var disposeBag = DisposeBag()

    internal func testTimer() {
        let scheduler = TestScheduler(initialClock: 0)

        var count = 0

        Effect<Int>.timer(id: 1, every: .seconds(1), on: scheduler)
            .subscribe(onNext: { _ in count += 1 })
            .disposed(by: disposeBag)

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(count, 1)

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(count, 2)

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(count, 3)

        scheduler.advance(by: .seconds(3))
        XCTAssertEqual(count, 6)
    }

    internal func testInterleavingTimer() {
        let scheduler = TestScheduler(initialClock: 0)

        var count2 = 0
        var count3 = 0

        Effect.merge(
            Effect<Int>.timer(id: 1, every: .seconds(2), on: scheduler)
                .do(onNext: { _ in count2 += 1 })
                .eraseToEffect(),
            Effect<Int>.timer(id: 2, every: .seconds(3), on: scheduler)
                .do(onNext: { _ in count3 += 1 })
                .eraseToEffect()
        )
        .subscribe(onNext: { _ in })
        .disposed(by: disposeBag)

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(count2, 0)
        XCTAssertEqual(count3, 0)
        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(count2, 1)
        XCTAssertEqual(count3, 0)
        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(count2, 1)
        XCTAssertEqual(count3, 1)
        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(count2, 2)
        XCTAssertEqual(count3, 1)
    }

    internal func testTimerCancellation() {
        let scheduler = TestScheduler(initialClock: 0)

        var count2 = 0
        var count3 = 0

        struct CancelToken: Hashable {}

        Effect.merge(
            Effect<Int>.timer(id: CancelToken(), every: .seconds(2), on: scheduler)
                .do(onNext: { _ in count2 += 1 })
                .eraseToEffect(),
            Effect<Int>.timer(id: CancelToken(), every: .seconds(3), on: scheduler)
                .do(onNext: { _ in count3 += 1 })
                .eraseToEffect(),
            Observable.just(())
                .delay(.seconds(31), scheduler: scheduler)
                .flatMap { Effect.cancel(id: CancelToken()) }
                .eraseToEffect()
        )
        .subscribe(onNext: { _ in })
        .disposed(by: disposeBag)

        scheduler.advance(by: .seconds(1))

        XCTAssertEqual(count2, 0)
        XCTAssertEqual(count3, 0)

        scheduler.advance(by: .seconds(1))

        XCTAssertEqual(count2, 1)
        XCTAssertEqual(count3, 0)

        scheduler.advance(by: .seconds(1))

        XCTAssertEqual(count2, 1)
        XCTAssertEqual(count3, 1)

        scheduler.advance(by: .seconds(1))

        XCTAssertEqual(count2, 2)
        XCTAssertEqual(count3, 1)

        scheduler.run()

        XCTAssertEqual(count2, 15)
        XCTAssertEqual(count3, 10)
    }

    internal func testTimerCompletion() {
        let scheduler = TestScheduler(initialClock: 0)

        var count = 0

        Effect<Int>.timer(id: 1, every: .seconds(1), on: scheduler)
            .take(3)
            .subscribe(onNext: { _ in count += 1 })
            .disposed(by: disposeBag)

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(count, 1)

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(count, 2)

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(count, 3)

        scheduler.run()
        XCTAssertEqual(count, 3)
    }
}
