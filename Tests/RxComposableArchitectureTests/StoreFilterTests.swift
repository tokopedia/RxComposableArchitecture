//
//  File.swift
//  
//
//  Created by andhika.setiadi on 18/12/23.
//

#if DEBUG
    import XCTest
    import RxSwift

    @testable import RxComposableArchitecture

    @MainActor
    final class StoreFilterTests: XCTestCase {
        let disposeBag = DisposeBag()
        
        func testFilter() {
            let store = Store<Int?, Void>(initialState: nil, reducer: EmptyReducer())
                .filter { state, _ in state != nil }
            
            let viewStore = ViewStore(store, observe: { $0 })
            var count = 0
            viewStore
                .observable
                .subscribe(onNext: { _ in count += 1 })
                .disposed(by: disposeBag)
            
            XCTAssertEqual(count, 1)
            viewStore.send(())
            XCTAssertEqual(count, 1)
            viewStore.send(())
            XCTAssertEqual(count, 1)
        }
    }
#endif
