//
//  ExamplesTests.swift
//  ExamplesTests
//
//  Created by jefferson.setiawan on 17/05/22.
//

import RxComposableArchitecture
import XCTest
@testable import Examples

class BasicReducerTests: XCTestCase {

    func testTapPlus() {
        let testStore = TestStore(initialState: BasicState(number: 0), reducer: basicUsageReducer, environment: (), useNewScope: true)
        
        testStore.send(.didTapPlus) {
            $0.number = 1
        }
    }
    
    func testTapMinus() {
        let testStore = TestStore(initialState: BasicState(number: 5), reducer: basicUsageReducer, environment: (), useNewScope: true)
        
        testStore.send(.didTapMinus) {
            $0.number = 4
        }
    }
    
    func testTapMinusOnZero() {
        let testStore = TestStore(initialState: BasicState(number: 0), reducer: basicUsageReducer, environment: (), useNewScope: true)
        
        testStore.send(.didTapMinus) {
            $0.errorMessage = "Can't below 0"
        }
    }
    
    func testShouldResetErrorWhenTappingPlus() {
        let testStore = TestStore(initialState: BasicState(number: 0, errorMessage: "SomeError"), reducer: basicUsageReducer, environment: (), useNewScope: true)
        
        testStore.send(.didTapPlus) {
            $0.number = 1
            $0.errorMessage = nil
        }
    }
    
    func testShouldResetErrorWhenTappingMinusWithNumberGreaterThanZero() {
        let testStore = TestStore(initialState: BasicState(number: 1, errorMessage: "SomeError"), reducer: basicUsageReducer, environment: (), useNewScope: true)
        
        testStore.send(.didTapMinus) {
            $0.number = 0
            $0.errorMessage = nil
        }
    }
}
