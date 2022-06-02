//
//  TestScheduler.swift
//  RxComposableArchitecture_Tests
//
//  Created by jefferson.setiawan on 13/05/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation
import RxSwift

extension DispatchTimeInterval {
    internal var convertToSecondsFactor: Double {
        switch self {
        case .nanoseconds: return 1_000_000_000.0
        case .microseconds: return 1_000_000.0
        case .milliseconds: return 1000.0
        case .seconds: return 1.0
        case .never: fatalError("Cannot convert never")
        @unknown default: fatalError("Unknown DispatchTimeINtervalValue: \(self)")
        }
    }

    internal var convertToSecondsInterval: Double {
        switch self {
        case let .microseconds(value), let .milliseconds(value), let .seconds(value), let .nanoseconds(value): return Double(value) / convertToSecondsFactor
        default: fatalError("Unsupported DispatchTimeInterval value: \(self)")
        }
    }
}

public struct TestSchedulerVirtualTimeConverter: VirtualTimeConverterType {
    public typealias VirtualTimeUnit = Double

    public typealias VirtualTimeIntervalUnit = DispatchTimeInterval

    public func convertFromVirtualTime(_ virtualTime: Double) -> RxTime {
        Date(timeIntervalSince1970: virtualTime)
    }

    public func convertToVirtualTime(_ time: RxTime) -> Double {
        time.timeIntervalSince1970
    }

    public func convertFromVirtualTimeInterval(_ virtualTimeInterval: DispatchTimeInterval) -> TimeInterval {
        virtualTimeInterval.convertToSecondsInterval
    }

    public func convertToVirtualTimeInterval(_ timeInterval: TimeInterval) -> DispatchTimeInterval {
        .nanoseconds(Int(timeInterval * 1_000_000_000))
    }

    public func offsetVirtualTime(_ time: Double, offset: DispatchTimeInterval) -> Double {
        return time + offset.convertToSecondsInterval
    }

    public func compareVirtualTime(_ lhs: Double, _ rhs: Double) -> VirtualTimeComparison {
        if lhs < rhs {
            return .lessThan
        } else if lhs > rhs {
            return .greaterThan
        } else {
            return .equal
        }
    }
}

public class TestScheduler: _VirtualTimeScheduler<TestSchedulerVirtualTimeConverter> {
    public init(initialClock: Double) {
        super.init(initialClock: initialClock, converter: TestSchedulerVirtualTimeConverter())
    }
}
