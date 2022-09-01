//
//  RouteVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 17/05/22.
//

import RxComposableArchitecture
import UIKit

final class Node<Value> {
    var value: Value
    private(set) var children: [Node]
    weak var parent: Node?
    
    //    var count: Int {
    //        1 + children.reduce(0) { $0 + $1.count }
    //    }
    
    init(_ value: Value) {
        self.value = value
        children = []
    }
    
    init(_ value: Value, children: [Node]) {
        self.value = value
        self.children = children
    }
    
    func add(child: Node) {
        children.append(child)
        child.parent = self
    }
    
    func resolveDFS(_ tree: Node) -> [Value] {
        
        var stackResult = [Value]()
        var stackTree = [tree]
        
        while !stackTree.isEmpty {
            
            let current = stackTree.popLast() // remove the last one added, O(1)
            guard let currentUnwrap = current else { return stackResult }
            stackResult.append(currentUnwrap.value) // process node
            if !currentUnwrap.children.isEmpty {
                for tree in currentUnwrap.children {
                    stackTree.append(tree)
                }
            }
        }
        
        return stackResult
    }
}

extension Node: CustomStringConvertible {
  // 2
  var description: String {
    // 3
    var text = "\(value)"
    
   // 4
    if !children.isEmpty {
      text += " {" + children.map { $0.description }.joined(separator: ", ") + "} "
    }
    return text
  }
}


extension Node: Equatable where Value: Equatable {
    static func ==(lhs: Node, rhs: Node) -> Bool {
        lhs.value == rhs.value && lhs.children == rhs.children
    }
}
extension Node where Value: Equatable {
    func find(_ value: Value) -> Node? {
        if self.value == value {
            return self
        }
        
        for child in children {
            if let match = child.find(value) {
                return match
            }
        }
        
        return nil
    }
}
struct InstrumentLog {
    var info: Instrumentation.CallbackInfo<Any, Any>
    var kind: Instrumentation.CallbackKind
    var timing: Instrumentation.CallbackTiming
    var time: DispatchTime
}

class MyInstrumentation {
    var instrumentation: Instrumentation! // to have access on self
    var allLogs: [InstrumentLog] = [] // Queue
    
    init() {
        instrumentation = Instrumentation(callback: { [unowned self] info, timing, kind in
            let currentTime = DispatchTime.now()
            let infoString = String(describing: info)
            allLogs.append(InstrumentLog(info: info, kind: kind, timing: timing, time: currentTime))
        })
    }
    
    func fireLog() {
        guard let first = allLogs.first else { return }
        let tree = Node<FinalData>(FinalData(name: String(describing: first.info.storeKind), kind: "Store Creation", startTime: first.time))
        var latestLeaf: Node<FinalData>? = tree
        allLogs.forEach { instrumentLog in
            switch instrumentLog.timing {
            case .pre:
                let val = Node(FinalData(
                    name: String(describing: instrumentLog.info),
                    kind: "\(instrumentLog.kind) \(String(describing: instrumentLog.info.action))",
                    startTime: instrumentLog.time
                ))
                latestLeaf!.add(child: val)
                latestLeaf = val
            case .post:
                let comparing = FinalData(
                    name: String(describing: instrumentLog.info),
                    kind: "\(instrumentLog.kind) \(String(describing: instrumentLog.info.action))",
                    startTime: instrumentLog.time
                )
                var leaf: Node<FinalData>? = latestLeaf
                while leaf?.value != comparing && leaf?.parent != nil {
                    leaf = leaf?.parent
                }
                leaf!.value.endTime = instrumentLog.time
                latestLeaf = leaf?.parent
            }
        }
        
        allLogs.removeAll()
//        var stackResult = [Value]()
//        var stackTree = [tree]
//        
//        while !stackTree.isEmpty {
//            
//            let current = stackTree.popLast() // remove the last one added, O(1)
//            guard let currentUnwrap = current else { return stackResult }
//            stackResult.append(currentUnwrap.value) // process node
//            if !currentUnwrap.children.isEmpty {
//                for tree in currentUnwrap.children {
//                    stackTree.append(tree)
//                }
//            }
//        }
//        
//        return stackResult
        
        print(tree.resolveDFS(tree))
    }
}

struct FinalData: Equatable {
    var name: String
    var kind: String
    var startTime: DispatchTime
    var endTime: DispatchTime?
    
    static func == (lhs: FinalData, rhs: FinalData) -> Bool {
        return lhs.name == rhs.name && lhs.kind == rhs.kind
    }
}

// Roadmap:
///  1. dump data
///  2. store dmn => userdefaults
///  3. processing gmn
///  4. dashboard / displaying

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
    
    let instrumentLog = MyInstrumentation()
    internal init() {
        super.init(style: .insetGrouped)
        title = "RxComposableArchitecture Examples"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        Instrumentation.shared = instrumentLog.instrumentation
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        instrumentLog.fireLog()
    }
    
    override internal func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedRoute = routes[indexPath.row]
        switch selectedRoute {
        case .basic:
            let viewController = BasicUsageVC(store: Store(
                initialState: BasicState(number: 0),
                reducer: basicUsageReducer,
                environment: (),
                useNewScope: true
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
