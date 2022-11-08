//
//  NeverEqualVC+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import RxComposableArchitecture

struct NeverEqualExample: ReducerProtocol {
    struct State: Equatable {
        @NeverEqual var showAlert: String?
        @NeverEqual var scrollToTop: Stateless?
    }
    
    enum Action: Equatable {
        case didTapShowAlert
        case didTapScrollToTop
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .didTapShowAlert:
            state.showAlert = "This is an alert"
            return .none
        case .didTapScrollToTop:
            state.scrollToTop = Stateless()
            return .none
        }
    }
    
}
