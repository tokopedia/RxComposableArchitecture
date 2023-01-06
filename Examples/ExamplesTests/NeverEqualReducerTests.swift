//
//  NeverEqualReducerTests.swift
//  ExamplesTests
//
//  Created by jefferson.setiawan on 03/06/22.
//

import RxComposableArchitecture
import XCTest

@testable import Examples

final class NeverEqualReducerTests: XCTestCase {
    internal func testTapToast() {
        let testStore = TestStore(
            initialState: NeverEqualExample.State(),
            reducer: NeverEqualExample(),
            failingWhenNothingChange: true,
            useNewScope: true
        )
        testStore.send(.didTapShowAlert) {
            $0.showAlert = "This is an alert"
        }

        testStore.send(.didTapShowAlert) {
            $0.showAlert = "This is an alert"
        }
    }

    internal func testTapScrollToTop() {
        let testStore = TestStore(
            initialState: NeverEqualExample.State(),
            reducer: NeverEqualExample(),
            failingWhenNothingChange: true,
            useNewScope: true
        )
        testStore.send(.didTapScrollToTop) {
            $0.scrollToTop = Stateless()
        }

        testStore.send(.didTapScrollToTop) {
            $0.scrollToTop = Stateless()
        }
    }
}
