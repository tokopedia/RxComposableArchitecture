//
//  RouteVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 17/05/22.
//

import RxComposableArchitecture
import UIKit

class RouteVC: UITableViewController {
    internal enum Route: String, CaseIterable {
        case basic = "1. State, Action, Reducer"
        case environment = "2. Environment"
        case scoping = "3. Scope"
        case pullback = "4. Pullback"
        case optionalIfLet = "5. IfLet & Reducer.optional"
        case neverEqual = "6. Demo NeverEqual"
        case timer = "7. Demo Timer"
        case nestedScope = "8. Nested Scope"
    }

    internal var routes: [Route] = Route.allCases
    internal init() {
        super.init(style: .insetGrouped)
        title = "RxComposableArchitecture Examples"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    override internal func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedRoute = routes[indexPath.row]
        switch selectedRoute {
        case .basic:
            let viewController = BasicUsageVC(
                store: StoreOf<Basic>(
                    initialState: Basic.State(number: 0),
                    reducer: Basic()
                )
            )
            navigationController?.pushViewController(viewController, animated: true)
        case .environment:
            navigationController?.pushViewController(EnvironmentRouteVC(), animated: true)
        case .scoping:
            let viewController = ScopingVC(
                store: StoreOf<Scoping>(
                    initialState: Scoping.State(),
                    reducer: Scoping()
                )
            )
            navigationController?.pushViewController(viewController, animated: true)
        case .pullback:
            let viewController = PullbackVC(
                store: Store(
                    initialState: Pullback.State(),
                    reducer: Pullback()
                )
            )
            navigationController?.pushViewController(viewController, animated: true)
        case .optionalIfLet:
            let viewController = OptionalIfLetVC(
                store: Store(
                    initialState: OptionalIfLet.State(),
                    reducer: OptionalIfLet()
                )
            )
            navigationController?.pushViewController(viewController, animated: true)
        case .neverEqual:
            let viewController = NeverEqualVC(
                store: Store(
                    initialState: NeverEqualExample.State(),
                    reducer: NeverEqualExample()
                )
            )
            navigationController?.pushViewController(viewController, animated: true)
        case .timer:
            let viewController = TimerVC(
                store: Store(
                    initialState: TimerExample.State(),
                    reducer: TimerExample()
                )
            )
            navigationController?.pushViewController(viewController, animated: true)
        case .nestedScope:
            let viewController = NestedScopeVC(
                store: Store(
                    initialState: Parent.State(),
                    reducer: Parent(),
                    useNewScope: false
                )
            )
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        routes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = routes[indexPath.row].rawValue
        return cell
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
