////
////  UniqueElements.swift
////  RxComposableArchitecture_RxComposableArchitecture
////
////  Created by Kensen on 07/01/21.
////
//
//
///**
// Property wrapper to reduce boiler plate code to remove duplicates from a collection of HashDiffable.
//
// ```
// struct Element: Equatable, HashDiffable {}
//
// struct ParentState: Equatable {
//    @UniqueElements var arrayState: [Element]
//    @UniqueElements var identifiedArrayState: IdentifiedArrayOf<Element>
// }
// ```
//
// Everytime we set arrayState or identifiedArrayState, it will automatically remove all duplicates, making them having only unique elements.
// Using this property wrapper will help reduce data disrepancy between the source of data and components that use them
// */
//
//@propertyWrapper
//public struct UniqueElements<State>: Equatable where State: Collection & Equatable, State.Element: HashDiffable {
//    public var wrappedValue: State {
//        didSet {
//            wrappedValue = Self.getUniqueState(wrappedValue)
//        }
//    }
//
//    public init(wrappedValue: State) {
//        self.wrappedValue = Self.getUniqueState(wrappedValue)
//    }
//
//    private static func getUniqueState(_ state: State) -> State {
//        if let array = state as? [State.Element] {
//            return (array.removeDuplicates() as? State) ?? state
//        } else if let identifiedArray = state as? IdentifiedArrayOf<State.Element> {
//            return (identifiedArray.removeDuplicates() as? State) ?? state
//        } else {
//            assertionFailure("\(type(of: state)) is not supported yet")
//            return state
//        }
//    }
//}
//
//extension UniqueElements: Decodable where State: Decodable {
//    public init(value: State) {
//        wrappedValue = Self.getUniqueState(value)
//    }
//
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        let rawValue = try container.decode(State.self)
//        self.init(value: rawValue)
//    }
//}
