////
////  SingleSelection.swift
////  RxComposableArchitecture
////
////  Created by Wendy Liga on 25/05/21.
////
//
///**
// PropertyWrapper to help manage single selection on `IdentifiedArray`.
//
// if you have state like this
//
// ```swift
// struct Item: HashDiffable, Equatable {
//     let id: Int
//     var isSelected: Bool
// }
//
// let itemReducer = Reducer... {
//    switch action {
//       case .tap:
//          state.isSelected = true
//    }
// }
//
// struct State {
//     var items: IdentifiedArrayOf<Item>
// }
//
// let stateReducer = Reducer... {
//    switch action {
//       case .item(id, .tap):
//            state.items = state.items.map { item in
//                var newItem = item
//                newItem.isSelected = newItem.id == id
//
//                return newItem
//            }
//    }
// }
// ```
//
// as you can see you need to handle the action on parent too, loop each item to select only on selected `id`
// here, `SingleSelection` comes to rescue.
//
// ```swift
// struct Item: HashDiffable, Equatable {
//     let id: Int
//     var isSelected: Bool
// }
//
// let itemReducer = Reducer... {
//    switch action {
//       case .tap:
//          state.isSelected = true
//    }
// }
//
// struct State {
//     @SingleSelection(wrappedValue: [], selection: \.isSelected)
//     var items: IdentifiedArrayOf<Item>
// }
//
// let stateReducer = Reducer... {
//    switch action {
//       case .item(id, .tap):
//       # you don't need to handle it manually on parent side #
//    }
// }
// ```
//
// ## how to use
// ```
// @SingleSelection(wrappedValue: [], selection: \.isSelected)
// ```
// by using `SingleSelection`, you don't need to handle the single selection manually,
// just set selection from child side, and `SingleSelection` will automatically unselect previous one and select the new one.
//
// your array item also can conform to `Selectable`, so you don't need to manually give the keypath
//
// ```swift
// struct Item: HashDiffable, Equatable, Selectable {
//     let id: Int
//     var isSelected: Bool
// }
//
// struct State {
//     @SingleSelection
//     var items: IdentifiedArrayOf<Item>
// }
// ```
//
// - Complexity: O(n)
// everytime array is mutated, SingleSelection need to check if only one item is selected every time mutation happend.
// */
//@propertyWrapper
//public struct SingleSelection<Element> where Element: HashDiffable {
//    private let _getSelection: (Element) -> Bool
//    private let _setSelection: (inout Element, Bool) -> Void
//
//    private var _currentSelectedId: Element.IdentifierType?
//    private var _wrappedValue: IdentifiedArrayOf<Element>
//
//    public var wrappedValue: IdentifiedArrayOf<Element> {
//        get {
//            _wrappedValue
//        }
//        set {
//            set(newValue)
//        }
//    }
//
//    /**
//     SingleSelection
//
//     - Parameters:
//        - wrappedValue: initial value
//        - extract: map given `Element` to `isSelected` Bool
//        - set: closure to set new Bool value to `Element` `isSelected`
//     */
//    public init(
//        wrappedValue: IdentifiedArrayOf<Element> = [],
//        extract: @escaping (Element) -> Bool,
//        set: @escaping (inout Element, Bool) -> Void
//    ) {
//        _wrappedValue = wrappedValue
//        _getSelection = extract
//        _setSelection = set
//
//        // initial setup
//        self.set(wrappedValue)
//    }
//
//    /**
//     SingleSelection
//
//     - Parameters:
//        - wrappedValue: initial value
//        - selection: writeable keypath to `isSelected` value.
//     */
//    public init(
//        wrappedValue: IdentifiedArrayOf<Element> = [],
//        selection path: WritableKeyPath<Element, Bool>
//    ) {
//        self.init(
//            wrappedValue: wrappedValue,
//            extract: { $0[keyPath: path] },
//            set: { $0[keyPath: path] = $1 }
//        )
//    }
//
//    /**
//     logic that will run before setting new value to wrappedValue
//
//     here we will try to
//        - eleminate multiple selected item (only 1 will last)
//        - deselect `_currentSelectedId` if neccessary
//        - will keep track of current selected id on `_currentSelectedId`
//     */
//    private mutating func set(_ values: IdentifiedArrayOf<Element>) {
//        /// filter all element where `isSelected` is true, and map it to its `Element.IdentifierType` or `id`
//        let selectedIds = values
//            .compactMap { value -> Element.IdentifierType? in
//                guard _getSelection(value) else { return nil }
//                return value.id
//            }
//
//        /// if current selected id is nil, we will search for candidate
//        guard let currentSelectedId = _currentSelectedId else {
//            var _values = values
//
//            // if new given array has more than 1 item selected, will select first index and delesect else.
//            if selectedIds.count > 1 {
//                // loop every other id that is selected other than intented
//                (1 ..< selectedIds.endIndex).forEach { offset in
//                    let id = selectedIds[offset]
//                    // if not nil
//                    _values[id: id].map { value in
//                        var value = value
//                        _setSelection(&value, false) // unselect
//                        _values[id: id] = value
//                    }
//                }
//            }
//
//            // save
//            _currentSelectedId = selectedIds.first
//            _wrappedValue = _values
//
//            return
//        }
//
//        /// if current selected id count is 1, then single selection rules is fulfilled, we don't need to continue.
//        guard selectedIds.count > 1 else {
//            // save new value
//            _wrappedValue = values
//            return
//        }
//
//        // delesect current selected
//        var withoutCurrentSelection = values
//        withoutCurrentSelection[id: currentSelectedId].map { value in
//            var value = value
//            _setSelection(&value, false)
//            withoutCurrentSelection[id: currentSelectedId] = value
//        }
//
//        // clear current selection
//        _currentSelectedId = nil
//
//        // recuversivly search selected id and remove duplicate if necessary
//        set(withoutCurrentSelection)
//    }
//}
//
//public protocol Selectable {
//    var isSelected: Bool { get set }
//}
//
//extension Selectable {
//    public var path: WritableKeyPath<Self, Bool> {
//        \.isSelected
//    }
//}
//
//extension SingleSelection where Element: Selectable {
//    /**
//     SingleSelection
//
//     - Parameters:
//        - wrappedValue: initial value
//     */
//    public init(wrappedValue: IdentifiedArrayOf<Element> = []) {
//        self.init(
//            wrappedValue: wrappedValue,
//            extract: \.isSelected,
//            set: { $0.isSelected = $1 }
//        )
//    }
//}
//
//extension SingleSelection: Equatable where Element: Equatable {
//    // manually conform equatable
//    // because there're closure
//    public static func == (lhs: Self, rhs: Self) -> Bool {
//        lhs._currentSelectedId == rhs._currentSelectedId && lhs._wrappedValue == rhs._wrappedValue
//    }
//}
//
//extension SingleSelection: Hashable where Element: Hashable {
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(_currentSelectedId)
//        hasher.combine(_wrappedValue)
//    }
//}
