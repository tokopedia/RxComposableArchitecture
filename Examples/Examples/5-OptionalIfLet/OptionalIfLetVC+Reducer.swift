//
//  OptionalIfLetVC+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 06/06/22.
//

import CasePaths
import RxComposableArchitecture

internal struct OptionalIfLet: ReducerProtocol {
    internal struct State: Equatable {
        internal var number = 0
        internal var counter: Counter.State?
    }
    
    internal enum Action: Equatable {
        case didToggle
        case counter(Counter.Action)
    }
    
    var body: some ReducerProtocol<OptionalIfLet.State, OptionalIfLet.Action> {
        Reduce { state, action in
            switch action {
            case .didToggle:
                if let counter = state.counter {
                    state.number = counter.number
                    state.counter = nil
                } else {
                    state.counter = Counter.State(number: 0)
                }
                return .none
            case .counter: return .none
            }
        }
        .ifLet(\.counter, action: /Action.counter) {
            Counter()
        }
    }
}
