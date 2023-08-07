//
//  RouteVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 17/05/22.
//

import RxComposableArchitecture
import UIKit
import SwiftUI

class RouteVC: UITableViewController {
    internal enum Route: String, CaseIterable {
        internal enum UIFramework: String, CaseIterable {
            case SwiftUI
            case UIKit
        }
        case basic = "1. State, Action, Reducer"
        case environment = "2. Environment"
        case scoping = "3. Scope"
        case pullback = "4. Pullback"
        case optionalIfLet = "5. IfLet & Reducer.optional"
        case neverEqual = "6. Demo NeverEqual"
        case timer = "7. Demo Timer"
    }

    internal var routes: [Route.UIFramework: [Route]] = [
        .UIKit: Route.allCases,
        .SwiftUI: Route.allCases
    ]
    internal init() {
        super.init(style: .insetGrouped)
        title = "RxComposableArchitecture Examples"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    override internal func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let route = routes[indexPath.section == 0 ? .UIKit : .SwiftUI]!
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedRoute = route[indexPath.row]
        switch selectedRoute {
        case .basic:
            let viewController = BasicUsageVC(
                store: StoreOf<Basic>(
                    initialState: Basic.State(number: 0),
                    reducer: Basic()
                )
            )
            let swiftUIController = UIHostingController(
                rootView: BasicUsageView(
                    store: Store(
                        initialState: Basic.State(number: 0),
                        reducer: Basic()
                    )
                )
            )
            navigationController?.pushViewController(indexPath.section == 0 ? viewController : swiftUIController, animated: true)
            
        case .environment:
            let uikitVC = EnvironmentRouteVC()
            let swiftUIVC = UIHostingController(rootView: EnvironmentRouteView())
            navigationController?.pushViewController(indexPath.section == 0 ? uikitVC : swiftUIVC, animated: true)
            
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
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return routes.keys.count
    }
    
    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Route.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "UIKit"
        case 1: return "SwiftUI"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let route = routes[indexPath.section == 0 ? .UIKit : .SwiftUI]!
        cell.textLabel?.text = route[indexPath.row].rawValue
        return cell
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
