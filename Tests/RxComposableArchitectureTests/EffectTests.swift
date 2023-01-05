//
//  EffectTests.swift
//  RxComposableArchitecture_RxComposableArchitectureTests
//
//  Created by Jefferson Setiawan on 02/02/21.
//

import RxSwift
import XCTest

@_spi(Canary) import RxComposableArchitecture

@MainActor
internal final class EffectTests: XCTestCase {
    private var disposeBag = DisposeBag()
    private let scheduler = TestScheduler(initialClock: 0)
    
    func testCatchToEffect() {
      struct MyError: Swift.Error, Equatable {}

        Observable<Int>.just(42)
            .catchToEffect()
            .subscribe(onNext: {
                guard case let .success(intValue) = $0 else {
                    XCTFail("Value is not Success one")
                    return
                }
                XCTAssertEqual(intValue, 42)
            })
            .disposed(by: disposeBag)

        Observable<Int>.error(MyError())
            .eraseToEffect()
            .subscribe(onError: {
                guard let err = $0 as? MyError else {
                    XCTFail("Error is not MyError")
                    return
                }
                XCTAssertEqual(err, MyError())
            })
            .disposed(by: disposeBag)
        Observable<Int>.just(42)
            .eraseToEffect()
            .subscribe(onNext: { XCTAssertEqual($0, 42) })
            .disposed(by: disposeBag)

        Observable<Int>.just(42)
            .catchToEffect{
                switch $0 {
                case let .success(val):
                  return val
                case .failure:
                  return -1
                }
            }
            .subscribe(onNext: { XCTAssertEqual($0, 42) })
            .disposed(by: disposeBag)
        
        Observable<Int>.error(MyError())
            .catchToEffect{
                switch $0 {
                case let .success(val):
                  return val
                case .failure:
                  return -1
                }
            }
            .subscribe(onNext: { XCTAssertEqual($0, -1) })
            .disposed(by: disposeBag)
    }

    internal func testConcatenate() {
        var values: [Int] = []

        let effect = Effect<Int>.concatenate(
            Effect(value: 1).delay(.seconds(1), scheduler: scheduler).eraseToEffect(),
            Effect(value: 2).delay(.seconds(2), scheduler: scheduler).eraseToEffect(),
            Effect(value: 3).delay(.seconds(3), scheduler: scheduler).eraseToEffect()
        )

        effect
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        XCTAssertEqual(values, [])

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(values, [1])

        scheduler.advance(by: .seconds(2))
        XCTAssertEqual(values, [1, 2])

        scheduler.advance(by: .seconds(3))
        XCTAssertEqual(values, [1, 2, 3])

        scheduler.run()
        XCTAssertEqual(values, [1, 2, 3])
    }

    internal func testConcatenateOneEffect() {
        var values: [Int] = []

        let effect = Effect<Int>.concatenate(
            Effect(value: 1).delay(.seconds(1), scheduler: scheduler).eraseToEffect()
        )

        effect
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        XCTAssertEqual(values, [])

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(values, [1])

        scheduler.run()
        XCTAssertEqual(values, [1])
    }

    internal func testMerge() {
        let effect = Effect<Int>.merge(
            Effect(value: 1).delay(.seconds(1), scheduler: scheduler).eraseToEffect(),
            Effect(value: 2).delay(.seconds(2), scheduler: scheduler).eraseToEffect(),
            Effect(value: 3).delay(.seconds(3), scheduler: scheduler).eraseToEffect()
        )

        var values: [Int] = []
        effect
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)

        XCTAssertEqual(values, [])

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(values, [1])

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(values, [1, 2])

        scheduler.advance(by: .seconds(1))
        XCTAssertEqual(values, [1, 2, 3])
    }

    internal func testEffectSubscriberInitializer() {
        let effect = Effect<Int>.run { subscriber in
            subscriber.onNext(1)
            subscriber.onNext(2)

            self.scheduler.scheduleRelative((), dueTime: .seconds(1)) {
                subscriber.onNext(3)
                return Disposables.create()
            }
            .disposed(by: self.disposeBag)

            self.scheduler.scheduleRelative((), dueTime: .seconds(2)) {
                subscriber.onNext(4)
                subscriber.onCompleted()
                return Disposables.create()
            }
            .disposed(by: self.disposeBag)

            return Disposables.create()
        }

        var values: [Int] = []
        var isComplete = false
        effect
            .subscribe(onNext: { values.append($0) }, onCompleted: { isComplete = true })
            .disposed(by: disposeBag)

        XCTAssertEqual(values, [1, 2])
        XCTAssertEqual(isComplete, false)

        scheduler.advance(by: .seconds(1))

        XCTAssertEqual(values, [1, 2, 3])
        XCTAssertEqual(isComplete, false)

        scheduler.advance(by: .seconds(1))

        XCTAssertEqual(values, [1, 2, 3, 4])
        XCTAssertEqual(isComplete, true)
    }

    internal func testEffectSubscriberInitializer_WithCancellation() {
        enum CancelId {}

        let effect = Effect<Int>.run { subscriber in
            subscriber.onNext(1)

            self.scheduler.scheduleRelative((), dueTime: .seconds(1)) {
                subscriber.onNext(2)
                return Disposables.create()
            }
            .disposed(by: self.disposeBag)

            return Disposables.create()
        }
        .cancellable(id: CancelId.self)

        var values: [Int] = []
        var isComplete = false
        effect
            .subscribe(onNext: { values.append($0) }, onCompleted: { isComplete = true })
            .disposed(by: disposeBag)

        XCTAssertEqual(values, [1])
        XCTAssertEqual(isComplete, false)

        Effect<Void>.cancel(id: CancelId.self)
            .subscribe(onNext: {})
            .disposed(by: disposeBag)

        scheduler.advance(by: .seconds(1))

        XCTAssertEqual(values, [1])
        XCTAssertEqual(isComplete, true)
    }
    
    func testDoubleCancelInFlight() {
        var result: Int?
        
        _ = Observable.just(42)
            .eraseToEffect()
            .cancellable(id: "id", cancelInFlight: true)
            .cancellable(id: "id", cancelInFlight: true)
            .subscribe { result = $0 }
        
        XCTAssertEqual(result, 42)
    }
    
#if DEBUG
    func testUnimplemented() {
        let disposeBag = DisposeBag()
        let effect = Effect<Never>.unimplemented("unimplemented")
        XCTExpectFailure {
            effect
                .subscribe()
                .disposed(by: disposeBag)
        } issueMatcher: { issue in
            issue.compactDescription == "unimplemented - An unimplemented effect ran."
        }
    }
#endif
    /// Can't test `.values`
//    func testTask() async {
//        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else { return }
//        let effect = EffectTask<Int>.task { 42 }
//        for await result in effect.values {
//            XCTAssertEqual(result, 42)
//        }
//    }
    
    func testCancellingTask_Infallible() {
        @Sendable func work() async -> Int {
            do {
                try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
                XCTFail()
            } catch {
            }
            return 42
        }
        var disposeBag = DisposeBag()
        
        Effect<Int>.task { await work() }
            .subscribe(
                onNext: { _ in
                    XCTFail()
                },
                onCompleted: {
                    XCTFail()
                }
            )
            .disposed(by: disposeBag)
        disposeBag = DisposeBag()
        
        
        _ = XCTWaiter.wait(for: [.init()], timeout: 1.1)
    }
    
    func testDependenciesTransferredToEffects_Task() async {
        struct Feature: ReducerProtocol {
            enum Action: Equatable {
                case tap
                case response(Int)
            }
            @Dependency(\.date) var date
            func reduce(into state: inout Int, action: Action) -> Effect<Action> {
                switch action {
                case .tap:
                    return .task {
                        .response(Int(self.date.now.timeIntervalSinceReferenceDate))
                    }
                case let .response(value):
                    state = value
                    return .none
                }
            }
        }
        let store = TestStore(
            initialState: 0,
            reducer: Feature()
                .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
        )
        
        await store.send(.tap).finish(timeout: NSEC_PER_SEC)
        await store.receive(.response(1_234_567_890)) {
            $0 = 1_234_567_890
        }
    }
    func testDependenciesTransferredToEffects_Run() async {
        struct Feature: ReducerProtocol {
            enum Action: Equatable {
                case tap
                case response(Int)
            }
            @Dependency(\.date) var date
            func reduce(into state: inout Int, action: Action) -> Effect<Action> {
                switch action {
                case .tap:
                    return .run { send in
                        await send(.response(Int(self.date.now.timeIntervalSinceReferenceDate)))
                    }
                case let .response(value):
                    state = value
                    return .none
                }
            }
        }
        let store = TestStore(
            initialState: 0,
            reducer: Feature()
                .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
        )
        
        await store.send(.tap).finish(timeout: NSEC_PER_SEC)
        await store.receive(.response(1_234_567_890)) {
            $0 = 1_234_567_890
        }
    }
    
    func testMap() async {
        @Dependency(\.date) var date
        let effect =
        DependencyValues
            .withValue(\.date, .init { Date(timeIntervalSince1970: 1_234_567_890) }) {
                Effect<Void>(value: ())
                    .map { date() }
            }
        let disposeBag = DisposeBag()
        var output: Date?
        effect
            .subscribe(onNext: {
                output = $0
            })
            .disposed(by: disposeBag)
        XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))
        /// TODO: how to use `.values` in the RxSwift to get async version? [Rxswift 6?]
//        if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
//            let effect =
//            DependencyValues
//                .withValue(\.date, .init { Date(timeIntervalSince1970: 1_234_567_890) }) {
//                    Effect<Void>.task {}
//                        .map { date() }
//                }
//            output = await effect.values.first(where: { _ in true })
//            XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))
//        }
    }
    
    func testCanary1() async {
        for _ in 1...100 {
            let task = TestStoreTask(rawValue: Task {}, timeout: NSEC_PER_SEC)
            await task.finish()
        }
    }
    
    func testCanary2() async {
        for _ in 1...100 {
            let task = TestStoreTask(rawValue: nil, timeout: NSEC_PER_SEC)
            await task.finish()
        }
    }
}
