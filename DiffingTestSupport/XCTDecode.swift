//
//  XCTDecode.swift
//  Tests
//
//  Created by Kensen on 12/07/21.
//

import XCTest

public func XCTDecode<T>(_ type: T.Type, from data: Data, atKeyPath keyPath: String? = nil, file: StaticString = #file, line: UInt = #line) throws -> T where T: Decodable {
    do {
        if let keyPath = keyPath {
            let topLevel = try JSONSerialization.jsonObject(with: data)

            if let nestedJson = (topLevel as AnyObject).value(forKeyPath: keyPath) {
                let nestedJsonData = try JSONSerialization.data(withJSONObject: nestedJson)
                return try JSONDecoder().decode(type, from: nestedJsonData)
            } else {
                let debugDescription = "Nested JSON not found for key path \"\(keyPath)\""
                let decodingError = DecodingError.dataCorrupted(
                    .init(
                        codingPath: [],
                        debugDescription: debugDescription
                    )
                )

                XCTFail(debugDescription, file: file, line: line)
                throw decodingError
            }
        } else {
            return try JSONDecoder().decode(type, from: data)
        }
    } catch {
        guard let decodingError = error as? DecodingError else {
            XCTFail(error.localizedDescription, file: file, line: line)
            throw error
        }

        switch decodingError {
        case let .dataCorrupted(context), let .keyNotFound(_, context), let .typeMismatch(_, context), let .valueNotFound(_, context):
            let codingPath: String = context.codingPath.map(\.stringValue).joined(separator: ".")

            let failMessage: String
            if codingPath.isEmpty {
                failMessage = context.debugDescription
            } else {
                failMessage = "\(context.debugDescription) (codingPath: \"\(codingPath)\")"
            }

            XCTFail(failMessage, file: file, line: line)
        @unknown default:
            XCTFail(decodingError.localizedDescription, file: file, line: line)
        }

        throw decodingError
    }
}
