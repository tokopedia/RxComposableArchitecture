//
//  XCTPrettyAssertEqual.swift
//  RxComposableArchitecture_TestSupport
//
//  Created by Jefferson Setiawan on 20/01/21.
//

import DiffingUtility
import XCTest

public func XCTPrettyAssertEqual<T>(_ before: T, _ after: T, _ mode: DiffMode = .full, file: StaticString = #file, line: UInt = #line) {
    guard let diff = debugDiff(before, after, mode)
        .map({ "\($0.indent(by: 4))\n\n(Expected: −, Received: +)" }) else { return }
    XCTFail(diff, file: file, line: line)
}
