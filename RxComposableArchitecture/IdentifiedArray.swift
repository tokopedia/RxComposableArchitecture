//
//  IdentifiedArray.swift
//  RxComposableArchitecture_RxComposableArchitecture
//
//  Created by Jefferson Setiawan on 16/07/20.
//

import DiffingInterface
import Foundation

/// An array of elements that can be identified by a given key path.
///
/// A useful container of state that is intended to interface with `ForEachStore`. For example,
/// your application may model a counter in an identifiable fashion:
///
///     struct CounterState: Differentiable {
///       let id: UUID
///       var count = 0
///     }
///     enum CounterAction { case incr, decr }
///     let counterReducer = Reducer<CounterState, CounterAction, Void> { ... }
///
/// This domain can be pulled back to a larger domain with the `forEach` method:
///
///     struct AppState { var counters = IdentifiedArray<Int>(id: \.self) }
///     enum AppAction { case counter(id: UUID, action: CounterAction) }
///     let appReducer = counterReducer.forEach(
///       state: \AppState.counters,
///       action: /AppAction.counter(id:action:),
///       environment: { $0 }
///     )
///
/// And then SwiftUI can work with this array of identified elements in a list view:
///
///     struct AppView: View {
///       let store: Store<AppState, AppAction>
///
///       var body: some View {
///         List {
///           ForEachStore(
///             self.store.scope(state: \.counters, action: AppAction.counter(id:action))
///             content: CounterView.init(store:)
///           )
///         }
///       }
///     }
public struct IdentifiedArray<ID, Element>: MutableCollection, RandomAccessCollection
    where ID: Hashable {
    /// A key path to a value that identifies an element.
    public let id: KeyPath<Element, ID>

    /// A raw array of each element's identifier.
    public private(set) var ids: [ID]

    /// A raw array of the underlying elements.
    public var elements: [Element] { Array(self) }

    // TODO: Support multiple elements with the same identifier but different data.
    private var dictionary: [ID: Element]

    /// Initializes an identified array with a sequence of elements and a key
    /// path to an element's identifier.
    ///
    /// - Parameters:
    ///   - elements: A sequence of elements.
    ///   - id: A key path to a value that identifies an element.
    public init<S>(_ elements: S, id: KeyPath<Element, ID>) where S: Sequence, S.Element == Element {
        self.id = id

        let idsAndElements = elements.map { (id: $0[keyPath: id], element: $0) }
        ids = idsAndElements.map { $0.id }
        dictionary = Dictionary(idsAndElements, uniquingKeysWith: { $1 })
    }

    /// Initializes an empty identified array with a key path to an element's
    /// identifier.
    ///
    /// - Parameter id: A key path to a value that identifies an element.
    public init(id: KeyPath<Element, ID>) {
        self.init([], id: id)
    }

    public var startIndex: Int { ids.startIndex }
    public var endIndex: Int { ids.endIndex }

    public func index(after i: Int) -> Int {
        ids.index(after: i)
    }

    public func index(before i: Int) -> Int {
        ids.index(before: i)
    }

    public subscript(position: Int) -> Element {
        // NB: `_read` crashes Xcode Preview compilation.
        get { dictionary[ids[position]]! }
        _modify { yield &self.dictionary[self.ids[position]]! }
    }

    #if DEBUG
        /// Direct access to an element by its identifier.
        ///
        /// - Parameter id: The identifier of element to access. Must be a valid identifier for an
        ///   element of the array and will _not_ insert elements that are not already in the array, or
        ///   remove elements when passed `nil`. Use `append` or `insert(_:at:)` to insert elements. Use
        ///   `remove(id:)` to remove an element by its identifier.
        /// - Returns: The element.
        public subscript(id id: ID) -> Element? {
            get { dictionary[id] }
            set {
                if newValue != nil, dictionary[id] == nil {
                    fatalError(
                        """
                        Can't update element with identifier \(id) because no such element exists in the array.

                        If you are trying to insert an element into the array, use the "append" or "insert" \
                        methods.
                        """
                    )
                }
                if newValue == nil {
                    fatalError(
                        """
                        Can't update element with identifier \(id) with nil.

                        If you are trying to remove an element from the array, use the "remove(id:) method."
                        """
                    )
                }
                if newValue![keyPath: self.id] != id {
                    fatalError(
                        """
                        Can't update element at identifier \(id) with element having mismatched identifier \
                        \(newValue![keyPath: self.id]).

                        If you would like to replace the element with identifier \(id) with an element with a \
                        new identifier, remove the existing element and then insert the new element, instead.
                        """
                    )
                }
                dictionary[id] = newValue
            }
        }

    #else
        public subscript(id id: ID) -> Element? {
            // NB: `_read` crashes Xcode Preview compilation.
            get { dictionary[id] }
            _modify { yield &self.dictionary[id] }
        }
    #endif

    public mutating func insert(_ newElement: Element, at i: Int) {
        let id = newElement[keyPath: self.id]
        dictionary[id] = newElement
        ids.insert(id, at: i)
    }

    public mutating func insert<C>(
        contentsOf newElements: C, at i: Int
    ) where C: Collection, Element == C.Element {
        for newElement in newElements.reversed() {
            insert(newElement, at: i)
        }
    }

    /// Removes and returns the element with the specified identifier.
    ///
    /// - Parameter id: The identifier of the element to remove.
    /// - Returns: The removed element.
    @discardableResult
    public mutating func remove(id: ID) -> Element {
        let element = dictionary[id]
        assert(element != nil, "Unexpectedly found nil while removing an identified element.")
        dictionary[id] = nil
        ids.removeAll(where: { $0 == id })
        return element!
    }

    @discardableResult
    public mutating func remove(at position: Int) -> Element {
        remove(id: ids.remove(at: position))
    }

    public mutating func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        var ids: [ID] = []
        for (index, id) in zip(self.ids.indices, self.ids).reversed() {
            if try shouldBeRemoved(dictionary[id]!) {
                self.ids.remove(at: index)
                ids.append(id)
            }
        }
        for id in ids where !self.ids.contains(id) {
            self.dictionary[id] = nil
        }
    }

    public mutating func remove(atOffsets offsets: IndexSet) {
        for offset in offsets.reversed() {
            _ = remove(at: offset)
        }
    }

    /// Unavailable, if needed, please implement this, The implementation of `move` is in SwitUI.Collection.Array
//    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
//        self.ids.move(fromOffsets: source, toOffset: destination)
//    }

    public mutating func sort(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows {
        try ids.sort {
            try areInIncreasingOrder(self.dictionary[$0]!, self.dictionary[$1]!)
        }
    }

    public mutating func shuffle<T>(using generator: inout T) where T: RandomNumberGenerator {
        ids.shuffle(using: &generator)
    }

    public mutating func shuffle() {
        var rng = SystemRandomNumberGenerator()
        shuffle(using: &rng)
    }

    public mutating func reverse() {
        ids.reverse()
    }
}

extension IdentifiedArray: CustomDebugStringConvertible {
    public var debugDescription: String {
        elements.debugDescription
    }
}

extension IdentifiedArray: CustomReflectable {
    public var customMirror: Mirror {
        Mirror(reflecting: elements)
    }
}

extension IdentifiedArray: CustomStringConvertible {
    public var description: String {
        elements.description
    }
}

extension IdentifiedArray: Decodable where Element: Decodable & HashDiffable, ID == Element.IdentifierType {
    public init(from decoder: Decoder) throws {
        self.init(try [Element](from: decoder))
    }
}

extension IdentifiedArray: Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
        try elements.encode(to: encoder)
    }
}

extension IdentifiedArray: Equatable where Element: Equatable {}

extension IdentifiedArray: Hashable where Element: Hashable {}

extension IdentifiedArray where Element: Comparable {
    public mutating func sort() {
        sort(by: <)
    }
}

extension IdentifiedArray: ExpressibleByArrayLiteral where Element: HashDiffable, ID == Element.IdentifierType {
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension IdentifiedArray where Element: HashDiffable, ID == Element.IdentifierType {
    public init<S>(_ elements: S) where S: Sequence, S.Element == Element {
        self.init(elements, id: \.id)
    }
}

extension IdentifiedArray: RangeReplaceableCollection
    where Element: HashDiffable, ID == Element.IdentifierType {
    public init() {
        self.init([], id: \.id)
    }

    public mutating func replaceSubrange<C, R>(_ subrange: R, with newElements: C)
        where C: Collection, R: RangeExpression, Element == C.Element, Index == R.Bound {
        let replacingIds = ids[subrange]
        let newIds = newElements.map { $0.id }
        ids.replaceSubrange(subrange, with: newIds)

        for element in newElements {
            dictionary[element.id] = element
        }

        for id in replacingIds where !ids.contains(id) {
            self.dictionary[id] = nil
        }
    }
}

/// A convenience type to specify an `IdentifiedArray` by an identifiable element.
public typealias IdentifiedArrayOf<Element> = IdentifiedArray<Element.IdentifierType, Element>
    where Element: HashDiffable

extension IdentifiedArrayOf where Element: HashDiffable, Element.IdentifierType == ID {
    public func removeDuplicates() -> Self {
        /// This table will contain `diffIdentifier` as the `key` and object `type` as the value
        var tableOfObjectType = [AnyHashable: Any.Type]()

        var uniqueObjects = IdentifiedArrayOf<Element>()

        forEach { currentObject in
            /// Get current object identifier
            let currentId = currentObject.id

            /// Get current object type from Type Erasure base object
            let currentObjectType = type(of: currentObject)

            /// Check if `currentId` is already registered on `Table Bank of Identifiers Type`
            /// If `yes` > Get object type with current identifier from `Table Bank of Identifiers Type`
            /// If `no` > Then return `nil`
            let previousObjectType = tableOfObjectType[currentId]

            /// Check whether current object type is the same with previous object type(if exist) fetched from `Table Bank of Identifiers Type`
            /// If `currentId` already exist on `Table Bank of Identifiers Type` but the type is different it's not counted as _**duplicates**_
            if currentObjectType != previousObjectType {
                tableOfObjectType[currentId] = currentObjectType
                uniqueObjects.append(currentObject)
            }
        }

        return uniqueObjects
    }
}

extension IdentifiedArray {
    public var isNotEmpty: Bool {
        return !isEmpty
    }

    @inlinable
    public subscript(safe index: Index) -> Element? {
        guard startIndex <= index, index < endIndex else { return nil }
        return self[index]
    }
}
