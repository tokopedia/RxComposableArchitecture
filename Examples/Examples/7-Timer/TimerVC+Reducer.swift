//
//  TimerVC+Reducer.swift
//  Examples
//
//  Created by victor.cuaca on 07/10/22.
//

import RxComposableArchitecture
import RxSwift

struct TimerState: Equatable {
    var tickCount: Int = 0
}

enum TimerAction: Equatable {
    case onDidLoad
    case onTimerTick
}

internal let timerDemoReducer = Reducer<TimerState, TimerAction, Void> { state, action, _ in
    switch action {
    case .onDidLoad:
        return Effect<Int>.timer(id: "0", every: .seconds(1), on: MainScheduler.instance)
            .map { _ in
                print(">> Timer tick")
                return TimerAction.onTimerTick
            }
        
    case .onTimerTick:
        state.tickCount += 1
        return .none
    }
}
