//
//  CompatibilityCollectionDifference.swift
//
//
//  Created by jefferson.setiawan on 02/08/22.
//

import Foundation

// https://github.com/apple/swift/blob/main/stdlib/public/core/CollectionDifference.swift
struct CompatibilityCollectionDifference<ChangeElement> {
    /// A single change to a collection.
    @frozen public enum Change {

        /// An insertion.
        ///
        /// The `offset` value is the offset of the inserted element in the final
        /// state of the collection after the difference is fully applied.
        /// A non-`nil` `associatedWith` value is the offset of the complementary
        /// change.
        case insert(offset: Int, element: ChangeElement, associatedWith: Int?)

        /// A removal.
        ///
        /// The `offset` value is the offset of the element to be removed in the
        /// original state of the collection. A non-`nil` `associatedWith` value is
        /// the offset of the complementary change.
        case remove(offset: Int, element: ChangeElement, associatedWith: Int?)
        //        // Internal common field accessors
        //        internal var _offset: Int {
        //            get {
        //                switch self {
        //                case .insert(offset: let o, element: _, associatedWith: _):
        //                    return o
        //                case .remove(offset: let o, element: _, associatedWith: _):
        //                    return o
        //                }
        //            }
        //        }
        //        internal var _element: ChangeElement {
        //            get {
        //                switch self {
        //                case .insert(offset: _, element: let e, associatedWith: _):
        //                    return e
        //                case .remove(offset: _, element: let e, associatedWith: _):
        //                    return e
        //                }
        //            }
        //        }
        //        internal var _associatedOffset: Int? {
        //            get {
        //                switch self {
        //                case .insert(offset: _, element: _, associatedWith: let o):
        //                    return o
        //                case .remove(offset: _, element: _, associatedWith: let o):
        //                    return o
        //                }
        //            }
        //        }
    }

    /// The insertions contained by this difference, from lowest offset to
    /// highest.
    public let insertions: [CompatibilityCollectionDifference<ChangeElement>.Change]

    /// The removals contained by this difference, from lowest offset to highest.
    public let removals: [CompatibilityCollectionDifference<ChangeElement>.Change]

    public init?<Changes>(_ changes: Changes)
    where
        Changes: Collection,
        Changes.Element == CompatibilityCollectionDifference<ChangeElement>.Change
    {
        var _insertions: [CompatibilityCollectionDifference<ChangeElement>.Change] = []
        var _removals: [CompatibilityCollectionDifference<ChangeElement>.Change] = []
        changes.forEach { change in
            switch change {
            case .insert:
                _insertions.append(change)
            case .remove:
                _removals.append(change)
            }
        }
        self.insertions = _insertions
        self.removals = _removals
    }
    //    public init?<Changes: Collection>(
    //        _ changes: Changes
    //    ) where Changes.Element == Change {
    //        guard CompatibilityCollectionDifference<ChangeElement>._validateChanges(changes) else {
    //            return nil
    //        }
    //
    //        self.init(_validatedChanges: changes)
    //    }
    //
    //    /// Internal initializer for use by algorithms that cannot produce invalid
    //    /// collections of changes. These include the Myers' diff algorithm,
    //    /// self.inverse(), and the move inferencer.
    //    ///
    //    /// If parameter validity cannot be guaranteed by the caller then
    //    /// `CollectionDifference.init?(_:)` should be used instead.
    //    ///
    //    /// - Parameter c: A valid collection of changes that represent a transition
    //    ///   between two states.
    //    ///
    //    /// - Complexity: O(*n* * log(*n*)), where *n* is the length of the
    //    ///   parameter.
    //    internal init<Changes: Collection>(
    //        _validatedChanges changes: Changes
    //    ) where Changes.Element == Change {
    //        let sortedChanges = changes.sorted { (a, b) -> Bool in
    //            switch (a, b) {
    //            case (.remove(_, _, _), .insert(_, _, _)):
    //                return true
    //            case (.insert(_, _, _), .remove(_, _, _)):
    //                return false
    //            default:
    //                return a._offset < b._offset
    //            }
    //        }
    //
    //        // Find first insertion via binary search
    //        let firstInsertIndex: Int
    //        if sortedChanges.isEmpty {
    //            firstInsertIndex = 0
    //        } else {
    //            var range = 0...sortedChanges.count
    //            while range.lowerBound != range.upperBound {
    //                let i = (range.lowerBound + range.upperBound) / 2
    //                switch sortedChanges[i] {
    //                case .insert(_, _, _):
    //                    range = range.lowerBound...i
    //                case .remove(_, _, _):
    //                    range = (i + 1)...range.upperBound
    //                }
    //            }
    //            firstInsertIndex = range.lowerBound
    //        }
    //
    //        removals = Array(sortedChanges[0..<firstInsertIndex])
    //        insertions = Array(sortedChanges[firstInsertIndex..<sortedChanges.count])
    //    }
    //
    //    /// The public initializer calls this function to ensure that its parameter
    //    /// meets the conditions set in its documentation.
    //    ///
    //    /// - Parameter changes: a collection of `CollectionDifference.Change`
    //    ///   instances intended to represent a valid state transition for
    //    ///   `CollectionDifference`.
    //    ///
    //    /// - Returns: whether the parameter meets the following criteria:
    //    ///
    //    ///   1. All insertion offsets are unique
    //    ///   2. All removal offsets are unique
    //    ///   3. All associations between insertions and removals are symmetric
    //    ///
    //    /// Complexity: O(`changes.count`)
    //    private static func _validateChanges<Changes: Collection>(
    //        _ changes : Changes
    //    ) -> Bool where Changes.Element == Change {
    //        if changes.isEmpty { return true }
    //
    //        var insertAssocToOffset = Dictionary<Int,Int>()
    //        var removeOffsetToAssoc = Dictionary<Int,Int>()
    //        var insertOffset = Set<Int>()
    //        var removeOffset = Set<Int>()
    //
    //        for change in changes {
    //            let offset = change._offset
    //            if offset < 0 { return false }
    //
    //            switch change {
    //            case .remove(_, _, _):
    //                if removeOffset.contains(offset) { return false }
    //                removeOffset.insert(offset)
    //            case .insert(_, _, _):
    //                if insertOffset.contains(offset) { return false }
    //                insertOffset.insert(offset)
    //            }
    //
    //            if let assoc = change._associatedOffset {
    //                if assoc < 0 { return false }
    //                switch change {
    //                case .remove(_, _, _):
    //                    if removeOffsetToAssoc[offset] != nil { return false }
    //                    removeOffsetToAssoc[offset] = assoc
    //                case .insert(_, _, _):
    //                    if insertAssocToOffset[assoc] != nil { return false }
    //                    insertAssocToOffset[assoc] = offset
    //                }
    //            }
    //        }
    //
    //        return removeOffsetToAssoc == insertAssocToOffset
    //    }
}

// _V is a rudimentary type made to represent the rows of the triangular matrix type used by the Myer's algorithm
//
// This type is basically an array that only supports indexes in the set `stride(from: -d, through: d, by: 2)` where `d` is the depth of this row in the matrix
// `d` is always known at allocation-time, and is used to preallocate the structure.
private struct _V {

    private var a: [Int]

    // The way negative indexes are implemented is by interleaving them in the empty slots between the valid positive indexes
    @inline(__always) private static func transform(_ index: Int) -> Int {
        // -3, -1, 1, 3 -> 3, 1, 0, 2 -> 0...3
        // -2, 0, 2 -> 2, 0, 1 -> 0...2
        return (index <= 0 ? -index : index &- 1)
    }

    init(maxIndex largest: Int) {
        a = [Int](repeating: 0, count: largest + 1)
    }

    subscript(index: Int) -> Int {
        get {
            return a[_V.transform(index)]
        }
        set(newValue) {
            a[_V.transform(index)] = newValue
        }
    }
}

internal func myers<C, D>(
    from old: C, to new: D,
    using cmp: (C.Element, D.Element) -> Bool
) -> CompatibilityCollectionDifference<C.Element>
where
    C: BidirectionalCollection,
    D: BidirectionalCollection,
    C.Element == D.Element
{

    // Core implementation of the algorithm described at http://www.xmailserver.org/diff2.pdf
    // Variable names match those used in the paper as closely as possible
    func _descent(from a: UnsafeBufferPointer<C.Element>, to b: UnsafeBufferPointer<D.Element>)
        -> [_V]
    {
        let n = a.count
        let m = b.count
        let max = n + m

        var result = [_V]()
        var v = _V(maxIndex: 1)
        v[1] = 0

        var x = 0
        var y = 0
        iterator: for d in 0...max {
            let prev_v = v
            result.append(v)
            v = _V(maxIndex: d)

            // The code in this loop is _very_ hot—the loop bounds increases in terms
            // of the iterator of the outer loop!
            for k in stride(from: -d, through: d, by: 2) {
                if k == -d {
                    x = prev_v[k &+ 1]
                } else {
                    let km = prev_v[k &- 1]

                    if k != d {
                        let kp = prev_v[k &+ 1]
                        if km < kp {
                            x = kp
                        } else {
                            x = km &+ 1
                        }
                    } else {
                        x = km &+ 1
                    }
                }
                y = x &- k

                while x < n && y < m {
                    if !cmp(a[x], b[y]) {
                        break
                    }
                    x &+= 1
                    y &+= 1
                }

                v[k] = x

                if x >= n && y >= m {
                    break iterator
                }
            }
            if x >= n && y >= m {
                break
            }
        }

        return result
    }

    // Backtrack through the trace generated by the Myers descent to produce the changes that make up the diff
    func _formChanges(
        from a: UnsafeBufferPointer<C.Element>,
        to b: UnsafeBufferPointer<C.Element>,
        using trace: [_V]
    ) -> [CompatibilityCollectionDifference<C.Element>.Change] {
        var changes = [CompatibilityCollectionDifference<C.Element>.Change]()

        var x = a.count
        var y = b.count
        for d in stride(from: trace.count &- 1, to: 0, by: -1) {
            let v = trace[d]
            let k = x &- y
            let prev_k = (k == -d || (k != d && v[k &- 1] < v[k &+ 1])) ? k &+ 1 : k &- 1
            let prev_x = v[prev_k]
            let prev_y = prev_x &- prev_k

            while x > prev_x && y > prev_y {
                // No change at this position.
                x &-= 1
                y &-= 1
            }

            assert((x == prev_x && y > prev_y) || (y == prev_y && x > prev_x))
            if y != prev_y {
                changes.append(.insert(offset: prev_y, element: b[prev_y], associatedWith: nil))
            } else {
                changes.append(.remove(offset: prev_x, element: a[prev_x], associatedWith: nil))
            }

            x = prev_x
            y = prev_y
        }

        return changes
    }

    /* Splatting the collections into contiguous storage has two advantages:
   *
   *   1) Subscript access is much faster
   *   2) Subscript index becomes Int, matching the iterator types in the algorithm
   *
   * Combined, these effects dramatically improves performance when
   * collections differ significantly, without unduly degrading runtime when
   * the parameters are very similar.
   *
   * In terms of memory use, the linear cost of creating a ContiguousArray (when
   * necessary) is significantly less than the worst-case n² memory use of the
   * descent algorithm.
   */
    func _withContiguousStorage<C: Collection, R>(
        for values: C,
        _ body: (UnsafeBufferPointer<C.Element>) throws -> R
    ) rethrows -> R {
        if let result = try values.withContiguousStorageIfAvailable(body) { return result }
        let array = ContiguousArray(values)
        return try array.withUnsafeBufferPointer(body)
    }

    return _withContiguousStorage(for: old) { a in
        return _withContiguousStorage(for: new) { b in
            return CompatibilityCollectionDifference(
                _formChanges(from: a, to: b, using: _descent(from: a, to: b)))!
        }
    }
}

extension Array {
    // For iOS < 13
    internal func differenceCompatibility<C>(
        from other: C, by areEquivalent: (C.Element, Element) -> Bool
    ) -> CompatibilityCollectionDifference<Element>
    where C: BidirectionalCollection, Element == C.Element {
        myers(from: other, to: self, using: areEquivalent)
    }
}
