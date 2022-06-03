//
//  BasicUsage+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 25/05/22.
//

import RxComposableArchitecture

struct BasicState: Equatable {
    var number: Int
    var errorMessage: String?
}

enum BasicAction: Equatable {
    case didTapPlus
    case didTapMinus
}

let basicUsageReducer = Reducer<BasicState, BasicAction, Void> { state, action, _ in
    switch action {
    case .didTapMinus:
        guard state.number > 0 else {
            state.errorMessage = "Can't below 0"
            return .none
        }
        state.number -= 1
        state.errorMessage = nil
        return .none
    case .didTapPlus:
        state.number += 1
        state.errorMessage = nil
        return .none
    }
}
