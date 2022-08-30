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
        let testStore = TestStore(initialState: Basic.State(number: 0), reducer: Basic())
        
        testStore.send(.didTapPlus) {
            $0.number = 1
        }
    }
    
    func testTapMinus() {
        let testStore = TestStore(initialState: Basic.State(number: 5), reducer: Basic())
        
        testStore.send(.didTapMinus) {
            $0.number = 4
        }
    }
    
    func testTapMinusOnZero() {
        let testStore = TestStore(initialState: Basic.State(number: 0), reducer: Basic())
        
        testStore.send(.didTapMinus) {
            $0.errorMessage = "Can't below 0"
        }
    }
    
    func testShouldResetErrorWhenTappingPlus() {
        let testStore = TestStore(initialState: Basic.State(number: 0, errorMessage: "SomeError"), reducer: Basic())
        
        testStore.send(.didTapPlus) {
            $0.number = 1
            $0.errorMessage = nil
        }
    }
    
    func testShouldResetErrorWhenTappingMinusWithNumberGreaterThanZero() {
        let testStore = TestStore(initialState: Basic.State(number: 1, errorMessage: "SomeError"), reducer: Basic())
        
        testStore.send(.didTapMinus) {
            $0.number = 0
            $0.errorMessage = nil
        }
    }
}
