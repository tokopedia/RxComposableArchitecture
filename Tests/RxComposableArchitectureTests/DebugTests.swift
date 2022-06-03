import RxComposableArchitecture
import RxSwift
import XCTest

@testable import RxComposableArchitecture

internal final class DebugTests: XCTestCase {
    internal func testCollection() {
        XCTAssertEqual(
            debugOutput([1, 2, 3]),
            """
            [
              1,
              2,
              3,
            ]
            """
        )

        XCTAssertEqual(
            debugOutput([[1, 2, 3], [4, 5, 6]]),
            """
            [
              [
                1,
                2,
                3,
              ],
              [
                4,
                5,
                6,
              ],
            ]
            """
        )
    }

    internal func testSet() {
        XCTAssertEqual(
            debugOutput(Set([1, 2, 3])),
            """
            Set([
              1,
              2,
              3,
            ])
            """
        )

        XCTAssertEqual(
            debugOutput(
                Set([
                    Set([1, 2, 3]),
                    Set([4, 5, 6])
                ])
            ),
            """
            Set([
              Set([
                1,
                2,
                3,
              ]),
              Set([
                4,
                5,
                6,
              ]),
            ])
            """
        )
    }

    internal func testDictionary() {
        XCTAssertEqual(
            debugOutput(["Blob": 1, "Blob Jr.": 2, "Blob Sr.": 3]),
            """
            [
              "Blob Jr.": 2,
              "Blob Sr.": 3,
              "Blob": 1,
            ]
            """
        )

        XCTAssertEqual(
            debugOutput([1: ["Blob": 1], 2: ["Blob Jr.": 2], 3: ["Blob Sr.": 3]]),
            """
            [
              1: [
                "Blob": 1,
              ],
              2: [
                "Blob Jr.": 2,
              ],
              3: [
                "Blob Sr.": 3,
              ],
            ]
            """
        )
    }

    internal func testTuple() {
        XCTAssertEqual(
            debugOutput((1, "2", 3.0)),
            """
            (
              1,
              "2",
              3.0
            )
            """
        )

        XCTAssertEqual(
            debugOutput(((1, "2", 3.0), ("4" as Character, "5" as UnicodeScalar))),
            """
            (
              (
                1,
                "2",
                3.0
              ),
              (
                "4",
                "5"
              )
            )
            """
        )

        XCTAssertEqual(
            debugOutput(()),
            """
            ()
            """
        )
    }

    internal func testStruct() {
        struct User {
            var id: Int
            var name: String
        }

        XCTAssertEqual(
            debugOutput(
                User(id: 1, name: "Blob")
            ),
            """
            User(
              id: 1,
              name: "Blob"
            )
            """
        )
    }

    internal func testClass() {
        class User {
            var id = 1
            var name = "Blob"
        }

        XCTAssertEqual(
            debugOutput(User()),
            """
            User(
              id: 1,
              name: "Blob"
            )
            """
        )
    }

    internal func testEnum() {
        enum Enum {
            case caseWithNoAssociatedValues
            case caseWithOneAssociatedValue(Int)
            case caseWithOneLabeledAssociatedValue(one: Int)
            case caseWithTwoLabeledAssociatedValues(one: Int, two: String)
            case caseWithTuple((one: Int, two: String))
        }

        XCTAssertEqual(
            debugOutput(Enum.caseWithNoAssociatedValues),
            """
            Enum.caseWithNoAssociatedValues
            """
        )
        XCTAssertEqual(
            debugOutput(Enum.caseWithOneAssociatedValue(1)),
            """
            Enum.caseWithOneAssociatedValue(
              1
            )
            """
        )
        XCTAssertEqual(
            debugOutput(Enum.caseWithOneLabeledAssociatedValue(one: 1)),
            """
            Enum.caseWithOneLabeledAssociatedValue(
              one: 1
            )
            """
        )
        XCTAssertEqual(
            debugOutput(Enum.caseWithTwoLabeledAssociatedValues(one: 1, two: "Blob")),
            """
            Enum.caseWithTwoLabeledAssociatedValues(
              one: 1,
              two: "Blob"
            )
            """
        )
        // NB: Fails due to https://bugs.swift.org/browse/SR-12409
        //    XCTAssertEqual(
        //      debugOutput(Enum.caseWithTuple((one: 1, two: "Blob"))),
        //      """
        //      Enum.caseWithTuple(
        //        (
        //          one: 1,
        //          two: "Blob"
        //        )
        //      )
        //      """
        //    )
    }

    internal func testObject() {
        XCTAssertEqual(
            debugOutput(NSObject()),
            """
            NSObject()
            """
        )
    }

    internal func testDebugOutputConvertible() {
        XCTAssertEqual(
            debugOutput(Date(timeIntervalSinceReferenceDate: 0)),
            "Date(2001-01-01T00:00:00.000Z)"
        )
        XCTAssertEqual(
            debugOutput(URL(string: "https://www.pointfree.co")!),
            "https://www.pointfree.co"
        )
        XCTAssertEqual(
            debugOutput(DispatchQueue.main),
            "DispatchQueue.main"
        )
        XCTAssertEqual(
            debugOutput(DispatchQueue.global()),
            "DispatchQueue.global()"
        )
        XCTAssertEqual(
            debugOutput(DispatchQueue.global(qos: .background)),
            "DispatchQueue.global(qos: .background)"
        )
        XCTAssertEqual(
            debugOutput(DispatchQueue(label: "co.pointfree", qos: .background)),
            #"DispatchQueue(label: "co.pointfree", qos: .background)"#
        )
        XCTAssertEqual(
            debugOutput(OperationQueue.main),
            "OperationQueue.main"
        )
        XCTAssertEqual(
            debugOutput(OperationQueue()),
            "OperationQueue()"
        )
        XCTAssertEqual(
            debugOutput(RunLoop.main),
            "RunLoop.main"
        )
    }

    #if compiler(<5.5)
        internal func testNestedDump() {
            struct User {
                var id: UUID
                var name: String
                var createdAt: Date
                var favoritePrimes: [Int]
                var friends: [User]
            }

            enum AppState {
                case loggedOut(login: String, password: String)
                case loggedIn(User)
            }

            XCTAssertEqual(
                debugOutput(
                    AppState.loggedIn(
                        User(
                            id: UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!,
                            name: "Blob",
                            createdAt: Date(timeIntervalSinceReferenceDate: 0),
                            favoritePrimes: [7, 11],
                            friends: [
                                User(
                                    id: UUID(uuidString: "CAFEBEEF-CAFE-BEEF-CAFE-BEEFCAFEBEEF")!,
                                    name: "Blob Jr.",
                                    createdAt: Date(timeIntervalSinceReferenceDate: 60 * 60 * 24 * 365),
                                    favoritePrimes: [2, 3, 5],
                                    friends: []
                                ),
                                User(
                                    id: UUID(uuidString: "D00DBEEF-D00D-BEEF-D00D-BEEFD00DBEEF")!,
                                    name: "Blob Sr.",
                                    createdAt: Date(timeIntervalSinceReferenceDate: 60 * 60 * 48 * 365),
                                    favoritePrimes: [23],
                                    friends: []
                                )
                            ]
                        )
                    )
                ),
                """
                AppState.loggedIn(
                  User(
                    id: DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF,
                    name: "Blob",
                    createdAt: 2001-01-01T00:00:00Z,
                    favoritePrimes: [
                      7,
                      11,
                    ],
                    friends: [
                      User(
                        id: CAFEBEEF-CAFE-BEEF-CAFE-BEEFCAFEBEEF,
                        name: "Blob Jr.",
                        createdAt: 2002-01-01T00:00:00Z,
                        favoritePrimes: [
                          2,
                          3,
                          5,
                        ],
                        friends: [
                        ]
                      ),
                      User(
                        id: D00DBEEF-D00D-BEEF-D00D-BEEFD00DBEEF,
                        name: "Blob Sr.",
                        createdAt: 2003-01-01T00:00:00Z,
                        favoritePrimes: [
                          23,
                        ],
                        friends: [
                        ]
                      ),
                    ]
                  )
                )
                """
            )
        }
    #endif

    internal func testRecursiveOutput() {
        class Foo {
            var foo: Foo?
        }
        let foo = Foo()
        foo.foo = foo
        XCTAssertEqual(
            debugOutput(foo),
            """
            Foo(
              foo: Foo(↩︎)
            )
            """
        )
    }

    internal func testStructDiff() {
        let before = """
        AppState(
          login: LoginState(
            alertData: nil,
            email: "blob@pointfree.co",
            isFormValid: true,
            isLoginRequestInFlight: true,
            password: "password",
            twoFactor: nil
          ),
          newGame: nil
        )
        """

        let after = """
        AppState(
          login: nil,
          newGame: NewGameState(
            game: nil,
            oPlayerName: "",
            xPlayerName: ""
          )
        )
        """

        XCTAssertEqual(
            debugDiff(before, after, printer: { $0 })!,
            """
              AppState(
            −   login: LoginState(
            −     alertData: nil,
            −     email: "blob@pointfree.co",
            −     isFormValid: true,
            −     isLoginRequestInFlight: true,
            −     password: "password",
            −     twoFactor: nil
            −   ),
            −   newGame: nil
            +   login: nil,
            +   newGame: NewGameState(
            +     game: nil,
            +     oPlayerName: "",
            +     xPlayerName: ""
            +   )
              )
            """
        )
    }

    internal func testArrayDiff() {
        let before = """
        [
          Todo(
            isComplete: true,
            description: "Milk",
            id: 00000000-0000-0000-0000-000000000000
          ),
          Todo(
            isComplete: false,
            description: "Eggs",
            id: 00000000-0000-0000-0000-000000000001
          ),
        ]
        """

        let after = """
        [
          Todo(
            isComplete: false,
            description: "Eggs",
            id: 00000000-0000-0000-0000-000000000001
          ),
          Todo(
            isComplete: true,
            description: "Milk",
            id: 00000000-0000-0000-0000-000000000000
          ),
        ]
        """

        XCTAssertEqual(
            debugDiff(before, after, printer: { $0 })!,
            """
              [
            −   Todo(
            −     isComplete: true,
            −     description: "Milk",
            −     id: 00000000-0000-0000-0000-000000000000
            −   ),
                Todo(
                  isComplete: false,
                  description: "Eggs",
                  id: 00000000-0000-0000-0000-000000000001
                ),
            +   Todo(
            +     isComplete: true,
            +     description: "Milk",
            +     id: 00000000-0000-0000-0000-000000000000
            +   ),
              ]
            """
        )
    }

    internal func testComplexDiff() {
        let before = """
        AppState(
          login: LoginState(
            alertData: nil,
            email: "blob@pointfree.co",
            isFormValid: true,
            isLoginRequestInFlight: true,
            password: "password",
            twoFactor: nil
          ),
          newGame: nil,
          todos: [
            Todo(
              isComplete: true,
              description: "Milk",
              id: 00000000-0000-0000-0000-000000000000
            ),
            Todo(
              isComplete: false,
              description: "Eggs",
              id: 00000000-0000-0000-0000-000000000001
            ),
          ]
        )
        """

        let after = """
        AppState(
          login: nil,
          newGame: NewGameState(
            game: nil,
            oPlayerName: "",
            xPlayerName: ""
          ),
          todos: [
            Todo(
              isComplete: false,
              description: "Eggs",
              id: 00000000-0000-0000-0000-000000000001
            ),
            Todo(
              isComplete: true,
              description: "Milk",
              id: 00000000-0000-0000-0000-000000000000
            ),
          ]
        )
        """

        XCTAssertEqual(
            debugDiff(before, after, printer: { $0 })!,
            """
              AppState(
            −   login: LoginState(
            −     alertData: nil,
            −     email: "blob@pointfree.co",
            −     isFormValid: true,
            −     isLoginRequestInFlight: true,
            −     password: "password",
            −     twoFactor: nil
            +   login: nil,
            +   newGame: NewGameState(
            +     game: nil,
            +     oPlayerName: "",
            +     xPlayerName: ""
                ),
            −   newGame: nil,
                todos: [
            −     Todo(
            −       isComplete: true,
            −       description: "Milk",
            −       id: 00000000-0000-0000-0000-000000000000
            −     ),
                  Todo(
                    isComplete: false,
                    description: "Eggs",
                    id: 00000000-0000-0000-0000-000000000001
                  ),
            +     Todo(
            +       isComplete: true,
            +       description: "Milk",
            +       id: 00000000-0000-0000-0000-000000000000
            +     ),
                ]
              )
            """
        )
    }

    internal func testComplexDiff3() {
        let before = """
        B
        B
        """

        let after = """
        A
        B
        """

        XCTAssertEqual(
            debugDiff(before, after, printer: { $0 })!,
            """
            − B
            + A
              B
            """
        )
    }

    internal func testDebugCaseOutput() {
        enum Action {
            case action1(Bool, label: String)
            case action2(Bool, Int, String)
            case screenA(ScreenA)

            enum ScreenA {
                case row(index: Int, action: RowAction)

                enum RowAction {
                    case tapped
                    case textChanged(query: String)
                }
            }
        }

        XCTAssertEqual(
            debugCaseOutput(Action.action1(true, label: "Blob")),
            "Action.action1(_:, label:)"
        )

        XCTAssertEqual(
            debugCaseOutput(Action.action2(true, 1, "Blob")),
            "Action.action2(_:, _:, _:)"
        )

        XCTAssertEqual(
            debugCaseOutput(Action.screenA(.row(index: 1, action: .tapped))),
            "Action.screenA(.row(index:, action: .tapped))"
        )

        XCTAssertEqual(
            debugCaseOutput(Action.screenA(.row(index: 1, action: .textChanged(query: "Hi")))),
            "Action.screenA(.row(index:, action: .textChanged(query:)))"
        )
    }

    internal func testDebugOutput() {
        enum Action {
            case action1(Bool, label: String)
            case action2(Bool, Int, String)
            case screenA(ScreenA)

            enum ScreenA {
                case row(index: Int, action: RowAction)

                enum RowAction {
                    case tapped
                    case textChanged(query: String)
                }
            }
        }

        XCTAssertEqual(
            debugOutput(Action.action1(true, label: "Blob")),
            """
            Action.action1(
              true,
              label: "Blob"
            )
            """
        )

        XCTAssertEqual(
            debugOutput(Action.action2(true, 1, "Blob")),
            """
            Action.action2(
              true,
              1,
              "Blob"
            )
            """
        )

        XCTAssertEqual(
            debugOutput(Action.screenA(.row(index: 1, action: .tapped))),
            """
            Action.screenA(
              ScreenA.row(
                index: 1,
                action: RowAction.tapped
              )
            )
            """
        )

        XCTAssertEqual(
            debugOutput(Action.screenA(.row(index: 1, action: .textChanged(query: "Hi")))),
            """
            Action.screenA(
              ScreenA.row(
                index: 1,
                action: RowAction.textChanged(
                  query: "Hi"
                )
              )
            )
            """
        )
    }
}
