//
//  Annotating.swift
//  TestSupport
//
//  Created by Wendy Liga on 24/09/20.
//

#if DEBUG
    import XCTest

    extension TestStore.Annotating {
        public static var activity: Self {
            Self { step, groupLevel, callback in
                func runActivity(named name: String) {
                    #if BAZEL
                        callback { _ in }
                        /**
                         unit test on bazel doesn't support add custom activity

                         Fatal error: XCTContext.runActivity(named:block:) failed because activities are disallowed in the current configuration.: file /Library/Caches/com.apple.xbs/Sources/XCTest_Sim/XCTest-16091.4/Sources/libXCTestSwiftSupport/XCTContext_SwiftExtensions.swift, line 23
                         */
                        return
                    #endif

                    let indent = String(repeating: "\t", count: groupLevel)

                    XCTContext.runActivity(named: "\(indent)\(name)") { _ in
                        callback { _ in }
                    }
                }

                switch step.type {
                case let .send(action, _):
                    runActivity(named: "send: \(action)")
                case let .receive(action, _):
                    runActivity(named: "receive: \(action)")
                case let .group(name, _):
                    runActivity(named: name)
                default:
                    callback { _ in }
                    return
                }
            }
        }

        public static var console: Self {
            Self { step, groupLevel, callback in
                func console(_ string: String) {
                    let indent = String(repeating: "\t", count: groupLevel)
                    print("\(indent)\(string)")
                }

                switch step.type {
                case let .send(action, _):
                    console("send: \(action)")
                case let .receive(action, _):
                    console("receive: \(action)")
                case let .group(name, _):
                    console("TestStore assert group: '\(name)' started at \(Date())")
                default:
                    return
                }

                callback { stepPassed in
                    console("\t [\(stepPassed ? "PASS" : "FAIL")]")
                }
            }
        }
    }

#endif
