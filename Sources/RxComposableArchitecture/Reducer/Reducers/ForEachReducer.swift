extension ReducerProtocol {
  /// Embeds a child reducer in a parent domain that works on elements of a collection in parent
  /// state.
  ///
  /// - Parameters:
  ///   - toElementsState: A writable key path from parent state to an `IdentifiedArray` of child
  ///     state.
  ///   - toElementAction: A case path from parent action to child identifier and child actions.
  ///   - element: A reducer that will be invoked with child actions against elements of child
  ///     state.
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @inlinable
  public func forEach<ID: Hashable, Element: ReducerProtocol>(
    _ toElementsState: WritableKeyPath<State, IdentifiedArray<ID, Element.State>>,
    action toElementAction: CasePath<Action, (ID, Element.Action)>,
    @ReducerBuilderOf<Element> _ element: () -> Element,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _ForEachReducer<Self, ID, Element> {
    _ForEachReducer(
      parent: self,
      toElementsState: toElementsState,
      toElementAction: toElementAction,
      element: element(),
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct _ForEachReducer<
  Parent: ReducerProtocol, ID: Hashable, Element: ReducerProtocol
>: ReducerProtocol {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toElementsState: WritableKeyPath<Parent.State, IdentifiedArray<ID, Element.State>>

  @usableFromInline
  let toElementAction: CasePath<Parent.Action, (ID, Element.Action)>

  @usableFromInline
  let element: Element

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @inlinable
  init(
    parent: Parent,
    toElementsState: WritableKeyPath<Parent.State, IdentifiedArray<ID, Element.State>>,
    toElementAction: CasePath<Parent.Action, (ID, Element.Action)>,
    element: Element,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.toElementsState = toElementsState
    self.toElementAction = toElementAction
    self.element = element
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action> {
    return .merge(
      self.reduceForEach(into: &state, action: action),
      self.parent.reduce(into: &state, action: action)
    )
  }

  @inlinable
  func reduceForEach(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action> {
    guard let (id, elementAction) = self.toElementAction.extract(from: action) else { return .none }
    if state[keyPath: self.toElementsState][id: id] == nil {
      runtimeWarning(
        """
        A "forEach" at "%@:%d" received an action for a missing element.

          Action:
            %@

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer removed an element with this ID before this reducer ran. This reducer \
        must run before any other reducer removes an element, which ensures that element reducers \
        can handle their actions while their state is still available.

        • An in-flight effect emitted this action when state contained no element at this ID. \
        While it may be perfectly reasonable to ignore this action, consider canceling the \
        associated effect before an element is removed, especially if it is a long-living effect.

        • This action was sent to the store while its state contained no element at this ID. To \
        fix this make sure that actions for this reducer can only be sent from a view store when \
        its state contains an element at this id. In SwiftUI applications, use "ForEachStore".
        """,
        [
          "\(self.fileID)",
          line,
          debugCaseOutput(action),
        ],
        file: self.file,
        line: self.line
      )
      return .none
    }
    return self.element
      .reduce(into: &state[keyPath: self.toElementsState][id: id]!, action: elementAction)
      .map { self.toElementAction.embed((id, $0)) }
  }
}
