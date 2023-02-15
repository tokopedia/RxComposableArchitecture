//
//  OptionalIfLetReducerTests.swift
//  ExamplesTests
//
//  Created by jefferson.setiawan on 06/06/22.
//

import XCTest
import RxComposableArchitecture
import RxSwift
@testable import Examples

class OptionalIfLetReducerTests: XCTestCase {
    func testDidSwitchToggle() {
        let testStore = TestStore2(
            initialState: OptionalIfLet.State(),
            reducer: OptionalIfLet()
        )
        testStore.send(.didToggle) {
            $0.counter = Counter.State()
        }
    }
    
    func testChangeCounterThenToggle() {
        let testStore = TestStore2(
            initialState: OptionalIfLet.State(number: 0, counter: Counter.State(number: 10)),
            reducer: OptionalIfLet()
        )
        testStore.send(.counter(.didTapPlus)) {
            $0.counter!.number = 11
        }
        
        testStore.send(.didToggle) {
            $0.number = 11
            $0.counter = nil
        }
    }
}
