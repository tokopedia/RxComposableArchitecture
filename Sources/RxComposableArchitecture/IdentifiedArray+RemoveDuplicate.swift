//
//  File.swift
//  
//
//  Created by Jefferson Setiawan on 15/08/24.
//

import IdentifiedCollections

extension IdentifiedArrayOf where Element: Identifiable, Element.ID == ID {
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
    
    public var isNotEmpty: Bool {
        return !isEmpty
    }

    @inlinable
    public subscript(safe index: Index) -> Element? {
        guard startIndex <= index, index < endIndex else { return nil }
        return self[index]
    }
}
