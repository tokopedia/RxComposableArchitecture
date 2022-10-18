//
//  Bootstrapping.swift
//  RxComposableArchitecture
//
//  Created by Wendy Liga on 25/06/21.
//

import Foundation

#if DEBUG
    ///     A Way to Mock/Inject custom behaviour to your TCA.
    ///     with `Bootstrap` you can inject your custom `Environment` to your page.
    ///     You can injected it like on your `Example`, or using `MainApp TCA Bootstrapping Tweak` options on
    ///     `Tweaks -> Others -> Bootstrapping`. (will explain later)
    ///
    ///     let's say, our page have this environment
    ///     ```swift
    ///     struct Environment {
    ///        var request: () -> Effect<Result<Response, NetworkError>>
    ///        ...
    ///        ...
    ///     }
    ///     ```
    ///
    ///     ## Injecting custom Environment
    ///
    ///     we want to inject custom behaviour like if request fail,
    ///     we will create the fail `Environment` case, and inject it.
    ///
    ///     ```swift
    ///     let requestFail = Environment {
    ///        request: {
    ///            return Effect(value: .failure(.serverError))
    ///        }
    ///     }
    ///     ```
    ///
    ///     once we have our Environment, we can inject it by
    ///     calling `mock(_:)` function on `Bootstrap`
    ///
    ///     ```swift
    ///     Bootstrap.mock(requestFail)
    ///     ```
    ///
    ///     you can expect your feature to have this custom behaviour right away,
    ///     you *do not* need to restart the simulator, or reinit your page.
    ///
    ///     ## Reset custom Environment
    ///
    ///     once you inject something, it will be there for the rest of app session(means untill app is killed).
    ///     maybe after testing and playing with custom behaviour, you want to go back to 'live' or production behaviour,
    ///     then you need to reset it by
    ///
    ///     ```swift
    ///     Bootstrap.clear(_YOUR_ENVIRONMENT_TYPE)
    ///     ```
    ///
    ///     so on our example
    ///     ```swift
    ///     Bootstrap.clear(Environment.self)
    ///     ```
    ///     it will clear the custom behaviour and you can expect it right away like when you custom it in the first place.
    ///
    ///     - Warning:
    ///     the way bootstrap works is each `Envrionment` type will become identifier. means you only can inject one at a time for spesific `Environment` type.

    public struct Bootstrap {
        /// Inject your custom `Environment`
        ///
        /// ## Example
        ///
        /// ```swift
        /// Bootstrap.mock(HomeEnvironment.self)
        /// ```
        /// - Parameter environment: `Environment` to be injected
        public static func mock<Environment>(environment: Environment) {
            guard type(of: environment) != Void.self else {
                assertionFailure(
                    "You made a mistake by passing Void as a param, you never need to mock the Void"
                )
                return
            }

            _bootstrappedEnvironments[String(reflecting: Environment.self)] = environment
        }

        /// Clear Previous custom injected `Environment`
        ///
        /// ## Example
        ///
        /// ```swift
        /// let requestFail = Environment {
        ///    request: {
        ///       return Effect(value: .failure(.serverError))
        ///    }
        /// }
        ///
        /// Bootstrap.mock(requestFail)
        /// ```
        ///
        /// - Parameter environment: `Environment` type
        public static func clear<Environment>(environment _: Environment.Type) {
            clear(String(reflecting: Environment.self))
        }

        /// fetch bootstrapped environment from given `Environment` type if exist
        /// - Parameter : `Environment` type
        /// - Returns: `Environment` from `_bootstrappedEnvironments` by given type
        internal static func get<Environment>(environment _: Environment.Type) -> Environment? {
            _bootstrappedEnvironments[String(reflecting: Environment.self)] as? Environment
        }

        /// clear from spesific id
        /// - Warning: this api only supposed to be used on `BootstrapPicker`
        /// - Parameter id: environment type in string
        internal static func clear(_ id: String) {
            _bootstrappedEnvironments.removeValue(forKey: id)
        }

        /// clear all bootstrapped environment
        /// - Warning: this api only supposed to be used on `BootstrapPicker`
        internal static func clearAll() {
            _bootstrappedEnvironments.removeAll()
        }

        /// get all Bootstrapped identifier
        /// - Warning: this api only supposed to be used on `BootstrapPicker`
        /// - Returns: all active indentifier
        internal static func getAllBootstrappedIdentifier() -> [String] {
            _bootstrappedEnvironments.map(\.key)
        }
    }

    internal var _bootstrappedEnvironments: [String: Any] = [:]
#endif
