//
//  ScopingReducerTests.swift
//  ExamplesTests
//
//  Created by jefferson.setiawan on 03/06/22.
//

import XCTest
import RxComposableArchitecture
import RxSwift
@testable import Examples

class ScopingReducerTests: XCTestCase {
    func testTapPlus() {
        let testStore = TestStore(
            initialState: Scoping.State(),
            reducer: Scoping(),
            failingWhenNothingChange: true,
            useNewScope: true
        )
        
        testStore.send(.counter(.didTapPlus)) {
            $0.counter.number = 1
        }
    }
    
    func testTapMinus() {
        let testStore = TestStore(
            initialState: Scoping.State(),
            reducer: Scoping(),
            failingWhenNothingChange: true,
            useNewScope: true
        )
        
        testStore.send(.counter(.didTapMinus)) {
            $0.counter.number = -1
        }
    }
    
    func testTapJumpButton() {
        let testStore = TestStore(
            initialState: Scoping.State(),
            reducer: Scoping(),
            failingWhenNothingChange: true,
            useNewScope: true
        )
        
        testStore.send(.didTapJump) {
            $0.counter.number = 100
        }
    }
}
