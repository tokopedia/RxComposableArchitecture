//
//  ScopingVC+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import CasePaths
import RxComposableArchitecture

internal struct ScopingState: Equatable {
    internal var counter = CounterState()
}

internal enum ScopingAction: Equatable {
    case didTapJump
    case counter(CounterAction)
}

internal let scopingReducer = Reducer<ScopingState, ScopingAction, Void> { state, action, _ in
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

internal struct CounterState: Equatable {
    internal var number: Int = 0
}

internal enum CounterAction: Equatable {
    case didTapMinus
    case didTapPlus
}
