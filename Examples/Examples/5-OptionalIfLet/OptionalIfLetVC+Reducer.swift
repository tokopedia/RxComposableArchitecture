//
//  OptionalIfLetVC+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 06/06/22.
//

import CasePaths
import RxComposableArchitecture

internal struct OptionalIfLetState: Equatable {
    internal var number = 0
    internal var counter: CounterState?
}

internal enum OptionalIfLetAction: Equatable {
    case didToggle
    case counter(CounterAction)
}

internal let optionalIfLetReducer = Reducer<OptionalIfLetState, OptionalIfLetAction, Void>.combine(
    pullbackCounterReducer.optional()
        .pullback(
            state: \.counter,
            action: /OptionalIfLetAction.counter,
            environment: { _ in }
        ),
    Reducer { state, action, _ in
        switch action {
        case .didToggle:
            if let counter = state.counter {
                state.number = counter.number
                state.counter = nil
            } else {
                state.counter = CounterState(number: state.number)
            }
            return .none
        case .counter: return .none
        }
    }

)
