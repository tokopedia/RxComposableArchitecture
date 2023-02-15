//
//  EnvironmentReducerTests.swift
//  ExamplesTests
//
//  Created by jefferson.setiawan on 03/06/22.
//

import XCTest
import RxComposableArchitecture
import RxSwift
import XCTestDynamicOverlay

@testable import Examples

final class EnvironmentReducerTests: XCTestCase {
    private var trackEventSink = [AnalyticsEvent]()
    private lazy var trackEventHandler: (AnalyticsEvent) -> Void = {
        self.trackEventSink.append($0)
    }

    override func setUp() {
        super.setUp()
        trackEventSink.removeAll()
    }

    func testSuccessLoadData() {
        let store = TestStore2(
            initialState: Environment.State(),
            reducer: Environment()
        )
        store.dependencies.envVCEnvironment.loadData = { Observable.just(.success(2)).eraseToEffect() }

        store.send(.didLoad) {
            $0.isLoading = true
        }
        store.receive(.receiveData(.success(2))) {
            $0.isLoading = false
            $0.text = "Data from environment: 2"
        }
    }

    func testFailedLoadData() {
        let store = TestStore2(
            initialState: Environment.State(),
            reducer: Environment()
        )
        store.dependencies.envVCEnvironment.loadData = { Effect(value: .failure(CustomError(message: "ERROR!"))) }
        
        store.send(.didLoad) {
            $0.isLoading = true
        }
        store.receive(.receiveData(.failure(CustomError(message: "ERROR!")))) {
            $0.isLoading = false
            $0.alertMessage = "ERROR!"
        }
        store.send(.dismissAlert) {
            $0.alertMessage = nil
        }
    }

    func testRefresh() {
        let store = TestStore2(
            initialState: Environment.State(),
            reducer: Environment()
        )
        store.dependencies.envVCEnvironment.loadData = { Effect(value: .success(2)) }
        store.dependencies.envVCEnvironment.trackEvent = trackEventHandler
        store.send(.refresh) {
            $0.isLoading = true
        }
        store.receive(.receiveData(.success(2))) {
            $0.isLoading = false
            $0.text = "Data from environment: 2"
        }

        /// How you modify the environment value
        store.dependencies.envVCEnvironment.loadData = {
            Effect(value: .success(5))
        }
        store.send(.refresh) {
            $0.isLoading = true
        }
        store.receive(.receiveData(.success(5))) {
            $0.isLoading = false
            $0.text = "Data from environment: 5"
        }
        XCTAssertEqual(trackEventSink,
                       [
                           AnalyticsEvent(name: "refresh", category: "DUMMY"),
                           AnalyticsEvent(name: "refresh", category: "DUMMY")
                       ])
    }

    func testGetCurrentDate() {
        let store = TestStore2(
            initialState: Environment.State(),
            reducer: Environment()
        )
        store.dependencies.envVCEnvironment.date = { Date(timeIntervalSince1970: 1_597_300_000) }
        store.dependencies.envVCEnvironment.trackEvent = trackEventHandler
        store.send(.getCurrentDate) {
            $0.currentDate = Date(timeIntervalSince1970: 1_597_300_000)
        }
        XCTAssertEqual(trackEventSink, [AnalyticsEvent(name: "getCurrentDate", category: "DUMMY")])
    }

    func testGenerateUUID() {
        let store = TestStore2(
            initialState: Environment.State(),
            reducer: Environment()
        )
        
        store.dependencies.envVCEnvironment.uuid = UUID.incrementing
        store.dependencies.envVCEnvironment.trackEvent = trackEventHandler
        store.send(.generateUUID) {
            $0.uuidString = "00000000-0000-0000-0000-000000000000"
        }
        store.send(.generateUUID) {
            $0.uuidString = "00000000-0000-0000-0000-000000000001"
        }
        XCTAssertEqual(trackEventSink,
                       [
                           AnalyticsEvent(name: "generateUUID", category: "DUMMY"),
                           AnalyticsEvent(name: "generateUUID", category: "DUMMY")
                       ])
    }
}
