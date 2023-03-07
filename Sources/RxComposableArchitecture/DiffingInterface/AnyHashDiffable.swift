//
//  AnyHashDiffable.swift
//  DiffingInterface
//
//  Created by Edho Prasetyo on 24/09/20.
//

/// A type-erased `Identifiable` value.
///
/// The `AnyHashDiffable` wrap the `HashDiffableProtocol` associatedType
///
/// If you want to use multiple element of array model conforming `Identifiable`, you can't directly call
///
///     let myArrayData = [Identifiable]()
///
/// Instead you wrap it like this:
///
///     let source = [
///         AnyHashDiffable("ABC"),
///         AnyHashDiffable(100)
///     ]
///

public struct AnyHashDiffable: Identifiable, Equatable {
    /// The value of `Diffable` wrapped by this instance.
    public var base: any Equatable {
        return box.base
    }

    /// A type-erased identifier value for difference calculation.
    public var id: AnyHashable {
        return box.id
    }

    internal let box: AnyHashDiffableBox
    /// Creates a type-erased `Identifiable` value that wraps the given instance.
    ///
    /// - Parameters:
    ///   - base: A differentiable value to wrap.
    public init<D: Identifiable & Equatable>(_ base: D) {
        /// Condition to handle if accidentaly `AnyHashDiffable` being wrapped in another `AnyHashDiffable` again.
        if let anyDifferentiable = base as? AnyHashDiffable {
            self = anyDifferentiable
        } else {
            box = HashDiffableBox(base)
        }
    }
    
    public static func == (lhs: AnyHashDiffable, rhs: AnyHashDiffable) -> Bool {
        lhs.box.isEqual(to: rhs.box)
    }
}

extension AnyHashDiffable: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "AnyHashDiffable(\(String(reflecting: base)))"
    }
}

internal protocol AnyHashDiffableBox {
    var base: any Equatable { get }
    var id: AnyHashable { get }

    func isEqual(to source: AnyHashDiffableBox) -> Bool
}

internal struct HashDiffableBox<Base: Identifiable & Equatable>: AnyHashDiffableBox {
    internal let baseComponent: Base

    internal var base: any Equatable {
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
        return baseComponent == sourceBase
    }
}
