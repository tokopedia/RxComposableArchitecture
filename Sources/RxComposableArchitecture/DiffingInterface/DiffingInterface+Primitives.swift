//
//  DiffingInterface+Primitives.swift
//  DiffingInterface
//
//  Created by Edho Prasetyo on 25/09/20.
//

extension Int: HashDiffable {
    public var id: Int {
        return self
    }
}

extension String: HashDiffable {
    public var id: String {
        return self
    }
}

extension Bool: HashDiffable {
    public var id: Bool {
        return self
    }
}

extension Double: HashDiffable {
    public var id: Double {
        return self
    }
}

extension Float: HashDiffable {
    public var id: Float {
        return self
    }
}

extension Array where Element == AnyHashDiffable {
    public func removeDuplicates() -> [AnyHashDiffable] {
        /// This table will contain `diffIdentifier` as the `key` and object `type` as the value
        var tableOfIdentifiersType = [AnyHashable: Any.Type]()
        var uniqueObjects = [AnyHashDiffable]()

        let tempSelf = self
        tempSelf.forEach { object in
            /// Get current object identifier
            let currentId = object.id
            /// Get current object type from Type Erasure base object
            let currentObjectType = type(of: object.base)
            /// Check if `currentId` is already registered on `Table Bank of Identifiers Type`
            /// If `yes` > Get object type with current identifier from `Table Bank of Identifiers Type`
            /// If `no` > Then return `nil`
            let previousesObjectType = tableOfIdentifiersType[currentId]

            /// Check wether current object type is the same with previous object type(if exist) fetched from `Table Bank of Identifiers Type`
            /// If `currentId` already exist on `Table Bank of Identifiers Type` but the type is different it's not counted as _**duplicates**_
            if currentObjectType != previousesObjectType {
                tableOfIdentifiersType[currentId] = currentObjectType
                uniqueObjects.append(object)
            }
        }

        return uniqueObjects
    }
}

extension Array where Element: HashDiffable {
    public func removeDuplicates() -> Self {
        /// This table will contain `diffIdentifier` as the `key` and object `type` as the value
        var tableOfObjectType = [AnyHashable: Any.Type]()

        var uniqueObjects = [Element]()

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
