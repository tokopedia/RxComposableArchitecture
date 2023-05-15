//
//  EnvironmentRoute.swift
//  Examples
//
//  Created by jefferson.setiawan on 02/06/22.
//

import RxComposableArchitecture
import UIKit
import Dependencies

class EnvironmentRouteVC: UITableViewController {
    internal enum Route: String, CaseIterable {
        case live = "Live"
        case mockSuccess = "Mock always success get data"
        case mockFailed = "Mock always failed get data"
        case mockRandom = "Mock random succcess and failed"
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
        case .live:
            let viewController = EnvironmentDemoVC(
                store: Store(
                    initialState: Environment.State(),
                    reducer: Environment()
                        .dependency(\.envVCEnvironment, .live)
                )
            )
            navigationController?.pushViewController(viewController, animated: true)
        case .mockSuccess:
            let viewController = EnvironmentDemoVC(
                store: Store(
                    initialState: Environment.State(),
                    reducer: Environment()
                        .dependency(\.envVCEnvironment, .mockSuccess)
                )
            )
            navigationController?.pushViewController(viewController, animated: true)
        case .mockFailed:
            let viewController = EnvironmentDemoVC(
                store: Store(
                    initialState: Environment.State(),
                    reducer: Environment()
                        .dependency(\.envVCEnvironment, .mockFailed)
                )
            )
            navigationController?.pushViewController(viewController, animated: true)
        case .mockRandom:
            let viewController = EnvironmentDemoVC(
                store: Store(
                    initialState: Environment.State(),
                    reducer: Environment()
                        .dependency(\.envVCEnvironment, .mockRandom)
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
