import RxSwift
import XCTest

@testable import RxComposableArchitecture

final class EffectThrottleTests: XCTestCase {
    var disposeBag = DisposeBag()
    let scheduler = TestScheduler(initialClock: 0)
    
    func testThrottleLatest() {
        var values: [Int] = []
        var effectRuns = 0
        
        func runThrottledEffect(value: Int) {
            enum CancelToken {}
            
            Observable.deferred { () -> Observable<Int> in
                effectRuns += 1
                return .just(value)
            }
            .eraseToEffect()
            .throttle(
                id: CancelToken.self, for: .seconds(1), scheduler: scheduler, latest: true
            )
            .subscribe(onNext: {
                values.append($0)
            })
            .disposed(by: disposeBag)
        }
        
        runThrottledEffect(value: 1)

        scheduler.advance()
        
        // A value emits right away.
        XCTAssertEqual(values, [1])
        
        runThrottledEffect(value: 2)
        
        scheduler.advance()
        
        // A second value is throttled.
        XCTAssertEqual(values, [1])
        
        scheduler.advance(by: .milliseconds(250))
        
        runThrottledEffect(value: 3)
        
        scheduler.advance(by: .milliseconds(250))
        
        runThrottledEffect(value: 4)
        
        scheduler.advance(by: .milliseconds(250))
        
        runThrottledEffect(value: 5)
        
        // A third value is throttled.
        XCTAssertEqual(values, [1])
        
        scheduler.advance(by: .milliseconds(250))
        
        // The latest value emits.
        XCTAssertEqual(values, [1, 5])
    }
    
    func testThrottleFirst() {
        var values: [Int] = []
        var effectRuns = 0

        func runThrottledEffect(value: Int) {
            enum CancelToken {}

            Observable.deferred { () -> Observable<Int> in
                effectRuns += 1
                return .just(value)
            }
            .eraseToEffect()
            .throttle(
                id: CancelToken.self, for: .seconds(1), scheduler: scheduler, latest: false
            )
            .subscribe(onNext: {
                values.append($0)
            })
            .disposed(by: disposeBag)
        }

        runThrottledEffect(value: 1)

        scheduler.advance()

        // A value emits right away.
        XCTAssertEqual(values, [1])

        runThrottledEffect(value: 2)

        scheduler.advance()

        // A second value is throttled.
        XCTAssertEqual(values, [1])

        scheduler.advance(by: .milliseconds(250))

        runThrottledEffect(value: 3)

        scheduler.advance(by: .milliseconds(250))

        runThrottledEffect(value: 4)

        scheduler.advance(by: .milliseconds(250))

        runThrottledEffect(value: 5)

        scheduler.advance(by: .milliseconds(250))

        // The second (throttled) value emits.
        XCTAssertEqual(values, [1, 2])

        scheduler.advance(by: .milliseconds(250))

        runThrottledEffect(value: 6)

        scheduler.advance(by: .milliseconds(500))

        // A third value is throttled.
        XCTAssertEqual(values, [1, 2])

        runThrottledEffect(value: 7)

        scheduler.advance(by: .milliseconds(250))

        // The third (throttled) value emits.
        XCTAssertEqual(values, [1, 2, 6])
    }

    func testThrottleAfterInterval() {
        var values: [Int] = []
        var effectRuns = 0

        func runThrottledEffect(value: Int) {
            enum CancelToken {}

            Observable.deferred { () -> Observable<Int> in
                effectRuns += 1
                return .just(value)
            }
            .eraseToEffect()
            .throttle(
                id: CancelToken.self, for: .seconds(1), scheduler: scheduler, latest: true
            )
            .subscribe(onNext: {
                values.append($0)
            })
            .disposed(by: disposeBag)
        }

        runThrottledEffect(value: 1)

        scheduler.advance()

        // A value emits right away.
        XCTAssertEqual(values, [1])

        scheduler.advance(by: .seconds(2))

        runThrottledEffect(value: 2)

        scheduler.advance()

        // A second value is emitted right away.
        XCTAssertEqual(values, [1, 2])

        scheduler.advance(by: .seconds(2))

        runThrottledEffect(value: 3)

        scheduler.advance()

        // A third value is emitted right away.
        XCTAssertEqual(values, [1, 2, 3])
    }

    func testThrottleEmitsFirstValueOnce() {
        var values: [Int] = []
        var effectRuns = 0

        func runThrottledEffect(value: Int) {
            enum CancelToken {}

            Observable.deferred { () -> Observable<Int> in
                effectRuns += 1
                return .just(value)
            }
            .eraseToEffect()
            .throttle(
                id: CancelToken.self, for: .seconds(1), scheduler: scheduler, latest: false
            )
            .subscribe(onNext: {
                values.append($0)
            })
            .disposed(by: disposeBag)
        }

        runThrottledEffect(value: 1)

        scheduler.advance()

        // A value emits right away.
        XCTAssertEqual(values, [1])

        scheduler.advance(by: .milliseconds(500))

        runThrottledEffect(value: 2)

        scheduler.advance(by: .milliseconds(500))

        runThrottledEffect(value: 3)

        // A second value is emitted right away.
        XCTAssertEqual(values, [1, 2])
    }
}
