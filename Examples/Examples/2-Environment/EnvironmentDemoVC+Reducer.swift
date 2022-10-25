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

struct Environment: ReducerProtocol {
    struct State {
        var text: String = "First Load"
        var isLoading = false
        var alertMessage: String?
        var uuidString: String = "NONE"
        var currentDate: Date?
    }
    
    enum Action {
        case didLoad
        case receiveData(Result<Int, CustomError>)
        case refresh
        case getCurrentDate
        case generateUUID
        case dismissAlert
    }
    
    @Dependency(\.envVCEnvironment) var env
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .didLoad:
            state.isLoading = true
            return env.loadData()
                .map(Action.receiveData)
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
                    .map(Action.receiveData)
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
}

struct AnalyticsEvent: Equatable {
    var name: String
    var category: String
}

struct CustomError: Error, Equatable {
    var message: String
}

class AnalyticsManager {
    private init() {}
    static func track(_ event: AnalyticsEvent) {
        print(">> Tracked: \(event)")
    }
}

struct EnvironmentVCEnvironment {
    var loadData: () -> Effect<Result<Int, CustomError>>
    var trackEvent: (AnalyticsEvent) -> Void
    var date: () -> Date
    var uuid: () -> UUID
}

private enum EnvironmentVCKey: DependencyKey {
    static var liveValue: EnvironmentVCEnvironment {
        EnvironmentVCEnvironment(
            loadData: {
                Observable.just(Result.success(Int.random(in: 0 ... 10000)))
                    .delay(.milliseconds(500), scheduler: MainScheduler.instance)
                    .eraseToEffect()
            },
            trackEvent: AnalyticsManager.track(_:),
            date: Date.init,
            uuid: UUID.init
        )
    }
}

extension DependencyValues {
    var envVCEnvironment: EnvironmentVCEnvironment {
        get { self[EnvironmentVCKey.self] }
        set { self[EnvironmentVCKey.self] = newValue }
    }
}
