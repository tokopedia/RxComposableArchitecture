//
//  EnvironmentDemoVC+Reducer.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import CasePaths
import Foundation
import RxComposableArchitecture
import RxSwift

struct CustomError: Error, Equatable {
    var message: String
}

struct EnvironmentState: Equatable {
    var text: String = "First Load"
    var isLoading = false
    var alertMessage: String?
    var uuidString: String = "NONE"
    var currentDate: Date?
}

enum EnvironmentAction: Equatable {
    case didLoad
    case receiveData(Result<Int, CustomError>)
    case refresh
    case getCurrentDate
    case generateUUID
    case dismissAlert
}

struct AnalyticsEvent: Equatable {
    var name: String
    var category: String
}

class AnalyticManager {
    private init() {}
    static func track(_ event: AnalyticsEvent) {
        print("<<< Track event of \(event)")
    }
}

struct EnvironmentVCEnvironment {
    var loadData: () -> Effect<Result<Int, CustomError>>
    var trackEvent: (AnalyticsEvent) -> Void
    var date: () -> Date
    var uuid: () -> UUID
}

let environmentReducer: Reducer<EnvironmentState, EnvironmentAction, EnvironmentVCEnvironment> = {
    Reducer<EnvironmentState, EnvironmentAction, EnvironmentVCEnvironment> { state, action, env in
        switch action {
        case .didLoad:
            state.isLoading = true
            return env.loadData()
                .map(EnvironmentAction.receiveData)
        case let .receiveData(response):
            state.isLoading = false
            switch response {
            case let .success(number):
                state.text = "Data from environment: \(number)"
            case let .failure(error):
                state.alertMessage = error.message
            }

            return .none
        case .refresh:
            state.isLoading = true
            return .merge(
                env.loadData()
                    .map(EnvironmentAction.receiveData)
                    .eraseToEffect(),
                .fireAndForget {
                    env.trackEvent(AnalyticsEvent(name: "refresh", category: "DUMMY"))
                }
            )
        case .getCurrentDate:
            state.currentDate = env.date()
            return .fireAndForget {
                env.trackEvent(AnalyticsEvent(name: "getCurrentDate", category: "DUMMY"))
            }
        case .generateUUID:
            state.uuidString = env.uuid().uuidString
            return .fireAndForget {
                env.trackEvent(AnalyticsEvent(name: "generateUUID", category: "DUMMY"))
            }
        case .dismissAlert:
            state.alertMessage = nil
            return .none
        }
    }
}()
