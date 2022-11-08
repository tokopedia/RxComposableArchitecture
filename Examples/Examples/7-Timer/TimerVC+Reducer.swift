//
//  TimerVC+Reducer.swift
//  Examples
//
//  Created by victor.cuaca on 07/10/22.
//

import RxComposableArchitecture
import RxSwift

struct TimerExample: ReducerProtocol {
    struct State: Equatable {
        var tickCount: Int = 0
    }
    
    enum Action: Equatable {
        case onDidLoad
        case onTimerTick
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onDidLoad:
            return Effect<Int>.timer(id: "0", every: .seconds(1), on: MainScheduler.instance)
                .map { _ in
                    print(">> Timer tick")
                    return Action.onTimerTick
                }
            
        case .onTimerTick:
            state.tickCount += 1
            return .none
        }
    }
}
