//
//  EnvironmentVC+Mock.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import Foundation
import RxSwift

extension EnvironmentVCEnvironment {
    internal static let live = Self(
        loadData: {
            Observable.just(Result.success(Int.random(in: 0 ... 10000)))
                .delay(.milliseconds(500), scheduler: MainScheduler.instance)
                .eraseToEffect()
        },
        trackEvent: AnalyticsManager.track,
        date: Date.init,
        uuid: UUID.init
    )

    internal static let mockSuccess = Self(
        loadData: {
            Observable.just(Result.success(Int.random(in: 0 ... 10000)))
                .delay(.milliseconds(500), scheduler: MainScheduler.instance)
                .eraseToEffect()
        },
        trackEvent: {
            print("MOCKING \($0)")
        },
        date: {
            /// always return 13 Aug 2020, 13:26:40
            Date(timeIntervalSince1970: 1_597_300_000)
        },
        uuid: UUID.incrementing
    )
    internal static let mockFailed = Self(
        loadData: {
            Observable.just(Result.failure(CustomError(message: "Server Error code: \(Int.random(in: 0 ... 500))")))
                .delay(.milliseconds(500), scheduler: MainScheduler.instance)
                .eraseToEffect()
        },
        trackEvent: {
            print("MOCKING \($0)")
        },
        date: {
            /// always return 13 Aug 2020, 13:26:40
            Date(timeIntervalSince1970: 1_597_300_000)
        },
        uuid: UUID.incrementing
    )

    internal static let mockRandom = Self(
        loadData: {
            if Bool.random() {
                return Observable.just(Result<Int, CustomError>.success(Int.random(in: 0 ... 10000)))
                    .delay(.milliseconds(500), scheduler: MainScheduler.instance)
                    .eraseToEffect()
            } else {
                return Observable.just(Result<Int, CustomError>.failure(CustomError(message: "Server Error")))
                    .delay(.milliseconds(500), scheduler: MainScheduler.instance)
                    .eraseToEffect()
            }
        },
        trackEvent: {
            print("MOCKING \($0)")
        },
        date: {
            /// always return 13 Aug 2020, 13:26:40
            Date(timeIntervalSince1970: 1_597_300_000)
        },
        uuid: UUID.incrementing
    )
}
