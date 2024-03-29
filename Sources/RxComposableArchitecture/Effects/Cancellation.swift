import Foundation
import RxSwift

extension Effect {
    /// Turns an effect into one that is capable of being canceled.
    ///
    /// To turn an effect into a cancellable one you must provide an identifier, which is used in
    /// ``Effect/cancel(id:)-70e00`` to identify which in-flight effect should be canceled.
    /// Any hashable value can be used for the identifier, such as a string, but you can add a bit of
    /// protection against typos by defining a new type for the identifier:
    ///
    /// ```swift
    /// struct LoadUserID {}
    ///
    /// case .reloadButtonTapped:
    ///   // Start a new effect to load the user
    ///   return self.apiClient.loadUser()
    ///     .map(Action.userResponse)
    ///     .cancellable(id: LoadUserID.self, cancelInFlight: true)
    ///
    /// case .cancelButtonTapped:
    ///   // Cancel any in-flight requests to load the user
    ///   return .cancel(id: LoadUserID.self)
    /// ```
    ///
    /// - Parameters:
    ///   - id: The effect's identifier.
    ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
    ///     canceled before starting this new one.
    /// - Returns: A new effect that is capable of being canceled by an identifier.
    public func cancellable(id: AnyHashable, cancelInFlight: Bool = false) -> Effect {
        switch self.operation {
        case .none:
            return .none
        case let .observable(observable):
            return Self(
                operation: .observable(
                    Observable.deferred {
                        _cancellablesLock.lock()
                        defer { _cancellablesLock.unlock() }
                        
                        let id = _CancelToken(id: id)
                        if cancelInFlight {
                            _cancellationCancellables[id]?.forEach { $0.dispose() }
                        }
                        
                        /// Flag is used to prevent disposable to send event on disposed `cancellationSubject`
                        /// Thanks: https://github.com/dannyhertz/rxswift-composable-architecture/issues/5
                        var hasCompleted = false
                        
                        let cancellationSubject = PublishSubject<Void>()
                        
                        var cancellationCancellable: AnyDisposable!
                        cancellationCancellable = AnyDisposable(
                            Disposables.create {
                                _cancellablesLock.sync {
                                    if !hasCompleted {
                                        cancellationSubject.onNext(())
                                        cancellationSubject.onCompleted()
                                    }
                                    _cancellationCancellables[id]?.remove(cancellationCancellable)
                                    if _cancellationCancellables[id]?.isEmpty == .some(true) {
                                        _cancellationCancellables[id] = nil
                                    }
                                }
                            }
                        )
                        
                        return observable.takeUntil(cancellationSubject)
                            .do(
                                onError: { _ in
                                    hasCompleted = true
                                    cancellationCancellable.dispose()
                                },
                                onSubscribed: {
                                    _ = _cancellablesLock.sync {
                                        _cancellationCancellables[id, default: []].insert(
                                            cancellationCancellable
                                        )
                                    }
                                },
                                onDispose: {
                                    hasCompleted = true
                                    cancellationCancellable.dispose()
                                }
                            )
                    }
                )
            )
            
        case let .run(priority, operation):
            return Self(
                operation: .run(priority, { send in
                    await withTaskCancellation(id: id, cancelInFlight: cancelInFlight, operation: {
                        await operation(send)
                    })
                })
            )
        }
    }
    
    /// Turns an effect into one that is capable of being canceled.
    ///
    /// A convenience for calling ``Effect/cancellable(id:cancelInFlight:)-17skv`` with a static type
    /// as the effect's unique identifier.
    ///
    /// - Parameters:
    ///   - id: A unique type identifying the effect.
    ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
    ///     canceled before starting this new one.
    /// - Returns: A new effect that is capable of being canceled by an identifier.
    public func cancellable(id: Any.Type, cancelInFlight: Bool = false) -> Self {
        self.cancellable(id: ObjectIdentifier(id), cancelInFlight: cancelInFlight)
    }
    
    /// An effect that will cancel any currently in-flight effect with the given identifier.
    ///
    /// - Parameter id: An effect identifier.
    /// - Returns: A new effect that will cancel any currently in-flight effect with the given
    ///   identifier.
    public static func cancel(id: AnyHashable) -> Self {
        .fireAndForget {
            _cancellablesLock.sync {
                _cancellationCancellables[_CancelToken(id: id)]?.forEach { $0.dispose() }
            }
        }
    }
    
    /// An effect that will cancel any currently in-flight effect with the given identifier.
    ///
    /// A convenience for calling ``Effect/cancel(id:)-iun1`` with a static type as the effect's
    /// unique identifier.
    ///
    /// - Parameter id: A unique type identifying the effect.
    /// - Returns: A new effect that will cancel any currently in-flight effect with the given
    ///   identifier.
    public static func cancel(id: Any.Type) -> Self {
        .cancel(id: ObjectIdentifier(id))
    }
    
    /// An effect that will cancel multiple currently in-flight effects with the given identifiers.
    ///
    /// - Parameter ids: An array of effect identifiers.
    /// - Returns: A new effect that will cancel any currently in-flight effects with the given
    ///   identifiers.
    public static func cancel(ids: [AnyHashable]) -> Self {
        .merge(ids.map(Effect.cancel(id:)))
    }
    
    /// An effect that will cancel multiple currently in-flight effects with the given identifiers.
    ///
    /// A convenience for calling ``Effect/cancel(ids:)-dmwy`` with a static type as the effect's
    /// unique identifier.
    ///
    /// - Parameter ids: An array of unique types identifying the effects.
    /// - Returns: A new effect that will cancel any currently in-flight effects with the given
    ///   identifiers.
    public static func cancel(ids: [Any.Type]) -> Self {
        .merge(ids.map(Effect.cancel(id:)))
    }
}


#if swift(>=5.7)
    /// Execute an operation with a cancellation identifier.
    ///
    /// If the operation is in-flight when `Task.cancel(id:)` is called with the same identifier, the
    /// operation will be cancelled.
    ///
    /// ```
    /// enum CancelID.self {}
    ///
    /// await withTaskCancellation(id: CancelID.self) {
    ///   // ...
    /// }
    /// ```
    ///
    /// ### Debouncing tasks
    ///
    /// When paired with a clock, this function can be used to debounce a unit of async work by
    /// specifying the `cancelInFlight`, which will automatically cancel any in-flight work with the
    /// same identifier:
    ///
    /// ```swift
    /// @Dependency(\.continuousClock) var clock
    /// enum CancelID {}
    ///
    /// // ...
    ///
    /// return .task {
    ///   await withTaskCancellation(id: CancelID.self, cancelInFlight: true) {
    ///     try await self.clock.sleep(for: .seconds(0.3))
    ///     return await .debouncedResponse(
    ///       TaskResult { try await environment.request() }
    ///     )
    ///   }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the operation.
    ///   - cancelInFlight: Determines if any in-flight operation with the same identifier should be
    ///     canceled before starting this new one.
    ///   - operation: An async operation.
    /// - Throws: An error thrown by the operation.
    /// - Returns: A value produced by operation.
    @_unsafeInheritExecutor
    public func withTaskCancellation<T: Sendable>(
        id: AnyHashable,
        cancelInFlight: Bool = false,
        operation: @Sendable @escaping () async throws -> T
    ) async rethrows -> T {
        let id = _CancelToken(id: id)
        let (cancellable, task) = _cancellablesLock.sync { () -> (AnyDisposable, Task<T, Error>) in
            if cancelInFlight {
                _cancellationCancellables[id]?.forEach { $0.dispose() }
            }
            let task = Task { try await operation() }
            let cancellable = AnyDisposable { task.cancel() }
            _cancellationCancellables[id, default: []].insert(cancellable)
            return (cancellable, task)
        }
        defer {
            _cancellablesLock.sync {
                _cancellationCancellables[id]?.remove(cancellable)
                if _cancellationCancellables[id]?.isEmpty == .some(true) {
                    _cancellationCancellables[id] = nil
                }
            }
        }
        do {
            return try await task.cancellableValue
        } catch {
            return try Result<T, Error>.failure(error)._rethrowGet()
        }
    }
#else
    public func withTaskCancellation<T: Sendable>(
        id: AnyHashable,
        cancelInFlight: Bool = false,
        operation: @Sendable @escaping () async throws -> T
    ) async rethrows -> T {
        let id = _CancelToken(id: id)
        let (cancellable, task) = _cancellablesLock.sync { () -> (AnyDisposable, Task<T, Error>) in
            if cancelInFlight {
                _cancellationCancellables[id]?.forEach { $0.dispose() }
            }
            let task = Task { try await operation() }
            let cancellable = AnyDisposable { task.cancel() }
            _cancellationCancellables[id, default: []].insert(cancellable)
            return (cancellable, task)
        }
        defer {
            _cancellablesLock.sync {
                _cancellationCancellables[id]?.remove(cancellable)
                if _cancellationCancellables[id]?.isEmpty == .some(true) {
                    _cancellationCancellables[id] = nil
                }
            }
        }
        do {
            return try await task.cancellableValue
        } catch {
            return try Result<T, Error>.failure(error)._rethrowGet()
        }
    }
#endif

#if swift(>=5.7)
  /// Execute an operation with a cancellation identifier.
  ///
  /// A convenience for calling ``withTaskCancellation(id:cancelInFlight:operation:)-4dtr6`` with a
  /// static type as the operation's unique identifier.
  ///
  /// - Parameters:
  ///   - id: A unique type identifying the operation.
  ///   - cancelInFlight: Determines if any in-flight operation with the same identifier should be
  ///     canceled before starting this new one.
  ///   - operation: An async operation.
  /// - Throws: An error thrown by the operation.
  /// - Returns: A value produced by operation.
  @_unsafeInheritExecutor
  public func withTaskCancellation<T: Sendable>(
    id: Any.Type,
    cancelInFlight: Bool = false,
    operation: @Sendable @escaping () async throws -> T
  ) async rethrows -> T {
    try await withTaskCancellation(
      id: ObjectIdentifier(id),
      cancelInFlight: cancelInFlight,
      operation: operation
    )
  }
#else
  public func withTaskCancellation<T: Sendable>(
    id: Any.Type,
    cancelInFlight: Bool = false,
    operation: @Sendable @escaping () async throws -> T
  ) async rethrows -> T {
    try await withTaskCancellation(
      id: ObjectIdentifier(id),
      cancelInFlight: cancelInFlight,
      operation: operation
    )
  }
#endif

extension Task where Success == Never, Failure == Never {
    /// Cancel any currently in-flight operation with the given identifier.
    ///
    /// - Parameter id: An identifier.
    public static func cancel<ID: Hashable & Sendable>(id: ID) {
        _cancellablesLock.sync { _cancellationCancellables[_CancelToken(id: id)]?.forEach { $0.dispose() } }
    }
    
    /// Cancel any currently in-flight operation with the given identifier.
    ///
    /// A convenience for calling `Task.cancel(id:)` with a static type as the operation's unique
    /// identifier.
    ///
    /// - Parameter id: A unique type identifying the operation.
    public static func cancel(id: Any.Type) {
        self.cancel(id: ObjectIdentifier(id))
    }
}

@_spi(Internals) public struct _CancelToken: Hashable {
    let id: AnyHashable
    let discriminator: ObjectIdentifier
    
    public init(id: AnyHashable) {
        self.id = id
        self.discriminator = ObjectIdentifier(type(of: id.base))
    }
}

@_spi(Internals) public var _cancellationCancellables: [_CancelToken: Set<AnyDisposable>] = [:]
@_spi(Internals) public let _cancellablesLock = NSRecursiveLock()

@rethrows
private protocol _ErrorMechanism {
    associatedtype Output
    func get() throws -> Output
}

extension _ErrorMechanism {
    func _rethrowError() rethrows -> Never {
        _ = try _rethrowGet()
        fatalError()
    }
    
    func _rethrowGet() rethrows -> Output {
        return try get()
    }
}

extension Result: _ErrorMechanism {}
