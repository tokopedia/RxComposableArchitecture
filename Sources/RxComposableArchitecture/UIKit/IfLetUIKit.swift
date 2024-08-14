import Combine

extension Store {
  /// Calls one of two closures depending on whether a store's optional state is `nil` or not, and
  /// whenever this condition changes for as long as the cancellable lives.
  ///
  /// If the store's state is non-`nil`, it will safely unwrap the value and bundle it into a new
  /// store of non-optional state that is passed to the first closure. If the store's state is
  /// `nil`, the second closure is called instead.
  ///
  /// This method is useful for handling navigation in UIKit. The state for a screen the user wants
  /// to navigate to can be held as an optional value in the parent, and when that value goes from
  /// `nil` to non-`nil`, or non-`nil` to `nil`, you can update the navigation stack accordingly:
  ///
  /// ```swift
  /// class ParentViewController: UIViewController {
  ///   let store: Store<ParentState, ParentAction>
  ///   var cancellables: Set<AnyCancellable> = []
  ///   ...
  ///   func viewDidLoad() {
  ///     ...
  ///     self.store
  ///       .scope(state: \.optionalChild, action: ParentAction.child)
  ///       .ifLet(
  ///         then: { [weak self] childStore in
  ///           self?.navigationController?.pushViewController(
  ///             ChildViewController(store: childStore),
  ///             animated: true
  ///           )
  ///         },
  ///         else: { [weak self] in
  ///           guard let self = self else { return }
  ///           self.navigationController?.popToViewController(self, animated: true)
  ///         }
  ///       )
  ///       .store(in: &self.cancellables)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - unwrap: A function that is called with a store of non-optional state when the store's
  ///     state is non-`nil`, or whenever it goes from `nil` to non-`nil`.
  ///   - else: A function that is called when the store's optional state is `nil`, or whenever it
  ///     goes from non-`nil` to `nil`.
  /// - Returns: A cancellable that maintains a subscription to updates whenever the store's state
  ///   goes from `nil` to non-`nil` and vice versa, so that the caller can react to these changes.
  public func ifLet<Wrapped>(
    then unwrap: @escaping (Store<Wrapped, Action>) -> Void,
    else: @escaping () -> Void = {}
  ) -> Cancellable where State == Wrapped? {
    return self._state
      .removeDuplicates(by: { ($0 != nil) == ($1 != nil) })
      .sink { state in
        if var state = state {
          unwrap(
            self.scope {
              state = $0 ?? state
              return state
            }
          )
        } else {
          `else`()
        }
      }
  }
}

import RxSwift
extension Store {
    /// Subscribes to updates when a store containing optional state goes from `nil` to non-`nil` or
    /// non-`nil` to `nil`.
    ///
    /// This is useful for handling navigation in UIKit. The state for a screen that you want to
    /// navigate to can be held as an optional value in the parent, and when that value switches
    /// from `nil` to non-`nil` you want to trigger a navigation and hand the detail view a `Store`
    /// whose domain has been scoped to just that feature:
    ///
    ///     class MasterViewController: UIViewController {
    ///       let store: Store<MasterState, MasterAction>
    ///       var cancellables: Set<AnyCancellable> = []
    ///       ...
    ///       func viewDidLoad() {
    ///         ...
    ///         self.store
    ///           .scope(state: \.optionalDetail, action: MasterAction.detail)
    ///           .ifLet(
    ///             then: { [weak self] detailStore in
    ///               self?.navigationController?.pushViewController(
    ///                 DetailViewController(store: detailStore),
    ///                 animated: true
    ///               )
    ///             },
    ///             else: { [weak self] in
    ///               guard let self = self else { return }
    ///               self.navigationController?.popToViewController(self, animated: true)
    ///             }
    ///           )
    ///           .store(in: &self.cancellables)
    ///       }
    ///     }
    ///
    /// - Parameters:
    ///   - unwrap: A function that is called with a store of non-optional state whenever the store's
    ///     optional state goes from `nil` to non-`nil`.
    ///   - else: A function that is called whenever the store's optional state goes from non-`nil` to
    ///     `nil`.
    /// - Returns: A cancellable associated with the underlying subscription.
    public func ifLet<Wrapped>(
        then unwrap: @escaping (Store<Wrapped, Action>) -> Void,
        else: @escaping () -> Void
    ) -> Disposable where State == Wrapped? {
        self._state.asObservable()
            .distinctUntilChanged { ($0 != nil) == ($1 != nil) }
            .subscribe(onNext: { state in
                if var state = state {
                    unwrap(
                        self.scope {
                            state = $0 ?? state
                            return state
                        }
                    )
                } else {
                    `else`()
                }
            })
    }

    /// An overload of `ifLet(then:else:)` for the times that you do not want to handle the `else`
    /// case.
    ///
    /// - Parameter unwrap: A function that is called with a store of non-optional state whenever the
    ///   store's optional state goes from `nil` to non-`nil`.
    /// - Returns: A cancellable associated with the underlying subscription.
    public func ifLet<Wrapped>(
        then unwrap: @escaping (Store<Wrapped, Action>) -> Void
    ) -> Disposable where State == Wrapped? {
        ifLet(then: unwrap, else: {})
    }
}

