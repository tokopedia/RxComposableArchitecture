//
//  PullbackReducerTests.swift
//  ExamplesTests
//
//  Created by jefferson.setiawan on 03/06/22.
//

import XCTest
import RxComposableArchitecture
import RxSwift
@testable import Examples

class PullbackReducerTests: XCTestCase {
    func testDidChangeText() {
        let testStore = TestStore(
            initialState: Pullback.State(),
            reducer: Pullback(),
            failingWhenNothingChange: true,
            useNewScope: true
        )
        testStore.send(.textDidChange("Hello")) {
            $0.text = "You write: Hello"
        }
    }
    
    func testSmallerReducer() {
        let testStore = TestStore(
            initialState: Counter.State(),
            reducer: Counter(),
            failingWhenNothingChange: true,
            useNewScope: true
        )
        testStore.send(.didTapMinus) {
            $0.number = -1
        }
        
        testStore.send(.didTapPlus) {
            $0.number = 0
        }
    }
}
