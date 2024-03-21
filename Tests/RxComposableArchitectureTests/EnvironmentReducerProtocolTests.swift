//
//  EnvironmentReducerProtocolTests.swift
//  
//
//  Created by andhika.setiadi on 17/08/23.
//

import XCTest
@testable import RxComposableArchitecture
@testable import XCTestDynamicOverlay

internal final class EnvironmentReducerProtocolTests: XCTestCase {
    
    internal func testEnvironmentReducerProtocol_getSuccess() {
        struct Authenticator: ReducerProtocol {
            typealias State = String
            typealias Action = Void
            
            internal var authenticatorService: AuthenticatorService
            
            func reduce(into state: inout String, action: Void) -> Effect<Void> {
                switch authenticatorService.getAuthResult() {
                case let .success(successMessage):
                    state = successMessage
                case let .failure(failureData):
                    state = failureData.message
                }
                return .none
            }
        }
        
        let testStore = TestStore(
            initialState: "",
            environment: AuthenticatorService.mock,
            reducer: Authenticator.init(authenticatorService:)
        )
        
        testStore.environment.getAuthResult = {
            .success("success")
        }
        
        testStore.send(()) {
            $0 = "success"
        }
        
        testStore.environment.getAuthResult = {
            .failure(Failure(message: "Failed"))
        }
        
        testStore.send(()) {
            $0 = "Failed"
        }
    }
}

private struct Failure: Error {
    let message: String
}

private struct AuthenticatorService {
    var getAuthResult: () -> Result<String, Failure>
    
    static var mock: AuthenticatorService {
        return AuthenticatorService(
            getAuthResult: unimplemented(
                "Unimplemented getAuthResult",
                placeholder: .failure(
                    Failure(message: "Need Mock")
                )
            )
        )
    }
}
