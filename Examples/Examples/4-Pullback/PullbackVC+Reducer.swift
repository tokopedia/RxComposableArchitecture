//
//  PullbackVC+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import CasePaths
import RxComposableArchitecture

internal struct PullbackState: Equatable {
    internal var text: String = ""
    internal var counter = CounterState()
}

internal enum PullbackAction: Equatable {
    case textDidChange(String)
    case counter(CounterAction)
}

internal let pullbackCounterReducer = Reducer<CounterState, CounterAction, Void> {
    state, action, _ in
    switch action {
    case .didTapMinus:
        state.number -= 1
        return .none
    case .didTapPlus:
        state.number += 1
        return .none
    }
}

private let defaultReducer = Reducer<PullbackState, PullbackAction, Void> { state, action, _ in
    switch action {
    case let .textDidChange(text):
        state.text = "You write: \(text)"
        return .none
    case .counter:
        return .none
    }
}

/// This is where we combine it to the parent reducer
internal let pullbackReducer = Reducer<PullbackState, PullbackAction, Void>.combine(
    pullbackCounterReducer.pullback(
        state: \.counter,
        action: /PullbackAction.counter,
        environment: { _ in }
    ),
    defaultReducer
)
