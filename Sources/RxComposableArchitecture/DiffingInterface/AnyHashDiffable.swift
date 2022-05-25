//
//  AnyHashDiffable.swift
//  DiffingInterface
//
//  Created by Edho Prasetyo on 24/09/20.
//

/// A type-erased `HashDiffable` value.
///
/// The `AnyHashDiffable` wrap the `HashDiffableProtocol` associatedType
///
/// If you want to use multiple element of array model conforming `HashDiffable`, you can't directly call
///
///     let myArrayData = [HashDiffable]()
///
/// Instead you wrap it like this:
///
///     let source = [
///         AnyHashDiffable("ABC"),
///         AnyHashDiffable(100)
///     ]
///

public struct AnyHashDiffable: HashDiffable {
    /// The value of `Diffable` wrapped by this instance.
    public var base: Any {
        return box.base
    }

    /// A type-erased identifier value for difference calculation.
    public var id: AnyHashable {
        return box.id
    }

    internal let box: AnyHashDiffableBox

    /// Creates a type-erased `HashDiffable` value that wraps the given instance.
    ///
    /// - Parameters:
    ///   - base: A differentiable value to wrap.
    public init<D: HashDiffable>(_ base: D) {
        /// Condition to handle if accidentaly `AnyHashDiffable` being wrapped in another `AnyHashDiffable` again.
        if let anyDifferentiable = base as? AnyHashDiffable {
            self = anyDifferentiable
        } else {
            box = HashDiffableBox(base)
        }
    }

    /// Indicate whether the content of `base` is equals to the content of the given source value.
    ///
    /// - Parameters:
    ///   - source: A source value to be compared.
    ///
    ///   - Returns: A Boolean value indicating whether the content of `base` is equals
    ///            to the content of `base` of the given source value.
    public func isEqual(to source: AnyHashDiffable) -> Bool {
        return box.isEqual(to: source.box)
    }
}

extension AnyHashDiffable: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "AnyHashDiffable(\(String(reflecting: base)))"
    }
}

internal protocol AnyHashDiffableBox {
    var base: Any { get }
    var id: AnyHashable { get }

    func isEqual(to source: AnyHashDiffableBox) -> Bool
}

internal struct HashDiffableBox<Base: HashDiffable>: AnyHashDiffableBox {
    internal let baseComponent: Base

    internal var base: Any {
        return baseComponent
    }

    internal var id: AnyHashable {
        return baseComponent.id
    }

    internal init(_ base: Base) {
        baseComponent = base
    }

    internal func isEqual(to source: AnyHashDiffableBox) -> Bool {
        guard let sourceBase = source.base as? Base else {
            return false
        }
        return baseComponent.isEqual(to: sourceBase)
    }
}
