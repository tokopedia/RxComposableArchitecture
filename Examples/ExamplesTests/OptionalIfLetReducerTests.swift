//
//  OptionalIfLetReducerTests.swift
//  ExamplesTests
//
//  Created by jefferson.setiawan on 06/06/22.
//

import RxComposableArchitecture
import RxSwift
import XCTest

@testable import Examples

class OptionalIfLetReducerTests: XCTestCase {
    func testDidSwitchToggle() {
        let testStore = TestStore(
            initialState: OptionalIfLetState(), reducer: optionalIfLetReducer, environment: ())
        testStore.send(.didToggle) {
            $0.counter = CounterState()
        }
    }

    func testChangeCounterThenToggle() {
        let testStore = TestStore(
            initialState: OptionalIfLetState(number: 0, counter: CounterState(number: 10)),
            reducer: optionalIfLetReducer, environment: ())
        testStore.send(.counter(.didTapPlus)) {
            $0.counter!.number = 11
        }

        testStore.send(.didToggle) {
            $0.number = 11
            $0.counter = nil
        }
    }
}
