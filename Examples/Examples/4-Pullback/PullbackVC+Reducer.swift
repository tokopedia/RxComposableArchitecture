//
//  PullbackVC+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import CasePaths
import RxComposableArchitecture

internal struct Pullback: ReducerProtocol {
    func reduce(into state: inout State, action: Action) -> RxComposableArchitecture.Effect<Action> {
        switch action {
        case let .textDidChange(text):
            state.text = "You write: \(text)"
            return .none
        case .counter:
            return .none
        }
    }
    
    internal struct State: Equatable {
        internal var text: String = ""
        internal var counter = Counter.State(number: 0)
    }
    
    internal enum Action: Equatable {
        case textDidChange(String)
        case counter(Counter.Action)
    }
    
    var body: some ReducerProtocol<Pullback.State, Pullback.Action> {
        Scope(state: \State.counter, action: /Action.counter) {
            Counter()
        }
        
        /// We can observe child action in parent reducer and do some work or additional logic here
        Reduce { state, action in
            switch action {
            case .counter(.didTapPlus):
                print(">>> trackerDidTapPlus")
                return .none
            default:
                return .none
            }
        }
    }
}
