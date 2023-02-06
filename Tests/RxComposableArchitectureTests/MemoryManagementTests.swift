import Foundation
import RxSwift
import XCTest

import RxComposableArchitecture

internal final class MemoryManagementTests: XCTestCase {
    internal func testOwnership_ScopeHoldsOntoParent() {
        let disposeBag = DisposeBag()

        let counterReducer = Reduce<Int, Void> { state, _ in
            state += 1
            return .none
        }
        let store = Store(initialState: 0, reducer: counterReducer)
            .scope(state: { "\($0)" })
            .scope(state: { Int($0)! })

        var count = 0

        store.subscribe { $0 }.subscribe(onNext: { count = $0 }).disposed(by: disposeBag)

        XCTAssertEqual(count, 0)
        _ = store.send(())
        XCTAssertEqual(count, 1)
    }
    
    internal func testOwnership_ViewStoreHoldsOntoStore() {
        let disposeBag = DisposeBag()
        let counterReducer = Reduce<Int, Void> { state, _ in
            state += 1
            return .none
        }
        let store = Store(initialState: 0, reducer: counterReducer)
        
        var count = 0
        store.subscribe { $0 }.subscribe(onNext: { count = $0 }).disposed(by: disposeBag)
        
        XCTAssertEqual(count, 0)
        store.send(())
        XCTAssertEqual(count, 1)
    }
    
    func testEffectWithMultipleScopes() {
        let disposeBag = DisposeBag()
        let expectation = self.expectation(description: "")
        
        enum Action { case tap, response }
        let store = Store(
            initialState: false,
            reducer: Reduce<Bool, Action> { state, action in
                switch action {
                case .tap:
                    state = false
                    return .task { .response }
                case .response:
                    state = true
                    return .fireAndForget {
                        expectation.fulfill()
                    }
                }
            }
        )
        
        var values: [Bool] = []
        store.subscribe()
            .subscribe(onNext: { values.append($0) })
            .disposed(by: disposeBag)
        
        XCTAssertEqual(values, [false])
        store.send(.tap)
        self.wait(for: [expectation], timeout: 1)
        XCTAssertEqual(values, [false, true])
    }
}
