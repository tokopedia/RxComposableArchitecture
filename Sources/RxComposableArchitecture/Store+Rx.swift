//
//  File.swift
//  
//
//  Created by Jefferson Setiawan on 14/08/24.
//

import Combine
import Foundation

extension Store {
    public var state: State {
        _state.value
    }
    
    public func subscribeNeverEqual<LocalState: Equatable>(
        _ toLocalState: @escaping (State) -> NeverEqual<LocalState>
    ) -> Effect<LocalState> {
        _state.map(toLocalState).removeDuplicates()
            .map(\.wrappedValue)
            .eraseToEffect()
    }
    
    public func subscribe<LocalState>(
        _ toLocalState: @escaping (State) -> LocalState,
        removeDuplicates isDuplicate: @escaping (LocalState, LocalState) -> Bool
    ) -> Effect<LocalState> {
        return _state.map(toLocalState).removeDuplicates(by: isDuplicate).eraseToEffect()
    }
    
    public func subscribe<LocalState: Equatable>(
        _ toLocalState: @escaping (State) -> LocalState
    ) -> Effect<LocalState> {
        return _state.map(toLocalState).removeDuplicates().eraseToEffect()
    }
}

extension Store where State: Equatable {
    public func subscribe() -> Effect<State> {
        return _state.removeDuplicates().eraseToEffect()
    }
}

extension Store where State: Collection, State.Element: Identifiable, State: Equatable, State.Element: Equatable {
    /**
     A version of scope that scope an collection of sub store.

     This is kinda a version of `ForEachStoreNode`, not composing `WithViewStore` but creates the sub store.

     ## Example
     ```
     struct AppState { var todos: [Todo] }
     struct AppAction { case todo(index: Int, action: TodoAction }

     store.subscribe(\.todos)
        .drive(onNext: { todos in
            self.todoNodes = zip(todos.indices, todos).map { (offset, _) in
                TodoNode(with: store.scope(
                    identifier: identifier,
                    action: Action.todo(index:action:)
                )
            }
        })
        .disposed(by: disposeBag)
     ```

     But with example above, you created the entire node again and again and it's not the efficient way.
     You can do some diffing and only creating spesific index, and rest is handle by diffing.

     - Parameters:
        - identifier: the identifier from `IdentifierType` make sure index is in bounds of the collection
        - action: A function to transform `LocalAction` to `Action`. `LocalAction` should have `(CollectionIndex, LocalAction)` signature.

     - Returns: A new store with its domain (state and domain) transformed based on the index you set
     */
    public func scope<LocalAction>(
        at identifier: State.Element.ID,
        action fromLocalAction: @escaping (LocalAction) -> Action
    ) -> Store<State.Element, LocalAction>? {
        let toLocalState: (State.Element.ID, State) -> State.Element? = { identifier, state in
            /**
             if current state is IdentifiedArray, use pre exist subscript by identifier, to improve performance
             */
            if let identifiedArray = state as? IdentifiedArrayOf<State.Element> {
                return identifiedArray[id: identifier]
            } else {
                return state.first(where: { $0.id == identifier })
            }
        }
        if useNewScope {
            var isSending = false
            // skip if element on parent state wasn't found
            guard let element = toLocalState(identifier, state) else { return nil }
            let localStore = Store<State.Element, LocalAction>(
                initialState: element,
                reducer: AnyReducer { localState, localAction, _ in
                    isSending = true
                    defer { isSending = false }
                    self.send(fromLocalAction(localAction))
                    guard let finalState = toLocalState(identifier, self.state) else {
                        return .none
                    }
                    localState = finalState
                    return .none
                },
                environment: (),
                useNewScope: useNewScope
            )
            
            localStore.scopeCollectionCancellable = _state
                .dropFirst()
                .sink(receiveValue: { [weak localStore] newValue in
                    guard !isSending else { return }
                    guard let element = toLocalState(identifier, newValue) else { return }
                    localStore?._state.send(element)
                })
            return localStore
        } else {
            // skip if element on parent state wasn't found
            guard let element = toLocalState(identifier, state) else { return nil }

            let localStore = Store<State.Element, LocalAction>(
                initialState: element,
                reducer: AnyReducer { localState, localAction, _ in
                    self.send(fromLocalAction(localAction))
                    guard let finalState = toLocalState(identifier, self.state) else {
                        return .none
                    }

                    localState = finalState
                    return .none
                },
                environment: (),
                useNewScope: useNewScope
            )
            localStore.scopeCollectionCancellable = _state
                .removeDuplicates()
                .flatMap {
                    return toLocalState(identifier, $0)
                        .map(Just.init)?.eraseToAnyPublisher() ?? Empty(completeImmediately: true).eraseToAnyPublisher()
                }
                .sink(receiveValue: { [weak localStore] newValue in
                    localStore?._state.send(newValue)
                })

            return localStore
        }
    }
}
