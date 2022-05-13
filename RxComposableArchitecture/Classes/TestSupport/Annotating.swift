//
//  Annotating.swift
//  TestSupport
//
//  Created by Wendy Liga on 24/09/20.
//

#if DEBUG
    extension TestStore.Annotating {
        public static var activity: Self {
            Self { step, groupLevel, callback in
                func runActivity(named name: String) {
                    callback { _ in }
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
