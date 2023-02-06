//
//  PullbackVC+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import CasePaths
import RxComposableArchitecture

internal struct Pullback: ReducerProtocol {
    internal struct State: Equatable {
        internal var text: String = ""
        internal var counter = Counter.State(number: 0)
    }
    
    internal enum Action: Equatable {
        case textDidChange(String)
        case counter(Counter.Action)
    }
    
    var body: some ReducerProtocolOf<Pullback> {
        Reduce { state, action in
            switch action {
            case .counter(.didTapPlus):
                print(">>> trackerDidTapPlus")
                return .none

            case let .textDidChange(text):
                state.text = "You write: \(text)"
                return .none

            default:
                return .none
            }
        }
        
        Scope(state: \.counter, action: /Action.counter) {
            Counter()
        }
    }
}
