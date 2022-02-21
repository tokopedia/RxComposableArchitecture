import RxSwift
import TestSupport
import XCTest

@testable import RxComposableArchitecture

internal final class EffectCancellationTests: XCTestCase {
    private var disposeBag = DisposeBag()

    override internal func tearDown() {
        super.tearDown()
        disposeBag = DisposeBag()
    }

    internal func testCancellation() {
        struct CancelToken: Hashable {}
        var values: [Int] = []

        let subject = PublishSubject<Int>()
        let effect = Effect(subject)
            .cancellable(id: CancelToken())

        effect.subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        XCTAssertEqual(values, [])
        subject.onNext(1)
        XCTAssertEqual(values, [1])
        subject.onNext(2)
        XCTAssertEqual(values, [1, 2])

        Effect<Never>.cancel(id: CancelToken())
            .subscribe()
            .disposed(by: disposeBag)

        subject.onNext(3)
        XCTAssertEqual(values, [1, 2])
    }

    internal func testCancelInFlight() {
        struct CancelToken: Hashable {}
        var values: [Int] = []

        let subject = PublishSubject<Int>()
        Effect(subject)
            .cancellable(id: CancelToken(), cancelInFlight: true)
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        XCTAssertEqual(values, [])
        subject.onNext(1)
        XCTAssertEqual(values, [1])
        subject.onNext(2)
        XCTAssertEqual(values, [1, 2])

        Effect(subject)
            .cancellable(id: CancelToken(), cancelInFlight: true)
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        subject.onNext(3)
        XCTAssertEqual(values, [1, 2, 3])
        subject.onNext(4)
        XCTAssertEqual(values, [1, 2, 3, 4])
    }

    internal func testCancellationAfterDelay() {
        struct CancelToken: Hashable {}
        var value: Int?

        Observable.just(1)
            .delay(.milliseconds(500), scheduler: MainScheduler.instance)
            .eraseToEffect()
            .cancellable(id: CancelToken())
            .subscribe(onNext: { value = $0 })
            .disposed(by: disposeBag)

        XCTAssertEqual(value, nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            _ = Effect<Never>.cancel(id: CancelToken())
                .subscribe()
                .disposed(by: self.disposeBag)
        }

        _ = XCTWaiter.wait(for: [expectation(description: "")], timeout: 0.1)

        XCTAssertEqual(value, nil)
    }

    internal func testCancellationAfterDelay_WithTestScheduler() {
        struct CancelToken: Hashable {}

        let scheduler = TestScheduler(initialClock: 0)

        var value: Int?

        Observable.just(1)
            .delay(.seconds(2), scheduler: scheduler)
            .eraseToEffect()
            .cancellable(id: CancelToken())
            .subscribe(onNext: { value = $0 })
            .disposed(by: disposeBag)

        XCTAssertEqual(value, nil)

        scheduler.advance(by: .seconds(1))

        Effect<Never>.cancel(id: CancelToken())
            .subscribe()
            .disposed(by: disposeBag)

        scheduler.advance(to: 1000)

        XCTAssertEqual(value, nil)
    }

    internal func testCancellablesCleanUp_OnComplete() {
        Observable.just(1)
            .eraseToEffect()
            .cancellable(id: 1)
            .subscribe()
            .disposed(by: disposeBag)

        XCTAssertTrue(cancellationCancellables.isEmpty)
    }

    internal func testCancellablesCleanUp_OnCancel() {
        let scheduler = TestScheduler(initialClock: 0)

        Observable.just(1)
            .delay(.seconds(1), scheduler: scheduler)
            .eraseToEffect()
            .cancellable(id: 1)
            .subscribe()
            .disposed(by: disposeBag)

        Effect<Never>.cancel(id: 1)
            .subscribe()
            .disposed(by: disposeBag)

        XCTAssertTrue(cancellationCancellables.isEmpty)
    }

    internal func testDoubleCancellation() {
        struct CancelToken: Hashable {}
        var values: [Int] = []

        let subject = PublishSubject<Int>()
        let effect = Effect(subject)
            .cancellable(id: CancelToken())
            .cancellable(id: CancelToken())

        effect
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        XCTAssertEqual(values, [])
        subject.onNext(1)
        XCTAssertEqual(values, [1])

        _ = Effect<Never>.cancel(id: CancelToken())
            .subscribe()
            .disposed(by: disposeBag)

        subject.onNext(2)
        XCTAssertEqual(values, [1])
    }

    internal func testCompleteBeforeCancellation() {
        struct CancelToken: Hashable {}
        var values: [Int] = []

        let subject = PublishSubject<Int>()
        let effect = Effect(subject)
            .cancellable(id: CancelToken())

        effect
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        subject.onNext(1)
        XCTAssertEqual(values, [1])

        subject.onCompleted()
        XCTAssertEqual(values, [1])

        Effect<Never>.cancel(id: CancelToken())
            .subscribe()
            .disposed(by: disposeBag)

        XCTAssertEqual(values, [1])
    }

    internal func testNestedCancels() {
        var effect = Observable<Void>.never()
            .eraseToEffect()
            .cancellable(id: 1)

        for _ in 1 ... .random(in: 1 ... 1000) {
            effect = effect.cancellable(id: 1)
        }

        effect
            .subscribe(onNext: { _ in })
            .disposed(by: disposeBag)

        disposeBag = DisposeBag()

        XCTAssertTrue(cancellationCancellables.isEmpty)
    }

    internal func testSharedId() {
        let scheduler = TestScheduler(initialClock: 0)

        let effect1 = Observable.just(1)
            .delay(.seconds(1), scheduler: scheduler)
            .eraseToEffect()
            .cancellable(id: "id")

        let effect2 = Observable.just(2)
            .delay(.seconds(2), scheduler: scheduler)
            .eraseToEffect()
            .cancellable(id: "id")

        var expectedOutput: [Int] = []
        effect1
            .subscribe(onNext: { expectedOutput.append($0) })
            .disposed(by: disposeBag)
        effect2
            .subscribe(onNext: { expectedOutput.append($0) })
            .disposed(by: disposeBag)

        XCTAssertEqual(expectedOutput, [])
        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(expectedOutput, [1])
        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(expectedOutput, [1, 2])
    }

    internal func testImmediateCancellation() {
        let scheduler = TestScheduler(initialClock: 0)

        var expectedOutput: [Int] = []
        // Don't hold onto cancellable so that it is deallocated immediately.
        let d = Observable.deferred { .just(1) }
            .delay(.seconds(1), scheduler: scheduler)
            .eraseToEffect()
            .cancellable(id: "id")
            .subscribe(onNext: { expectedOutput.append($0) })
        d.dispose()

        XCTAssertEqual(expectedOutput, [])
        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(expectedOutput, [])
    }
}
