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
        let store = Store2(initialState: -1, reducer: reducer, environment: env)
        
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
}
