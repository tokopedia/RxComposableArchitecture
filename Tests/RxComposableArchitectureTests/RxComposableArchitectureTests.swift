//
//  RxComposableArchitectureTests.swift
//  RxComposableArchitectureTests
//
//  Created by module_generator on 06/05/20.
//  Copyright © 2020 module_generator. All rights reserved.
//

import RxComposableArchitecture
import RxSwift
import XCTest
import XCTestDynamicOverlay
import Dependencies

@MainActor
internal class RxComposableArchitectureTests: XCTestCase {
    internal func testScheduling() {
        struct Counter: ReducerProtocol {
            typealias State = Int
            
            enum Action: Equatable {
                case incrAndSquareLater
                case incrNow
                case squareNow
            }
            
            @Dependency(\.rxMainQueue) var scheduler
            
            func reduce(into state: inout Int, action: Action) -> Effect<Action> {
                switch action {
                case .incrAndSquareLater:
                    return .merge(
                        Effect(value: .incrNow)
                            .delay(.seconds(2), scheduler: scheduler)
                            .eraseToEffect(),
                        Effect(value: .squareNow)
                            .delay(.seconds(1), scheduler: scheduler)
                            .eraseToEffect(),
                        Effect(value: .squareNow)
                            .delay(.seconds(2), scheduler: scheduler)
                            .eraseToEffect()
                    )
                case .incrNow:
                    state += 1
                    return .none
                case .squareNow:
                    state *= state
                    return .none
                }
            }
        }
        
        let scheduler = TestScheduler(initialClock: 0)

        let store = TestStore(
            initialState: 2,
            reducer: Counter(),
            useNewScope: true
        )
        
        store.dependencies.rxMainQueue = scheduler

        store.send(.incrAndSquareLater)
        scheduler.advance(by: .seconds(1))
        store.receive(.squareNow) { $0 = 4 }
        scheduler.advance(by: .seconds(1))
        store.receive(.incrNow) { $0 = 5 }
        store.receive(.squareNow) { $0 = 25 }

        store.send(.incrAndSquareLater)
        scheduler.advance(by: .seconds(2))
        store.receive(.squareNow) { $0 = 625 }
        store.receive(.incrNow) { $0 = 626 }
        store.receive(.squareNow) { $0 = 391_876 }
    }
    
    internal func testLongLivingEffects() {
        let subject = PublishSubject<Void>()
        
        enum Action { case end, incr, start }

        let reducer = Reduce<Int, Action> { state, action in
            switch action {
            case .end:
                return .fireAndForget { subject.onCompleted() }
            case .incr:
                state += 1
                return .none
            case .start:
                return subject.eraseToEffect().map { Action.incr }
            }
        }
        
        let store = TestStore(
            initialState: 0,
            reducer: reducer,
            useNewScope: true
        )

        store.send(.start)
        store.send(.incr) { $0 = 1 }
        subject.onNext(())
        store.receive(.incr) { $0 = 2 }
        store.send(.end)
    }

    internal func testCancellation() {
        struct Cancellation: ReducerProtocol {
            typealias State = Int
            
            enum Action: Equatable {
                case cancel
                case incr
                case response(Int)
            }
            
            @Dependency(\.myEnvironment) var environment
            @Dependency(\.rxMainQueue) var mainQueue
            
            func reduce(into state: inout Int, action: Action) -> Effect<Action> {
                enum CancelId {}

                switch action {
                case .cancel:
                    return .cancel(id: CancelId.self)

                case .incr:
                    state += 1
                    return environment.fetch(state)
                        .observeOn(mainQueue)
                        .map(Action.response)
                        .eraseToEffect()
                        .cancellable(id: CancelId.self)

                case let .response(value):
                    state = value
                    return .none
                }
            }
        }
        
        
        let scheduler = TestScheduler(initialClock: 0)

        let store = TestStore(
            initialState: 0,
            reducer: Cancellation(),
            useNewScope: true
        )
        
        store.dependencies.myEnvironment.fetch = { value in Effect(value: value * value) }
        store.dependencies.rxMainQueue = scheduler

        store.send(.incr) { $0 = 1 }
        scheduler.advance(by: .milliseconds(1))
        store.receive(.response(1))

        store.send(.incr) { $0 = 2 }
        store.send(.cancel)
        scheduler.run()
    }
    
    /// creating new test cases for using async await
    ///
    internal func testCancellationWithAsync() async {
        await withMainSerialExecutor {
            let mainQueue = DispatchQueue.test
            
            enum Action: Equatable {
                case cancel
                case incr
                case response(Int)
            }
            
            let reducer = Reduce<Int, Action> { state, action in
                enum CancelID {}
                
                switch action {
                case .cancel:
                    return .cancel(id: CancelID.self)
                    
                case .incr:
                    state += 1
                    return .task { [state] in
                        try await mainQueue.sleep(for: .seconds(1))
                        return .response(state * state)
                    }
                    .cancellable(id: CancelID.self)
                    
                case let .response(value):
                    state = value
                    return .none
                }
            }
            
            let store = TestStore(
                initialState: 0,
                reducer: reducer
            )
            
            await store.send(.incr) { $0 = 1 }
            await mainQueue.advance(by: .seconds(1))
            await store.receive(.response(1))
            
            await store.send(.incr) { $0 = 2 }
            await store.send(.cancel)
            await store.finish()
        }
    }
}

private struct MyEnvironment: DependencyKey {
    var fetch: (Int) -> Effect<Int>
    
    static let liveValue: MyEnvironment = MyEnvironment(
        fetch: { value in Effect(value: value * value) }
    )
    
    static let testValue: MyEnvironment = MyEnvironment(
        fetch: unimplemented("unimplemented fetch")
    )
}

extension DependencyValues {
    fileprivate var myEnvironment: MyEnvironment {
        get { self[MyEnvironment.self] }
        set { self[MyEnvironment.self] = newValue }
    }
}
