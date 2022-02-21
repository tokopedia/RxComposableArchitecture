//
//  SingleSelectionTests.swift
//  RxComposableArchitectureTests
//
//  Created by Wendy Liga on 25/05/21.
//

import RxComposableArchitecture
import XCTest

internal final class SingleSelectionTests: XCTestCase {
    internal struct Item: HashDiffable, Equatable {
        internal let id: Int
        internal var isSelected: Bool
    }

    internal struct State {
        @SingleSelection([], selection: \.isSelected)
        internal var items: IdentifiedArrayOf<Item>
    }

    internal func test_initNoSelection() {
        let initialItems = IdentifiedArray([
            Item(id: 1, isSelected: false),
            Item(id: 2, isSelected: false),
            Item(id: 3, isSelected: false),
            Item(id: 4, isSelected: false)
        ])

        let target = State(items: SingleSelection<Item>(initialItems, selection: \.isSelected))
        AssertSelection(target, selectionId: nil)
    }

    internal func test_initWithSelection() {
        let initialItems = IdentifiedArray([
            Item(id: 0, isSelected: true),
            Item(id: 1, isSelected: false),
            Item(id: 2, isSelected: false),
            Item(id: 3, isSelected: false)
        ])

        let target = State(items: SingleSelection<Item>(initialItems, selection: \.isSelected))
        AssertSelection(target, selectionId: 0)
    }

    internal func test_initWithMultipleSelection_shouldSelectTheFirstOne() {
        let initialItems = IdentifiedArray([
            Item(id: 0, isSelected: false),
            Item(id: 1, isSelected: true),
            Item(id: 2, isSelected: true),
            Item(id: 3, isSelected: true)
        ])

        let target = State(items: SingleSelection<Item>(initialItems, selection: \.isSelected))
        AssertSelection(target, selectionId: 1)
    }

    internal func test_initWithSelection_thenChangeSelection() {
        let initialItems = IdentifiedArray([
            Item(id: 0, isSelected: true),
            Item(id: 1, isSelected: false),
            Item(id: 2, isSelected: false),
            Item(id: 3, isSelected: false)
        ])

        var target = State(items: SingleSelection<Item>(initialItems, selection: \.isSelected))

        target.items[1].isSelected = true
        AssertSelection(target, selectionId: 1)
    }

    internal func test_initWithMultipleSelection_shouldSelectTheFirstOne_thenChangeSelectionSeveralTime() {
        let initialItems = IdentifiedArray([
            Item(id: 0, isSelected: false),
            Item(id: 1, isSelected: true),
            Item(id: 2, isSelected: true),
            Item(id: 3, isSelected: true)
        ])

        var target = State(items: SingleSelection<Item>(initialItems, selection: \.isSelected))
        target.items[2].isSelected = true
        target.items[3].isSelected = true
        AssertSelection(target, selectionId: 3)
    }

    internal func AssertSelection(
        _ state: SingleSelectionTests.State,
        selectionId id: Int?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let selected = state.items.filter(\.isSelected)
        guard let id = id else {
            XCTAssertTrue(selected.count == 0, file: file, line: line)
            return
        }

        guard let element = selected[id: id] else {
            XCTFail("element is not valid", file: file, line: line); return
        }

        XCTAssertTrue(selected.count == 1 && element.isSelected, file: file, line: line)
    }
}
