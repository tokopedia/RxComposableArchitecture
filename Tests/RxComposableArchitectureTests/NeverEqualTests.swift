//
//  NeverEqualTests.swift
//  
//
//  Created by jefferson.setiawan on 03/06/22.
//

@_spi(Internals) import RxComposableArchitecture
import RxSwift
import XCTest

internal final class NeverEqualTests: XCTestCase {
    private let disposeBag = DisposeBag()
    
    func testIncrement() {
        @NeverEqual var value = "Hello"
        let oldValue = $value
        value = "hello"
        XCTAssertNotEqual(oldValue, $value)
    }
    
    internal func testDistinctSet() {
        @NeverEqual var value = "Hello"
        (0 ..< 255).forEach { _ in
            value = "Hello"
        } // testing to max 255
        value = "Hello" // trigger 256, it should reset the numberOfIncrement to 0 again
        XCTAssertEqual($value, NeverEqual(wrappedValue: "Hello"))
    }
    
    internal func testStoreSubscriptionOfNeverEqual() {
        struct MyState: Equatable {
            @NeverEqual var run: Stateless?
        }
        enum MyAction: Equatable {
            case tap
        }
        
        let store = Store(
            initialState: MyState(),
            reducer: Reducer<MyState, MyAction, Void> { state, action, _ in
                switch action {
                case .tap:
                    state.run = Stateless()
                    return .none
                }
            },
            environment: ()
        )
        var called = 0
        store.subscribeNeverEqual(\.$run)
            .subscribe(onNext: {
                if $0 != nil {
                    called += 1
                }
            })
            .disposed(by: disposeBag)
        
        store.send(.tap)
        XCTAssertEqual(called, 1)
        
        store.send(.tap)
        XCTAssertEqual(called, 2)
    }
}
