//
//  BoostrapTests.swift
//  
//
//  Created by jefferson.setiawan on 03/08/22.
//

import RxSwift
import XCTest

@testable import RxComposableArchitecture

internal final class BoostrapTests: XCTestCase {
    internal func testBootsrap() {
        struct Env {
            var getNumber: () -> Int
        }
        
        let reducer = AnyReducer<Int, Void, Env> { state, action, env in
            state = env.getNumber()
            return .none
        }
        let env = Env(getNumber: {
            return 0
        })
        let store = Store(initialState: -1, reducer: reducer, environment: env)
        
        let mockEnv = Env(getNumber: {
            return 100
        })
        Bootstrap.mock(environment: mockEnv)
        
        _ = store.send(())

        XCTAssertEqual(store.state, 100)
        
        // clearing the bootstrap
        Bootstrap.clear(environment: Env.self)
        _ = store.send(())
        XCTAssertEqual(store.state, 0)
    }
    
    internal func testDependenciesBootstrap() {
        struct GetNumber: ReducerProtocol {
            typealias State = Int
            typealias Action = Void
            
            @Dependency(\.myEnvironment) private var environment
            
            func reduce(into state: inout Int, action: Void) -> Effect<Void> {
                state = environment.fetch()
                return .none
            }
        }
        
        Bootstrap.mock(for: GetNumber()) {
            $0.dependency(\.myEnvironment.fetch, { 2 })
        }
        
        let store = Store(
            initialState: 0,
            reducer: GetNumber()
        )
        
        store.send(())
        
        XCTAssertEqual(store.state, 2)
    }
}

private struct MyEnvironment: DependencyKey {
    var fetch: () -> Int
    
    static let liveValue: MyEnvironment = MyEnvironment(
        fetch: { 1 }
    )
}

extension DependencyValues {
    fileprivate var myEnvironment: MyEnvironment {
        get { self[MyEnvironment.self] }
        set { self[MyEnvironment.self] = newValue }
    }
}
