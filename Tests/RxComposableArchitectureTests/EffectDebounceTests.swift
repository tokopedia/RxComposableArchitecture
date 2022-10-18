import Foundation
import RxComposableArchitecture
import RxSwift
import XCTest

internal final class EffectDebounceTests: XCTestCase {
    private let disposeBag = DisposeBag()

    internal func testDebounce() {
        let scheduler = TestScheduler(initialClock: 0)
        var values: [Int] = []

        func runDebouncedEffect(value: Int) {
            struct CancelToken: Hashable {}
            Observable.just(value)
                .eraseToEffect()
                .debounce(id: CancelToken(), for: .seconds(1), scheduler: scheduler)
                .subscribe(onNext: { values.append($0) })
                .disposed(by: disposeBag)
        }

        runDebouncedEffect(value: 1)

        // Nothing emits right away.
        XCTAssertEqual(values, [])

        // Waiting half the time also emits nothing
        scheduler.advance(by: .milliseconds(500))
        XCTAssertEqual(values, [])

        // Run another debounced effect.
        runDebouncedEffect(value: 2)

        // Waiting half the time emits nothing because the first debounced effect has been canceled.
        scheduler.advance(by: .milliseconds(500))

        XCTAssertEqual(values, [])

        // Run another debounced effect.
        runDebouncedEffect(value: 3)

        // Waiting half the time emits nothing because the second debounced effect has been canceled.
        scheduler.advance(by: .milliseconds(500))
        XCTAssertEqual(values, [])

        // Waiting the rest of the time emits the final effect value.
        scheduler.advance(by: .milliseconds(500))
        XCTAssertEqual(values, [3])

        // Running out the scheduler
        scheduler.run()
        XCTAssertEqual(values, [3])
    }

    internal func testDebounceIsLazy() {
        let scheduler = TestScheduler(initialClock: 0)
        var values: [Int] = []
        var effectRuns = 0

        func runDebouncedEffect(value: Int) {
            struct CancelToken: Hashable {}

            Observable.deferred { () -> Observable<Int> in
                effectRuns += 1
                return .just(value)
            }
            .eraseToEffect()
            .debounce(id: CancelToken(), for: .seconds(1), scheduler: scheduler)
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)
        }

        runDebouncedEffect(value: 1)

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
