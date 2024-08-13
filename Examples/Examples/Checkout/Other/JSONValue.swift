//
//  JSONValue.swift
//  Examples
//
//  Created by jefferson.setiawan on 21/03/24.
//

import Foundation

public enum JSONValue: Equatable {
    case string(String)
    case number(NSNumber)
    case object([String: JSONValue])
    case array([JSONValue?])
    case bool(Bool)
}

public enum JSONValueError: Error {
    case invalid
}

extension JSONValue {
    public static func from(rawDictionary dict: [String: Any]) -> Result<JSONValue, JSONValueError> {
        var newDict = [String: JSONValue]()
        for (key, value) in dict {
            let eventValue: Result<JSONValue?, JSONValueError> = convertObjectToJSONValue(value: value)

            switch eventValue {
            case let .success(value):
                if let value = value {
                    newDict[key] = value
                }
            case .failure:
                return .failure(.invalid)
            }
        }

        return .success(.object(newDict))
    }

    private static func convertObjectToJSONValue(value: Any) -> Result<JSONValue?, JSONValueError> {
        switch value {
        case let data as Data:
            do {
                let object = try JSONSerialization.jsonObject(with: data, options: [])
                return convertObjectToJSONValue(value: object)
            } catch {
                return .failure(.invalid)
            }

        case let array as [Any]:
            var eventArray: [JSONValue?] = []

            for item in array {
                let eventValue = convertObjectToJSONValue(value: item)

                switch eventValue {
                case let .success(value):
                    eventArray.append(value)
                case .failure:
                    return eventValue
                }
            }

            return .success(.array(eventArray))

        case let dict as [String: Any]:
            return from(rawDictionary: dict).map(Optional.init)

        case let string as String:
            return .success(.string(string))

        case let number as NSNumber:
            /// `Bool`, `Int`, `Double` and `Float` will be considered as `NSNumber`
            /// `1` and `true` will also be considered as `NSNumber`
            /// To differentiate the output, casted `NSNumber` need to have another conditional check
            if number.isBoolean {
                return .success(.bool(number.boolValue))
            } else {
                return .success(.number(number))
            }

        case let value as Any?:
            switch value {
            case .some:
                return .failure(.invalid)
            case .none:
                return .success(nil)
            }
        default:
            return .failure(.invalid)
        }
    }

    public static func int(_ value: Int) -> JSONValue {
        return .number(NSNumber(value: value))
    }

    public static func int(_ value: Int64) -> JSONValue {
        return .number(NSNumber(value: value))
    }

    public static func double(_ value: Double) -> JSONValue {
        return .number(NSNumber(value: value))
    }

    public static func float(_ value: Float) -> JSONValue {
        return .number(NSNumber(value: value))
    }
}

private extension NSNumber {
    var isBoolean: Bool {
        return NSNumber(value: true).objCType == objCType
    }
}

extension JSONValue {
    public func extractValue() -> Any? {
        switch self {
        case let .number(number):
            return number.isBoolean ? number.boolValue : number.doubleValue
        case let .string(value):
            return value
        case let .bool(value):
            return value
        case let .object(dict):
            var formedDict: [String: Any] = [:]
            for (key, object) in dict {
                formedDict[key] = object.extractValue() as Any
            }
            return formedDict
        case let .array(array):
            var formedArray: [Any] = []
            for jsonValue in array {
                formedArray.append(jsonValue?.extractValue() as Any)
            }
            return formedArray
        }
    }

    public func toDictionary() -> [String: Any] {
        let value = (extractValue() as? [String: Any]) ?? [:]
        return value
    }
}

extension Dictionary where Key == String, Value == JSONValue {
    public func getTheDictionaryAttribute() -> [String: Any] {
        let compactDic = compactMap { $0 }
        var dic = [String: Any]()
        for attribute in compactDic {
            dic[attribute.key] = attribute.value.extractValue()
        }
        return dic
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int
    public init(integerLiteral value: Int) {
        self = .number(NSNumber(value: value))
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public typealias FloatLiteralType = Double
    public init(floatLiteral value: Double) {
        self = .number(NSNumber(value: value))
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public typealias BooleanLiteralType = Bool
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = JSONValue?
    public init(arrayLiteral elements: JSONValue?...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = JSONValue

    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        var dict = [Key: Value]()
        elements.forEach { key, value in
            dict[key] = value
        }

        self = .object(dict)
    }
}
