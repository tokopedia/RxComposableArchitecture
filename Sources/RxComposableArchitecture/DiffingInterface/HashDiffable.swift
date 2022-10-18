//
//  HashDiffableProtocol.swift
//  DiffingInterface
//
//  Created by Edho Prasetyo on 24/09/20.
//

public protocol HashDiffable {
    associatedtype IdentifierType: Hashable
    var id: Self.IdentifierType { get }
    func isEqual(to source: Self) -> Bool
}

extension HashDiffable where Self: Hashable {
    /// The `self` value as an identifier for difference calculation.
    public var id: Self {
        return self
    }
}

extension HashDiffable where Self: Equatable {
    public func isEqual(to source: Self) -> Bool {
        return self == source
    }
}
