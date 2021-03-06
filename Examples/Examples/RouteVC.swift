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
            let viewController = BasicUsageVC(store: Store(
                initialState: BasicState(number: 0),
                reducer: basicUsageReducer,
                environment: ()
            ))
            navigationController?.pushViewController(viewController, animated: true)
        case .environment:
            navigationController?.pushViewController(EnvironmentRouteVC(), animated: true)
        case .scoping:
            let viewController = ScopingVC(store: Store(
                initialState: ScopingState(),
                reducer: scopingReducer,
                environment: ()
            ))
            navigationController?.pushViewController(viewController, animated: true)
        case .pullback:
            let viewController = PullbackVC(store: Store(
                initialState: PullbackState(),
                reducer: pullbackReducer,
                environment: ()
            ))
            navigationController?.pushViewController(viewController, animated: true)
        case .optionalIfLet:
            let viewController = OptionalIfLetVC(store: Store(
                initialState: OptionalIfLetState(),
                reducer: optionalIfLetReducer,
                environment: ()
            ))
            navigationController?.pushViewController(viewController, animated: true)
        case .neverEqual:
            let viewController = NeverEqualVC(store: Store(
                initialState: NeverEqualState(),
                reducer: neverEqualDemoReducer,
                environment: ()
            ))
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
