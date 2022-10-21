//
//  BasicUsage+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 25/05/22.
//

import RxComposableArchitecture

struct Basic: ReducerProtocol {
    struct State: Equatable {
        var number: Int
        var errorMessage: String?
    }
    
    enum Action: Equatable {
        case didTapPlus
        case didTapMinus
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
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
}
