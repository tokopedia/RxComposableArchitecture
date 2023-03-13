//
//  EnvironmentDependencyCompatibilityTests.swift
//  ExamplesTests
//
//  Created by daniel.istyana on 12/03/23.
//

import XCTest
import RxComposableArchitecture

@testable import Examples

final class EnvironmentDependencyCompatibilityTests: XCTestCase {
    let testStore = TestStore(
        initialState: Environment.State(),
        reducer: Environment()
    )
    
    ///Given: Store with live implementation
    ///When: I override dependency using bootstrap
    ///Then: Should use bootstrap override
    internal func testOverrideDependencyUsingBootstrap() {
        Bootstrap.mock(environment: EnvironmentVCEnvironment.mockBootstrap)
        defer { Bootstrap.clear(environment: EnvironmentVCEnvironment.self) }
        
        testStore.send(.didLoad) {
            $0.isLoading = true
        }
        testStore.receive(.receiveData(.success(696969))) {
            $0.isLoading = false
            $0.text = "Data from environment: 696969"
        }
    }
    
    ///Given: already override dependency using bootstrap
    ///When: I override dependency using .dependency
    ///Then: Should use bootstrap override
    internal func testOverrideBootstrapUsingDependency() {
        Bootstrap.mock(environment: EnvironmentVCEnvironment.mockBootstrap)
        defer { Bootstrap.clear(environment: EnvironmentVCEnvironment.self) }
        
        testStore.dependencies.envVCEnvironment = .mockFailed
        
        testStore.send(.didLoad) {
            $0.isLoading = true
        }
        testStore.receive(.receiveData(.success(696969))) {
            $0.isLoading = false
            $0.text = "Data from environment: 696969"
        }
    }
    
    ///Given: I already override dependency using bootstrap
    ///When: I open the another feature instance and not override using bootstrap
    ///Then: Should use dependency based on contex
    internal func testCheckMultiplePagesWithOneOfThemUsingBootstrap() {
        testStore.dependencies.envVCEnvironment = .mockDependencySuccess
        
        testStore.send(.didLoad) {
            $0.isLoading = true
        }
        
        testStore.receive(.receiveData(.success(420420))) {
            $0.isLoading = false
            $0.text = "Data from environment: 420420"
        }
        
        // open new page
        let testStore2 = TestStore(
            initialState: Environment.State(),
            reducer: Environment()
        )
        
        Bootstrap.mock(environment: EnvironmentVCEnvironment.mockBootstrap)
        
        testStore2.send(.didLoad) {
            $0.isLoading = true
        }
        
        testStore2.receive(.receiveData(.success(696969))) {
            $0.isLoading = false
            $0.text = "Data from environment: 696969"
        }
        
        testStore.send(.didLoad) {
            $0.isLoading = true
        }
        
        testStore.send(.receiveData(.success(420420))) {
            $0.isLoading = false
            $0.text = "Data from environment: 420420"
        }
    }
}

extension EnvironmentVCEnvironment {
    internal static let mockBootstrap = Self(
        loadData: { .just(.success(696969)).eraseToEffect() },
        trackEvent: { _ in },
        date: { Date() },
        uuid: { UUID(uuidString: "deadbeef")! }
    )
    
    internal static let mockDependencySuccess = Self(
        loadData: { .just(.success(420420)).eraseToEffect() },
        trackEvent: { _ in },
        date: { Date() },
        uuid: { UUID(uuidString: "deadbeef")! }
    )
}
