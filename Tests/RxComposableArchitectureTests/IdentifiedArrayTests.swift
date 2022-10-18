import XCTest

@testable import RxComposableArchitecture

internal final class IdentifiedArrayTests: XCTestCase {
    internal func testIdSubscript() {
        let array: IdentifiedArray = [User(id: 1, name: "Blob")]

        XCTAssertEqual(array[id: 1], .some(User(id: 1, name: "Blob")))
    }

    internal func testRemoveId() {
        var array: IdentifiedArray = [User(id: 1, name: "Blob")]

        XCTAssertEqual(array.remove(id: 1), User(id: 1, name: "Blob"))
        XCTAssertEqual(array, [])
    }

    internal func testInsert() {
        var array: IdentifiedArray = [User(id: 1, name: "Blob")]

        array.insert(User(id: 2, name: "Blob Jr."), at: 0)
        XCTAssertEqual(array, [User(id: 2, name: "Blob Jr."), User(id: 1, name: "Blob")])
    }

    internal func testInsertContentsOf() {
        var array: IdentifiedArray = [User(id: 1, name: "Blob")]

        array.insert(
            contentsOf: [User(id: 3, name: "Blob Sr."), User(id: 2, name: "Blob Jr.")], at: 0)
        XCTAssertEqual(
            array,
            [
                User(id: 3, name: "Blob Sr."), User(id: 2, name: "Blob Jr."),
                User(id: 1, name: "Blob"),
            ]
        )
    }

    internal func testRemoveAt() {
        var array: IdentifiedArray = [
            User(id: 3, name: "Blob Sr."),
            User(id: 2, name: "Blob Jr."),
            User(id: 1, name: "Blob"),
        ]

        array.remove(at: 1)
        XCTAssertEqual(array, [User(id: 3, name: "Blob Sr."), User(id: 1, name: "Blob")])
    }

    internal func testRemoveAllWhere() {
        var array: IdentifiedArray = [
            User(id: 3, name: "Blob Sr."),
            User(id: 2, name: "Blob Jr."),
            User(id: 1, name: "Blob"),
        ]

        array.removeAll(where: { $0.name.starts(with: "Blob ") })
        XCTAssertEqual(array, [User(id: 1, name: "Blob")])
    }

    internal func testRemoveAtOffsets() {
        var array: IdentifiedArray = [
            User(id: 3, name: "Blob Sr."),
            User(id: 2, name: "Blob Jr."),
            User(id: 1, name: "Blob"),
        ]

        array.remove(atOffsets: [0, 2])
        XCTAssertEqual(array, [User(id: 2, name: "Blob Jr.")])
    }

    internal func testReplaceSubrange() {
        var array: IdentifiedArray = [
            User(id: 3, name: "Blob Sr."),
            User(id: 2, name: "Blob Jr."),
            User(id: 1, name: "Blob"),
            User(id: 2, name: "Blob Jr."),
        ]

        array.replaceSubrange(
            0...1,
            with: [
                User(id: 4, name: "Flob IV"),
                User(id: 5, name: "Flob V"),
            ]
        )

        XCTAssertEqual(
            array,
            [
                User(id: 4, name: "Flob IV"), User(id: 5, name: "Flob V"),
                User(id: 1, name: "Blob"),
                User(id: 2, name: "Blob Jr."),
            ]
        )
    }

    internal func testSortBy() {
        var array: IdentifiedArray = [
            ComparableValue(id: 1, value: 100),
            ComparableValue(id: 2, value: 50),
            ComparableValue(id: 3, value: 75),
        ]

        array.sort { $0.value < $1.value }

        XCTAssertEqual([2, 3, 1], array.ids)
        XCTAssertEqual(
            [
                ComparableValue(id: 2, value: 50),
                ComparableValue(id: 3, value: 75),
                ComparableValue(id: 1, value: 100),
            ], array
        )
    }

    internal func testSort() {
        var array: IdentifiedArray = [
            ComparableValue(id: 1, value: 100),
            ComparableValue(id: 2, value: 50),
            ComparableValue(id: 3, value: 75),
        ]

        array.sort()

        XCTAssertEqual([2, 3, 1], array.ids)
        XCTAssertEqual(
            [
                ComparableValue(id: 2, value: 50),
                ComparableValue(id: 3, value: 75),
                ComparableValue(id: 1, value: 100),
            ], array
        )
    }

    // Account for randomness API changes in Swift 5.3 (https://twitter.com/mbrandonw/status/1262388756847505410)
    // TODO: Try swapping out the LCRNG for a Xoshiro generator
    #if swift(>=5.3)
        internal func testShuffle() {
            var array: IdentifiedArray = [
                User(id: 1, name: "Blob"),
                User(id: 2, name: "Blob Jr."),
                User(id: 3, name: "Blob Sr."),
                User(id: 4, name: "Foo Jr."),
                User(id: 5, name: "Bar Jr."),
            ]
            var lcrng = LCRNG(seed: 0)
            array.shuffle(using: &lcrng)
            XCTAssertEqual(
                [
                    User(id: 1, name: "Blob"),
                    User(id: 3, name: "Blob Sr."),
                    User(id: 5, name: "Bar Jr."),
                    User(id: 4, name: "Foo Jr."),
                    User(id: 2, name: "Blob Jr."),
                ],
                array.elements
            )
            XCTAssertEqual([1, 3, 5, 4, 2], array.ids)
        }
    #endif

    internal func testReverse() {
        var array: IdentifiedArray = [
            ComparableValue(id: 1, value: 100),
            ComparableValue(id: 2, value: 50),
            ComparableValue(id: 3, value: 75),
        ]

        array.reverse()

        XCTAssertEqual([3, 2, 1], array.ids)
        XCTAssertEqual(
            [
                ComparableValue(id: 3, value: 75),
                ComparableValue(id: 2, value: 50),
                ComparableValue(id: 1, value: 100),
            ], array
        )
    }
}

internal struct User: Equatable, HashDiffable {
    internal let id: Int
    internal var name: String
}

internal struct ComparableValue: Comparable, HashDiffable {
    internal let id: Int
    internal let value: Int

    internal static func < (lhs: ComparableValue, rhs: ComparableValue) -> Bool {
        return lhs.value < rhs.value
    }
}
