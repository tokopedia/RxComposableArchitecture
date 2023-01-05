import Foundation
import RxSwift
import XCTest

@testable import RxComposableArchitecture

internal final class MemoryManagementTests: XCTestCase {
    internal func testOwnership_ScopeHoldsOntoParent() {
        let disposeBag = DisposeBag()

        let counterReducer = AnyReducer<Int, Void, Void> { state, _, _ in
            state += 1
            return .none
        }
        let store = Store(initialState: 0, reducer: counterReducer, environment: ())
            .scope(state: { "\($0)" })
            .scope(state: { Int($0)! })

        var count = 0

        store.subscribe { $0 }.subscribe(onNext: { count = $0 }).disposed(by: disposeBag)

        XCTAssertEqual(count, 0)
        _ = store.send(())
        XCTAssertEqual(count, 1)
    }
}
