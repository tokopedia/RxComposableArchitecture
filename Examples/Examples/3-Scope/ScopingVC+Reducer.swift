//
//  ScopingVC+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import CasePaths
import RxComposableArchitecture

internal struct Scoping: ReducerProtocol {
    internal struct State: Equatable {
        internal var counter = Counter.State()
    }
    
    internal enum Action: Equatable {
        case didTapJump
        case counter(Counter.Action)
    }
    
    internal func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .didTapJump:
            state.counter.number = 100
            return .none
        case .counter(.didTapMinus):
            state.counter.number -= 1
            return .none
        case .counter(.didTapPlus):
            state.counter.number += 1
            return .none
        }
    }
}

internal struct CounterState: Equatable {
    internal var number: Int = 0
}

internal enum CounterAction: Equatable {
    case didTapMinus
    case didTapPlus
}

internal struct Counter: ReducerProtocol {
    internal struct State: Equatable {
        internal var number: Int = 0
    }
    
    internal enum Action: Equatable {
        case didTapMinus
        case didTapPlus
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .didTapPlus:
            state.number += 1
            return .none
        case .didTapMinus:
            state.number -= 1
            return .none
        }
    }
    
}
