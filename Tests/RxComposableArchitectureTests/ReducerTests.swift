import Foundation
import RxComposableArchitecture
import RxSwift
import XCTest

@MainActor
internal final class ReducerTests: XCTestCase {
    internal func testCallableAsFunction() {
        let reducer = Reduce<Int, Void> { state, _ in
            state += 1
            return .none
        }

        var state = 0
        _ = reducer.reduce(into: &state, action: ())
        XCTAssertEqual(state, 1)
    }

    func testCombine() async {
        enum Action: Equatable {
            case increment
        }
        
        struct One: ReducerProtocol {
            typealias State = Int
            let effect: @Sendable () async -> Void
            func reduce(into state: inout State, action: Action) -> Effect<Action> {
                state += 1
                return .fireAndForget {
                    await self.effect()
                }
            }
        }
        
        var first = false
        var second = false
        
        let store = TestStore2(
            initialState: 0,
            reducer: CombineReducers {
                One(effect: { @MainActor in first = true })
                One(effect: { @MainActor in second = true })
            }
        )
        
        await store
            .send(.increment) { $0 = 2 }
            .finish()
        
        XCTAssertTrue(first)
        XCTAssertTrue(second)
    }

    internal func testDefaultSignpost() {
        let disposeBag = DisposeBag()
        
        let reducer = EmptyReducer<Int, Void>().signpost(log: .default)
        var n = 0
        // swiftformat:disable:next redundantParens
        let effect = reducer.reduce(into: &n, action: ())
        let expectation = self.expectation(description: "effect")
        effect
            .subscribe(onCompleted: { expectation.fulfill() })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 0.1)
    }

    internal func testDisabledSignpost() {
        let disposeBag = DisposeBag()

        let reducer = EmptyReducer<Int, Void>().signpost(log: .disabled)
        var n = 0
        // swiftformat:disable:next redundantParens
        let effect = reducer.reduce(into: &n, action: ())
        let expectation = self.expectation(description: "effect")
        effect
            .subscribe(onCompleted: { expectation.fulfill() })
            .disposed(by: disposeBag)
        wait(for: [expectation], timeout: 0.1)
    }
}
