//
//  BindingLocalTests.swift
//
//
//  Created by andhika.setiadi on 18/12/23.
//

#if DEBUG
  import XCTest

  @testable import RxComposableArchitecture

  @MainActor
  final class BindingLocalTests: XCTestCase {
    public func testBindingLocalIsActive() {
      XCTAssertFalse(BindingLocal.isActive)

      struct MyReducer: ReducerProtocol {
        struct State: Equatable {
          var text = ""
        }

        enum Action: Equatable {
          case textChanged(String)
        }

        func reduce(into state: inout State, action: Action) -> Effect<Action> {
          switch action {
          case let .textChanged(text):
            state.text = text
            return .none
          }
        }
      }

      let store = Store(initialState: MyReducer.State(), reducer: MyReducer())
      let viewStore = ViewStore(store, observe: { $0 })

      let binding = viewStore.binding(get: \.text) { text in
        XCTAssertTrue(BindingLocal.isActive)
        return .textChanged(text)
      }
      binding.wrappedValue = "Hello!"
      XCTAssertEqual(viewStore.text, "Hello!")
    }
  }
#endif
