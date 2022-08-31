//
//  ImproveIdentifiedArray.swift
//  RxComposableArchitecture_RxComposableArchitecture
//
//  Created by arya.cia on 31/08/22.
//

import Foundation
import OrderedCollections

public struct ImprovedIdentifiedArray<ID, Element> where ID: Hashable {
    public let id: KeyPath<Element, ID>
    
    // Captures identity access.
    // Direct access to `HashDiffable`'s `.id` property is faster than key path access.
    @usableFromInline
    internal var _id: (Element) -> ID
    
    @usableFromInline
    internal var _dictionary: OrderedDictionary<ID, Element>
    
    /// A read-only collection view for the ids contained in this array, as an `OrderedSet`.
    ///
    /// - Complexity: O(1)
    @inlinable
    @inline(__always)
    public var ids: OrderedSet<ID> {
        _dictionary.keys
    }
    
    @usableFromInline
    internal init(
        id: KeyPath<Element, ID>,
        _id: @escaping(Element)->ID,
        _dictionary: OrderedDictionary<ID, Element>
    ){
        self.id = id
        self._id = _id
        self._dictionary = _dictionary
    }
    
    /// Accesses the value associated with the given id for reading and writing.
    ///
    /// This *id-based* subscript returns the element identified by the given id if found in the
    /// array, or `nil` if no element is found.
    ///
    /// When you assign an element for an id and that element already exists, the array overwrites the
    /// existing value in place. If the array doesn't contain the element, it is appended to the
    /// array.
    ///
    /// If you assign `nil` for a given id, the array removes the element identified by that id.
    ///
    /// - Parameter id: The id to find in the array.
    /// - Returns: The element associated with `id` if found in the array; otherwise, `nil`.
    /// - Complexity: Looking up values in the array through this subscript has an expected complexity
    ///   of O(1) hashing/comparison operations on average, if `ID` implements high-quality hashing.
    ///   Updating the array also has an amortized expected complexity of O(1) -- although individual
    ///   updates may need to copy or resize the array's underlying storage.
    /// - Postcondition: Element identity must remain constant over modification. Modifying an
    ///   element's id will cause a crash.
    @inlinable
    @inline(__always)
    public subscript(id id: ID) -> Element? {
        _read {
            yield self._dictionary[id]
        }
        _modify {
            yield &self._dictionary[id]
            precondition(
                self._dictionary[id].map{ self._id($0) == id } ?? true,
                "Element identity must remain constant"
            )
        }
    }
    
    @inlinable
    public func contains(_ element: Element) -> Bool {
        self._dictionary[self._id(element)] != nil
    }
    
    /// Returns the index for the given id.
    ///
    /// If an element identified by the given id is found in the array, this method returns an index
    /// into the array that corresponds to the element.
    ///
    /// ```swift
    /// struct User: HashDiffable { var id: String }
    /// let users: ImprovedIdentifiedArray = [
    ///   User(id: "u_42"),
    ///   User(id: "u_1729"),
    /// ]
    /// users.index(id: "u_1729") // 1
    /// users.index(id: "u_1337") // nil
    /// ```
    ///
    /// - Parameter id: The id to find in the array.
    /// - Returns: The index for the element identified by `id` if found in the array; otherwise,
    ///   `nil`.
    /// - Complexity: Expected to be O(1) on average, if `ID` implements high-quality hashing.
    @inlinable
    @inline(__always)
    public func index(id: ID) -> Int? {
        self._dictionary.index(forKey: id)
    }
    
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        self._dictionary.removeValue(forKey: self._id(element))
    }
    
    /// Removes the element identified by the given id from the array.
    ///
    /// ```swift
    /// struct User: HashDiffable { var id: String }
    /// let users: ImprovedIdentifiedArray = [
    ///   User(id: "u_42"),
    ///   User(id: "u_1729"),
    /// ]
    /// users.remove(id: "u_1729") // User(id: "u_1729")
    /// users                      // [User(id: "u_42")]
    /// users.remove(id: "u_1337") // nil
    /// ```
    ///
    /// - Parameter id: The id of the element to be removed from the array.
    /// - Returns: The element that was removed, or `nil` if the element was not present in the array.
    /// - Complexity: O(`count`)
    @inlinable
    @discardableResult
    public mutating func remove(_ id: ID) -> Element? {
        self._dictionary.removeValue(forKey: id)
    }
}

/**
    A convenience typealias that specifies an ``NImprovedIdentifiedArray``
    by an element conforming to the `HashDiffable` protocol
 */
public typealias ImprovedIdentifiedArrayOf<Element> = ImprovedIdentifiedArray<Element.IdentifierType, Element> where Element: HashDiffable

//MARK: - ImprovedIdentifiedArray+Codable

extension ImprovedIdentifiedArray: Encodable where Element: Encodable {
  @inlinable
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(ContiguousArray(self._dictionary.values))
  }
}

extension ImprovedIdentifiedArray: Decodable
where Element: Decodable & HashDiffable, ID == Element.IdentifierType {
  @inlinable
  public init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    self.init()
    while !container.isAtEnd {
      let element = try container.decode(Element.self)
      let (inserted, _) = self.append(element)
      guard inserted else {
        let context = DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Duplicate element at offset \(container.currentIndex - 1)"
        )
        throw DecodingError.dataCorrupted(context)
      }
    }
  }
}

//MARK: - ImprovedIdentifiedArray+Collection

extension ImprovedIdentifiedArray: Collection {
  @inlinable
  @inline(__always)
  public var startIndex: Int { self._dictionary.keys.startIndex }

  @inlinable
  @inline(__always)
  public var endIndex: Int { self._dictionary.keys.endIndex }

  @inlinable
  @inline(__always)
  public func index(after i: Int) -> Int { self._dictionary.keys.index(after: i) }

  @inlinable
  @inline(__always)
  public subscript(position: Int) -> Element {
      _read {
          yield self._dictionary.elements[position].value
      }
      @available(
        *, unavailable, message: "use the id-based subscript, instead, for in-place modification"
      )
      set {
          fatalError()
      }
  }

  /// Returns a new array containing the elements of the array that satisfy the given predicate.
  ///
  /// - Parameter isIncluded: A closure that takes an element as its argument and returns a Boolean
  ///   value indicating whether it should be included in the returned array.
  /// - Returns: An array of the elements that `isIncluded` allows.
  /// - Complexity: O(`count`)
  @inlinable
  public func filter(
    _ isIncluded: (Element) throws -> Bool
  ) rethrows -> Self {
    try .init(
      id: self.id,
      _id: self._id,
      _dictionary: self._dictionary.filter { try isIncluded($1) }
    )
  }
}

//MARK: - ImprovedIdentifiedArray+CustomDebugStringConvertible

extension ImprovedIdentifiedArray: CustomDebugStringConvertible {
  public var debugDescription: String {
    var result = "ImprovedIdentifiedArray<\(Element.self)>(["
    var first = true
    for item in self {
      if first {
        first = false
      } else {
        result += ", "
      }
      debugPrint(item, terminator: "", to: &result)
    }
    result += "])"
    return result
  }
}

//MARK: - ImprovedIdentifiedArray+CustomReflectable

extension ImprovedIdentifiedArray: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(self, unlabeledChildren: Array(self), displayStyle: .collection)
  }
}

//MARK: - ImprovedIdentifiedArray+CustomStringConvertible

extension ImprovedIdentifiedArray: CustomStringConvertible {
  public var description: String {
    var result = "["
    var first = true
    for item in self {
      if first {
        first = false
      } else {
        result += ", "
      }
      debugPrint(item, terminator: "", to: &result)
    }
    result += "]"
    return result
  }
}

//MARK: - ImprovedIdentifiedArray+Equatable

extension ImprovedIdentifiedArray: Equatable where Element: Equatable {
  @inlinable
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id && lhs.elementsEqual(rhs)
  }
}

//MARK: - ImprovedIdentifiedArray+ExpressibleByArrayLiteral

extension ImprovedIdentifiedArray: ExpressibleByArrayLiteral where Element: HashDiffable, ID == Element.IdentifierType {
  @inlinable
  public init(arrayLiteral elements: Element...) {
    self.init(uniqueElements: elements)
  }
}

//MARK: - ImprovedIdentifiedArray+Hashable

extension ImprovedIdentifiedArray: Hashable where Element: Hashable {
  @inlinable
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
    hasher.combine(self.count)
    for element in self {
      hasher.combine(element)
    }
  }
}

//MARK: - ImprovedIdentifiedArray+PartialMutableCollections

extension ImprovedIdentifiedArray {
  /// Reorders the elements of the array such that all the elements that match the given predicate
  /// are after all the elements that don't match.
  ///
  /// After partitioning a collection, there is a pivot index `p` where no element before `p`
  /// satisfies the `belongsInSecondPartition` predicate and every element at or after `p` satisfies
  /// `belongsInSecondPartition`.
  ///
  /// - Parameter belongsInSecondPartition: A predicate used to partition the collection. All
  ///   elements satisfying this predicate are ordered after all elements not satisfying it.
  /// - Returns: The index of the first element in the reordered collection that matches
  ///  `belongsInSecondPartition`. If no elements in the collection match
  ///  `belongsInSecondPartition`, the returned index is equal to the collection's `endIndex`.
  /// - Complexity: O(`count`)
  @inlinable
  public mutating func partition(
    by belongsInSecondPartition: (Element) throws -> Bool
  ) rethrows -> Int {
    try self._dictionary.values.partition(by: belongsInSecondPartition)
  }

  /// Reverses the elements of the array in place.
  ///
  /// - Complexity: O(`count`)
  @inlinable
  public mutating func reverse() {
    self._dictionary.reverse()
  }

  /// Shuffles the collection in place.
  ///
  /// Use the `shuffle()` method to randomly reorder the elements of an array.
  ///
  /// This method is equivalent to calling ``shuffle(using:)``, passing in the system's default
  /// random generator.
  ///
  /// - Complexity: O(*n*), where *n* is the length of the collection.
  @inlinable
  public mutating func shuffle() {
    self._dictionary.shuffle()
  }

  /// Shuffles the collection in place, using the given generator as a source for randomness.
  ///
  /// You use this method to randomize the elements of a collection when you are using a custom
  /// random number generator.
  ///
  /// - Parameter generator: The random number generator to use when shuffling the collection.
  /// - Complexity: O(*n*), where *n* is the length of the collection.
  /// - Note: The algorithm used to shuffle a collection may change in a future version of Swift.
  ///   If you're passing a generator that results in the same shuffled order each time you run your
  ///   program, that sequence may change when your program is compiled using a different version of
  ///   Swift.
  @inlinable
  public mutating func shuffle<T: RandomNumberGenerator>(using generator: inout T) {
    self._dictionary.shuffle(using: &generator)
  }

  /// Sorts the collection in place, using the given predicate as the comparison between elements.
  ///
  /// When you want to sort a collection of elements that don't conform to the `Comparable`
  /// protocol, pass a closure to this method that returns `true` when the first element should be
  /// ordered before the second.
  ///
  /// Alternatively, use this method to sort a collection of elements that do conform to
  /// `Comparable` when you want the sort to be descending instead of ascending. Pass the
  /// greater-than operator (`>`) operator as the predicate.
  ///
  /// `areInIncreasingOrder` must be a *strict weak ordering* over the elements. That is, for any
  /// elements `a`, `b`, and `c`, the following conditions must hold:
  ///
  ///   * `areInIncreasingOrder(a, a)` is always `false`. (Irreflexivity)
  ///   * If `areInIncreasingOrder(a, b)` and `areInIncreasingOrder(b, c)` are both `true`, then
  ///     `areInIncreasingOrder(a, c)` is also `true`. (Transitive comparability)
  ///   * Two elements are *incomparable* if neither is ordered before the other according to the
  ///     predicate. If `a` and `b` are incomparable, and `b` and `c` are incomparable, then `a`
  ///     and `c` are also incomparable. (Transitive incomparability)
  ///
  /// The sorting algorithm is not guaranteed to be stable. A stable sort preserves the relative
  /// order of elements for which `areInIncreasingOrder` does not establish an order.
  ///
  /// - Parameter areInIncreasingOrder: A predicate that returns `true` if its first argument should
  ///   be ordered before its second argument; otherwise, `false`. If `areInIncreasingOrder` throws
  ///   an error during the sort, the elements may be in a different order, but none will be lost.
  /// - Complexity: O(*n* log *n*), where *n* is the length of the collection.
  @inlinable
  public mutating func sort(
    by areInIncreasingOrder: (Element, Element) throws -> Bool
  ) rethrows {
    try self._dictionary.sort(by: { try areInIncreasingOrder($0.value, $1.value) })
  }

  /// Exchanges the values at the specified indices of the array.
  ///
  /// Both parameters must be valid indices below ``endIndex``. Passing the same index as both `i`
  /// and `j` has no effect.
  ///
  /// - Parameters:
  ///   - i: The index of the first value to swap.
  ///   - j: The index of the second value to swap.
  /// - Complexity: O(1) when the array's storage isn't shared with another value; O(`count`)
  ///   otherwise.
  @inlinable
  public mutating func swapAt(_ i: Int, _ j: Int) {
    self._dictionary.swapAt(i, j)
  }
}

extension ImprovedIdentifiedArray where Element: Comparable {
  /// Sorts the set in place.
  ///
  /// You can sort an ordered set of elements that conform to the `Comparable` protocol by calling
  /// this method. Elements are sorted in ascending order.
  ///
  /// To sort the elements of your collection in descending order, pass the greater-than operator
  /// (`>`) to the ``sort(by:)`` method.
  ///
  /// The sorting algorithm is not guaranteed to be stable. A stable sort preserves the relative
  /// order of elements that compare equal.
  ///
  /// - Complexity: O(*n* log *n*), where *n* is the length of the collection.
  @inlinable
  public mutating func sort() {
    self.sort(by: <)
  }
}

#if canImport(SwiftUI)
  import SwiftUI

  extension ImprovedIdentifiedArray {
    /// Moves all the elements at the specified offsets to the specified destination offset,
    /// preserving ordering.
    ///
    /// - Parameters:
    ///   - source: The offsets of all elements to be moved.
    ///   - destination: The destination offset.
    /// - Complexity: O(*n* log *n*), where *n* is the length of the collection.
    @inlinable
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
      var removed: [Element] = []
      var removedBeforeDestinationCount = 0

      removed.reserveCapacity(source.count)
      for index in source.reversed() {
        removed.append(self.remove(at: index))
        if destination > index {
          removedBeforeDestinationCount += 1
        }
      }
      for element in removed {
        self.insert(element, at: destination - removedBeforeDestinationCount)
      }
    }
  }
#endif

//MARK: - ImprovedIdentifiedArray+PartialRangeReplaceableCollection

extension ImprovedIdentifiedArray where Element: HashDiffable, ID == Element.IdentifierType {
  /// Creates an empty array.
  ///
  /// This initializer is equivalent to initializing with an empty array literal.
  ///
  /// - Complexity: O(1)
  @inlinable
  public init() {
    self.init(id: \.id, _id: { $0.id }, _dictionary: .init())
  }
}

extension ImprovedIdentifiedArray {
  /// Removes and returns the element at the specified position.
  ///
  /// All the elements following the specified position are moved to close the resulting gap.
  ///
  /// - Parameter index: The position of the element to remove.
  /// - Returns: The removed element.
  /// - Precondition: `index` must be a valid index of the collection that is not equal to the
  ///   collection's end index.
  /// - Complexity: O(`count`)
  @inlinable
  @discardableResult
  public mutating func remove(at index: Int) -> Element {
    self._dictionary.remove(at: index).value
  }

  /// Removes all members from the set.
  ///
  /// - Parameter keepingCapacity: If `true`, the array's storage capacity is preserved; if `false`,
  ///   the underlying storage is released. The default is `false`.
  /// - Complexity: O(`count`)
  @inlinable
  public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
    self._dictionary.removeAll(keepingCapacity: keepCapacity)
  }

  /// Removes all the elements that satisfy the given predicate.
  ///
  /// Use this method to remove every element in a collection that meets particular criteria. The
  /// order of the remaining elements is preserved.
  ///
  /// - Parameter shouldBeRemoved: A closure that takes an element of the collection as its argument
  ///   and returns a Boolean value indicating whether the element should be removed from the
  ///   collection.
  /// - Complexity: O(`count`)
  @inlinable
  public mutating func removeAll(
    where shouldBeRemoved: (Element) throws -> Bool
  ) rethrows {
    try self._dictionary.removeAll(where: { try shouldBeRemoved($0.value) })
  }

  /// Removes the first element of a non-empty array.
  ///
  /// The members following the removed item need to be moved to close the resulting gap in the
  /// storage array.
  ///
  /// - Returns: The removed element.
  /// - Precondition: The array must be non-empty.
  /// - Complexity: O(`count`).
  @inlinable
  @discardableResult
  public mutating func removeFirst() -> Element {
    self._dictionary.removeFirst().value
  }

  /// Removes the first `n` elements of the collection.
  ///
  /// The members following the removed items need to be moved to close the resulting gap in the
  /// storage array.
  ///
  /// - Parameter n: The number of elements to remove from the collection.
  /// - Precondition: `n` must be greater than or equal to zero and must not exceed the number of
  ///   elements in the collection.
  /// - Complexity: O(`count`).
  @inlinable
  public mutating func removeFirst(n: Int) {
    self._dictionary.removeFirst(n)
  }

  /// Removes the last element of a non-empty array.
  ///
  /// - Returns: The removed element.
  /// - Precondition: The array must be non-empty.
  /// - Complexity: Expected to be O(`1`) on average, if `ID` implements high-quality hashing.
  @inlinable
  @discardableResult
  public mutating func removeLast() -> Element {
    self._dictionary.removeLast().value
  }

  /// Removes the last `n` element of the set.
  ///
  /// - Parameter n: The number of elements to remove from the collection.
  /// - Precondition: `n` must be greater than or equal to zero and must not exceed the number of
  ///   elements in the collection.
  /// - Complexity: Expected to be O(`n`) on average, if `ID` implements high-quality hashing.
  @inlinable
  public mutating func removeLast(_ n: Int) {
    self._dictionary.removeLast(n)
  }

  /// Removes the specified subrange of elements from the collection.
  ///
  /// All the elements following the specified subrange are moved to close the resulting gap.
  ///
  /// - Parameter bounds: The subrange of the collection to remove.
  /// - Precondition: The bounds of the range must be valid indices of the collection.
  /// - Complexity: O(`count`)
  @inlinable
  public mutating func removeSubrange(_ bounds: Range<Int>) {
    self._dictionary.removeSubrange(bounds)
  }

  /// Removes the specified subrange of elements from the collection.
  ///
  /// All the elements following the specified subrange are moved to close the resulting gap.
  ///
  /// - Parameter bounds: The subrange of the collection to remove.
  /// - Precondition: The bounds of the range must be valid indices of the collection.
  /// - Complexity: O(`count`)
  @inlinable
  public mutating func removeSubrange<R>(_ bounds: R)
  where R: RangeExpression, R.Bound == Int {
    self._dictionary.removeSubrange(bounds)
  }

  /// Reserves enough space to store the specified number of elements.
  ///
  /// This method ensures that the array has unique, mutable, contiguous storage, with space
  /// allocated for at least the requested number of elements.
  ///
  /// If you are adding a known number of elements to a dictionary, call this method once before
  /// the first insertion to avoid multiple reallocations.
  ///
  /// Do not call this method in a loop -- it does not use an exponential allocation strategy, so
  /// doing that can result in quadratic instead of linear performance.
  ///
  /// - Parameter minimumCapacity: The minimum number of elements that the array should be able to
  ///   store without reallocating its storage.
  /// - Complexity: O(`max(count, minimumCapacity)`)
  @inlinable
  public mutating func reserveCapacity(_ minimumCapacity: Int) {
    self._dictionary.reserveCapacity(minimumCapacity)
  }
}

#if canImport(SwiftUI)
  import SwiftUI

  extension ImprovedIdentifiedArray {
    /// Removes all the elements at the specified offsets from the collection.
    ///
    /// - Parameter offsets: The offsets of all elements to be removed.
    /// - Complexity: O(*n*) where *n* is the length of the collection.
    @inlinable
    public mutating func remove(atOffsets offsets: IndexSet) {
      for range in offsets.rangeView.reversed() {
        self.removeSubrange(range)
      }
    }
  }
#endif

//MARK: ImprovedIdentifiedArray+RandomAccessCollection

extension ImprovedIdentifiedArray: RandomAccessCollection {}

//MARK: ImprovedIdentifiedArray+Initializers

extension ImprovedIdentifiedArray {
  /// Creates a new array from the elements in the given sequence, which must not contain duplicate
  /// ids.
  ///
  /// In optimized builds, this initializer does not verify that the ids are actually unique. This
  /// makes creating the array somewhat faster if you know for sure that the elements are unique
  /// (e.g., because they come from another collection with guaranteed-unique members. However, if
  /// you accidentally call this initializer with duplicate members, it can return a corrupt array
  /// value that may be difficult to debug.
  ///
  /// - Parameters:
  ///   - elements: A sequence of elements to use for the new array. Every key in `elements`
  ///     must be unique.
  ///   - id: The key path to an element's identifier.
  /// - Returns: A new array initialized with the elements of `elements`.
  /// - Precondition: The sequence must not have duplicate ids.
  /// - Complexity: Expected O(*n*) on average, where *n* is the count of elements, if `ID`
  ///   implements high-quality hashing.
  @inlinable
  @_disfavoredOverload
  public init<S>(
    uncheckedUniqueElements elements: S,
    id: KeyPath<Element, ID>
  )
  where S: Sequence, S.Element == Element {
    self.init(
      id: id,
      _id: { $0[keyPath: id] },
      _dictionary: .init(uncheckedUniqueKeysWithValues: elements.lazy.map { ($0[keyPath: id], $0) })
    )
  }

  /// Creates a new array from the elements in the given sequence.
  ///
  /// You use this initializer to create an array when you have a sequence of elements with unique
  /// ids. Passing a sequence with duplicate ids to this initializer results in a runtime error.
  ///
  /// - Parameters:
  ///   - elements: A sequence of elements to use for the new array. Every key in
  ///     `keysAndValues` must be unique.
  ///   - id: The key path to an element's identifier.
  /// - Returns: A new array initialized with the elements of `elements`.
  /// - Precondition: The sequence must not have duplicate ids.
  /// - Complexity: Expected O(*n*) on average, where *n* is the count of elements, if `ID`
  ///   implements high-quality hashing.
  @inlinable
  public init<S>(
    uniqueElements elements: S,
    id: KeyPath<Element, ID>
  )
  where S: Sequence, S.Element == Element {
    if S.self == Self.self {
      self = elements as! Self
      return
    }
    if S.self == SubSequence.self {
      self.init(uncheckedUniqueElements: elements, id: id)
      return
    }
    self.init(
      id: id,
      _id: { $0[keyPath: id] },
      _dictionary: .init(uniqueKeysWithValues: elements.lazy.map { ($0[keyPath: id], $0) })
    )
  }

  /// Creates a new array from an existing array. This is functionally the same as copying the value
  /// of `elements` into a new variable.
  ///
  /// - Parameter elements: The elements to use as members of the new set.
  /// - Complexity: O(1)
  @inlinable
  public init(_ elements: Self) {
    self = elements
  }

  /// Creates a new set from an existing slice of another dictionary.
  ///
  /// - Parameter elements: The elements to use as members of the new array.
  /// - Complexity: This operation is expected to perform O(`elements.count`) operations on average,
  ///   provided that `ID` implements high-quality hashing.
  @inlinable
  public init(_ elements: SubSequence) {
    self.init(uncheckedUniqueElements: elements, id: elements.base.id)
  }

  /// Creates an empty array.
  ///
  /// - Parameter id: The key path to an element's identifier.
  /// - Complexity: O(1)
  @inlinable
  public init(id: KeyPath<Element, ID>) {
    self.init(id: id, _id: { $0[keyPath: id] }, _dictionary: .init())
  }
}

extension ImprovedIdentifiedArray where Element: HashDiffable, ID == Element.IdentifierType {
  /// Creates a new array from the elements in the given sequence, which must not contain duplicate
  /// ids.
  ///
  /// In optimized builds, this initializer does not verify that the ids are actually unique. This
  /// makes creating the array somewhat faster if you know for sure that the elements are unique
  /// (e.g., because they come from another collection with guaranteed-unique members. However, if
  /// you accidentally call this initializer with duplicate members, it can return a corrupt array
  /// value that may be difficult to debug.
  ///
  /// - Parameter elements: A sequence of elements to use for the new array. Every key in `elements`
  ///   must be unique.
  /// - Returns: A new array initialized with the elements of `elements`.
  /// - Precondition: The sequence must not have duplicate ids.
  /// - Complexity: Expected O(*n*) on average, where *n* is the count of elements, if `ID`
  ///   implements high-quality hashing.
  @inlinable
  @_disfavoredOverload
  public init<S>(uncheckedUniqueElements elements: S) where S: Sequence, S.Element == Element {
    self.init(
      id: \.id,
      _id: { $0.id },
      _dictionary: .init(uncheckedUniqueKeysWithValues: elements.lazy.map { ($0.id, $0) })
    )
  }

  /// Creates a new array from the elements in the given sequence.
  ///
  /// You use this initializer to create an array when you have a sequence of elements with unique
  /// ids. Passing a sequence with duplicate ids to this initializer results in a runtime error.
  ///
  /// - Parameters elements: A sequence of elements to use for the new array. Every key in
  ///   `keysAndValues` must be unique.
  /// - Returns: A new array initialized with the elements of `elements`.
  /// - Precondition: The sequence must not have duplicate ids.
  /// - Complexity: Expected O(*n*) on average, where *n* is the count of elements, if `ID`
  ///   implements high-quality hashing.
  @inlinable
  public init<S>(uniqueElements elements: S) where S: Sequence, S.Element == Element {
    if S.self == Self.self {
      self = elements as! Self
      return
    }
    if let elements = elements as? SubSequence {
      self.init(uncheckedUniqueElements: elements, id: elements.base.id)
      return
    }
    self.init(
      id: \.id,
      _id: { $0.id },
      _dictionary: .init(uniqueKeysWithValues: elements.lazy.map { ($0.id, $0) })
    )
  }
}

// MARK: - Deprecations

extension ImprovedIdentifiedArray {
  @available(*, deprecated, renamed: "init(uniqueElements:id:)")
  public init<S>(_ elements: S, id: KeyPath<Element, ID>) where S: Sequence, S.Element == Element {
    self.init(uniqueElements: elements, id: id)
  }
}

extension ImprovedIdentifiedArray where Element: HashDiffable, ID == Element.IdentifierType {
  @available(*, deprecated, renamed: "init(uniqueElements:)")
  public init<S>(_ elements: S) where S: Sequence, S.Element == Element {
    self.init(uniqueElements: elements)
  }
}

//MARK: - ImprovedIdentifiedArray+Insertions

extension ImprovedIdentifiedArray {
  /// Append a new member to the end of the array, if the array doesn't already contain it.
  ///
  /// - Parameter item: The element to add to the array.
  /// - Returns: A pair `(inserted, index)`, where `inserted` is a Boolean value indicating whether
  ///   the operation added a new element, and `index` is the index of `item` in the resulting
  ///   array.
  /// - Complexity: The operation is expected to perform O(1) copy, hash, and compare operations on
  ///   the `ID` type, if it implements high-quality hashing.
  @inlinable
  @inline(__always)
  @discardableResult
  public mutating func append(_ item: Element) -> (inserted: Bool, index: Int) {
    self.insert(item, at: self.endIndex)
  }

  /// Insert a new member to this array at the specified index, if the array doesn't already contain
  /// it.
  ///
  /// - Parameter item: The element to insert.
  /// - Returns: A pair `(inserted, index)`, where `inserted` is a Boolean value indicating whether
  ///   the operation added a new element, and `index` is the index of `item` in the resulting
  ///   array. If `inserted` is true, then the returned `index` may be different from the index
  ///   requested.
  ///
  /// - Complexity: The operation is expected to perform amortized O(`self.count`) copy, hash, and
  ///   compare operations on the `ID` type, if it implements high-quality hashing. (Insertions need
  ///   to make room in the storage array to add the inserted element.)
  @inlinable
  @discardableResult
  public mutating func insert(_ item: Element, at i: Int) -> (inserted: Bool, index: Int) {
    if let existing = self._dictionary.index(forKey: _id(item)) {
      return (false, existing)
    }
    self._dictionary.updateValue(item, forKey: _id(item), insertingAt: i)
    return (true, i)
  }

  /// Replace the member at the given index with a new value of the same identity.
  ///
  /// - Parameter item: The new value that should replace the original element. `item` must match
  ///   the identity of the original value.
  /// - Parameter index: The index of the element to be replaced.
  /// - Returns: The original element that was replaced.
  /// - Complexity: Amortized O(1).
  @inlinable
  @discardableResult
  public mutating func update(_ item: Element, at i: Int) -> Element {
    let old = self._dictionary.elements[i].key
    precondition(
      _id(item) == old, "The replacement item must match the identity of the original"
    )
    return self._dictionary.updateValue(item, forKey: old)!
  }

  /// Adds the given element to the array unconditionally, either appending it to the array, or
  /// replacing an existing value if it's already present.
  ///
  /// - Parameter item: The value to append or replace.
  /// - Returns: The original element that was replaced by this operation, or `nil` if the value was
  ///   appended to the end of the collection.
  /// - Complexity: The operation is expected to perform amortized O(1) copy, hash, and compare
  ///   operations on the `ID` type, if it implements high-quality hashing.
  @inlinable
  @discardableResult
  public mutating func updateOrAppend(_ item: Element) -> Element? {
    self._dictionary.updateValue(item, forKey: _id(item))
  }

  /// Adds the given element into the set unconditionally, either inserting it at the specified
  /// index, or replacing an existing value if it's already present.
  ///
  /// - Parameter item: The value to append or replace.
  /// - Parameter index: The index at which to insert the new member if `item` isn't already in the
  ///   set.
  /// - Returns: The original element that was replaced by this operation, or `nil` if the value was
  ///   newly inserted into the collection.
  /// - Complexity: The operation is expected to perform amortized O(1) copy, hash, and compare
  ///   operations on the `ID` type, if it implements high-quality hashing.
  @inlinable
  @discardableResult
  public mutating func updateOrInsert(
    _ item: Element,
    at i: Int
  ) -> (originalMember: Element?, index: Int) {
    self._dictionary.updateValue(item, forKey: _id(item), insertingAt: i)
  }
}
