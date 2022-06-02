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
        case basic = "1. Basic Usage"
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
            let viewController = BasicUsageVC(store: Store(initialState: BasicState(number: 0), reducer: basicUsageReducer, environment: ()))
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
