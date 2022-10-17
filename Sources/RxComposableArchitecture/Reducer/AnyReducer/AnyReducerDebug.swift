import CasePaths
import Dispatch

@available(iOS, deprecated: 9999.0, message: "Use a 'ReducerProtocol' conformance, instead.")
@available(macOS, deprecated: 9999.0, message: "Use a 'ReducerProtocol' conformance, instead.")
@available(tvOS, deprecated: 9999.0, message: "Use a 'ReducerProtocol' conformance, instead.")
@available(watchOS, deprecated: 9999.0, message: "Use a 'ReducerProtocol' conformance, instead.")
extension AnyReducer {
  /// Prints debug messages describing all received actions and state mutations.
  ///
  /// Printing is only done in debug (`#if DEBUG`) builds.
  ///
  /// - Parameters:
  ///   - prefix: A string with which to prefix all debug messages.
  ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
  ///     describing a print function and a queue to print from. Defaults to a function that ignores
  ///     the environment and returns a default ``DebugEnvironment`` that uses Swift's `print`
  ///     function and a background queue.
  /// - Returns: A reducer that prints debug messages for all received actions.
  public func debug(
    _ prefix: String = "",
    actionFormat: ActionFormat = .prettyPrint,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Self {
    self.debug(
      prefix,
      state: { $0 },
      action: .self,
      actionFormat: actionFormat,
      environment: toDebugEnvironment
    )
  }

  /// Prints debug messages describing all received actions.
  ///
  /// Printing is only done in debug (`#if DEBUG`) builds.
  ///
  /// - Parameters:
  ///   - prefix: A string with which to prefix all debug messages.
  ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
  ///     describing a print function and a queue to print from. Defaults to a function that ignores
  ///     the environment and returns a default ``DebugEnvironment`` that uses Swift's `print`
  ///     function and a background queue.
  /// - Returns: A reducer that prints debug messages for all received actions.
  public func debugActions(
    _ prefix: String = "",
    actionFormat: ActionFormat = .prettyPrint,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Self {
    self.debug(
      prefix,
      state: { _ in () },
      action: .self,
      actionFormat: actionFormat,
      environment: toDebugEnvironment
    )
  }

  /// Prints debug messages describing all received actions and state mutations.
  ///
  /// Printing is only done in debug (`#if DEBUG`) builds.
  ///
  /// - Parameters:
  ///   - prefix: A string with which to prefix all debug messages.
  ///   - toDebugState: A function that filters state to be printed.
  ///   - toDebugAction: A case path that filters actions that are printed.
  ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
  ///     describing a print function and a queue to print from. Defaults to a function that ignores
  ///     the environment and returns a default ``DebugEnvironment`` that uses Swift's `print`
  ///     function and a background queue.
  /// - Returns: A reducer that prints debug messages for all received actions.
  public func debug<DebugState, DebugAction>(
    _ prefix: String = "",
    state toDebugState: @escaping (State) -> DebugState,
    action toDebugAction: CasePath<Action, DebugAction>,
    actionFormat: ActionFormat = .prettyPrint,
    environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
      DebugEnvironment()
    }
  ) -> Self {
    #if DEBUG
      return .init { state, action, environment in
        let previousState = toDebugState(state)
        let effects = self.run(&state, action, environment)
        guard let debugAction = toDebugAction.extract(from: action) else { return effects }
        let nextState = toDebugState(state)
        let debugEnvironment = toDebugEnvironment(environment)
        return .merge(
          .fireAndForget {
            debugEnvironment.queue.async {
              var actionOutput = ""
              if actionFormat == .prettyPrint {
                customDump(debugAction, to: &actionOutput, indent: 2)
              } else {
                actionOutput.write(debugCaseOutput(debugAction).indent(by: 2))
              }
              let stateOutput =
                DebugState.self == Void.self
                ? ""
                : diff(previousState, nextState).map { "\($0)\n" } ?? "  (No state changes)\n"
              debugEnvironment.printer(
                """
                \(prefix.isEmpty ? "" : "\(prefix): ")received action:
                \(actionOutput)
                \(stateOutput)
                """
              )
            }
          },
          effects
        )
      }
    #else
      return self
    #endif
  }
}

public enum ActionFormat: Sendable {
  /// Prints the action in a single line by only specifying the labels of the associated values:
  ///
  /// ```swift
  /// Action.screenA(.row(index:, action: .textChanged(query:)))
  /// ```
  case labelsOnly

  /// Prints the action in a multiline, pretty-printed format, including all the labels of
  /// any associated values, as well as the data held in the associated values:
  ///
  /// ```swift
  /// Action.screenA(
  ///   ScreenA.row(
  ///     index: 1,
  ///     action: RowAction.textChanged(
  ///       query: "Hi"
  ///     )
  ///   )
  /// )
  /// ```
  case prettyPrint
}

/// An environment for debug-printing reducers.
@available(
  iOS,
  deprecated: 9999.0,
  message: "Call 'debug()' on a 'ReducerProtocol' conformance, instead."
)
@available(
  macOS,
  deprecated: 9999.0,
  message: "Call 'debug()' on a 'ReducerProtocol' conformance, instead."
)
@available(
  tvOS,
  deprecated: 9999.0,
  message: "Call 'debug()' on a 'ReducerProtocol' conformance, instead."
)
@available(
  watchOS,
  deprecated: 9999.0,
  message: "Call 'debug()' on a 'ReducerProtocol' conformance, instead."
)
/// An environment for debug-printing reducers.
public struct DebugEnvironment {
    public var printer: (String) -> Void
    public var queue: DispatchQueue

    public init(
        printer: @escaping (String) -> Void = { print($0) },
        queue: DispatchQueue
    ) {
        self.printer = printer
        self.queue = queue
    }

    public init(
        printer: @escaping (String) -> Void = { print($0) }
    ) {
        self.init(printer: printer, queue: _queue)
    }
}

private let _queue = DispatchQueue(
    label: "com.tokopedia.Tokopedia.DebugEnvironment",
    qos: .default
)

