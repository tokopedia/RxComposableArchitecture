//
//  File.swift
//  
//
//  Created by andhika.setiadi on 13/11/22.
//

import RxSwift
import XCTest
import Dependencies

@testable import RxComposableArchitecture

/// All Test cases in here using `useNewScope: true` on both Store(...) and TestStore(...)
///
@MainActor
internal class TestStoreTests: XCTestCase {
    private let disposeBag = DisposeBag()
    
    internal func testEffectConcatenation() async {
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
        
        _ = await store.send(Action.a)
        
        mainQueue.advance(by: .seconds(1))
        
        await store.receive(Action.b1)
        await store.receive(Action.b2)
        await store.receive(Action.b3)
        
        await store.receive(Action.c1)
        await store.receive(Action.c2)
        await store.receive(Action.c3)
        
        _ = await store.send(Action.d)
    }
    
    internal func testAsync() async {
        enum Action: Equatable {
            case tap
            case response(Int)
        }
        
        let store = TestStore(
            initialState: 0,
            reducer: Reduce<Int, Action>({ state, action in
                switch action {
                case .tap:
                    return .task { .response(42) }
                case let .response(number):
                    state = number
                    return .none
                }
            })
        )
        
        _ = await store.send(.tap)
        await store.receive(.response(42)) {
            $0 = 42
        }
    }
    
#if DEBUG
    internal func testExpectedStateEquality() async {
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
        
        _ = await store.send(.increment) {
            $0.isChanging = true
        }
        
        await store.receive(.changed(from: 0, to: 1)) {
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
    
    internal func testExpectedStateEqualityMustModify() async {
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
        
        _ = await store.send(.noop)
        await store.receive(.finished)
        
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
    
    func testReceiveActionMatchingPredicate() async {
        enum Action: Equatable {
            case noop, finished
        }
        
        let reducer = Reduce<Int, Action>(internal: { state, action in
            switch action {
            case .noop:
                return Effect(value: .finished)
            case .finished:
                return .none
            }
        })
        
        let store = TestStore(initialState: 0, reducer: reducer)
        
        let predicateShouldBeCalledExpectation = expectation(
            description: "predicate should be called")
        await store.send(.noop)
        await store.receive { action in
            predicateShouldBeCalledExpectation.fulfill()
            return action == .finished
        }
        wait(for: [predicateShouldBeCalledExpectation], timeout: 0)
        
        XCTExpectFailure {
            store.send(.noop)
            store.receive(.noop)
        }
        
        XCTExpectFailure {
            store.send(.noop)
            store.receive { $0 == .noop }
        }
    }
    
#endif
    
    internal func testStateAccess() async {
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
        
        _ = await store.send(.a) {
            $0 = 1
            XCTAssertEqual(store.state, 0)
        }
        XCTAssertEqual(store.state, 1)
        
        await store.receive(.b) {
            $0 = 2
            XCTAssertEqual(store.state, 1)
        }
        XCTAssertEqual(store.state, 2)
        
        await store.receive(.c) {
            $0 = 3
            XCTAssertEqual(store.state, 2)
        }
        XCTAssertEqual(store.state, 3)
        
        await store.receive(.d) {
            $0 = 4
            XCTAssertEqual(store.state, 3)
        }
        
        XCTAssertEqual(store.state, 4)
    }
    
    func testOverrideDependenciesDirectlyOnReducer() {
        struct Counter: ReducerProtocol {
            @Dependency(\.calendar) var calendar
            @Dependency(\.locale) var locale
            @Dependency(\.timeZone) var timeZone
            @Dependency(\.urlSession) var urlSession
            
            func reduce(into state: inout Int, action: Bool) -> Effect<Bool> {
                _ = self.calendar
                _ = self.locale
                _ = self.timeZone
                _ = self.urlSession
                state += action ? 1 : -1
                return .none
            }
        }
        
        let store = TestStore(
            initialState: 0,
            reducer: Counter()
                .dependency(\.calendar, Calendar(identifier: .gregorian))
                .dependency(\.locale, Locale(identifier: "en_US"))
                .dependency(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .dependency(\.urlSession, URLSession(configuration: .ephemeral))
        )
        
        store.send(true) { $0 = 1 }
    }
    
    func testOverrideDependenciesOnTestStore() {
        struct Counter: ReducerProtocol {
            @Dependency(\.calendar) var calendar
            @Dependency(\.client.fetch) var fetch
            @Dependency(\.locale) var locale
            @Dependency(\.timeZone) var timeZone
            @Dependency(\.urlSession) var urlSession
            
            func reduce(into state: inout Int, action: Bool) -> Effect<Bool> {
                _ = self.calendar
                _ = self.locale
                _ = self.timeZone
                _ = self.urlSession
                state += action ? 1 : -1
                return .none
            }
        }
        
        let store = TestStore(
            initialState: 0,
            reducer: Counter()
        ) {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.client.fetch = { 1 }
            $0.locale = Locale(identifier: "en_US")
            $0.timeZone = TimeZone(secondsFromGMT: 0)!
            $0.urlSession = URLSession(configuration: .ephemeral)
        }
        
        store.send(true) { $0 = 1 }
    }
    
    func testDependenciesEarlyBinding() async {
        struct Feature: ReducerProtocol {
            struct State: Equatable {
                var count = 0
                var date: Date
                init() {
                    @Dependency(\.date.now) var now: Date
                    self.date = now
                }
            }
            enum Action: Equatable {
                case tap
                case response(Int)
            }
            @Dependency(\.date.now) var now: Date
            func reduce(into state: inout State, action: Action) -> Effect<Action> {
                switch action {
                case .tap:
                    state.count += 1
                    return .task { .response(42) }
                case let .response(number):
                    state.count = number
                    state.date = now
                    return .none
                }
            }
        }
        
        let store = TestStore(
            initialState: Feature.State(),
            reducer: Feature()
        ) {
            $0.date = .constant(Date(timeIntervalSince1970: 1_234_567_890))
        }
        
        await store.send(.tap) {
            @Dependency(\.date.now) var now: Date
            $0.count = 1
            $0.date = now
        }
        await store.receive(.response(42)) {
            @Dependency(\.date.now) var now: Date
            $0.count = 42
            $0.date = now
        }
    }
}

private struct Client: DependencyKey {
    var fetch: () -> Int
    static let liveValue = Client(fetch: { 42 })
}

extension DependencyValues {
    fileprivate var client: Client {
        get { self[Client.self] }
        set { self[Client.self] = newValue }
    }
}
