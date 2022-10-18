//
//  NeverEqualVC+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import RxComposableArchitecture

struct NeverEqualState: Equatable {
    @NeverEqual
    var showAlert: String?
    @NeverEqual
    var scrollToTop: Stateless?
}

enum NeverEqualAction: Equatable {
    case didTapShowAlert
    case didTapScrollToTop
}

internal let neverEqualDemoReducer = Reducer<NeverEqualState, NeverEqualAction, Void> {
    state, action, _ in
    switch action {
    case .didTapShowAlert:
        state.showAlert = "This is an alert"
        return .none
    case .didTapScrollToTop:
        state.scrollToTop = Stateless()
        return .none
    }
}
