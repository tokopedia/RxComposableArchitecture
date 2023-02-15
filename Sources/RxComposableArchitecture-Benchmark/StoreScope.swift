import Benchmark
import RxComposableArchitecture

let storeScopeSuite = BenchmarkSuite(name: "Store scoping") { suite in
    let counterReducer = AnyReducer<Int, Bool, Void> { state, action, _ in
        if action {
            state += 1
            return .none
        } else {
            state -= 1
            return .none
        }
    }
    var store = Store2(initialState: 0, reducer: counterReducer, environment: ())
    var viewStores: [Store2<Int, Bool>] = [store]
    for _ in 1...5 {
        store = store.scope(state: { $0 })
        viewStores.append(store)
    }
    let lastViewStore = viewStores.last!
    
    suite.benchmark("Nested store") {
        _ = lastViewStore.send(true)
    }
}

let newStoreScopeSuite = BenchmarkSuite(name: "[NEW] Store scoping, with rescope") { suite in
    let counterReducer = AnyReducer<Int, Bool, Void> { state, action, _ in
        if action {
            state += 1
            return .none
        } else {
            state -= 1
            return .none
        }
    }
    var store = Store2(initialState: 0, reducer: counterReducer, environment: (), useNewScope: true)
    var viewStores: [Store2<Int, Bool>] = [store]
    for _ in 1...5 {
        store = store.scope(state: { $0 })
        viewStores.append(store)
    }
    let lastViewStore = viewStores.last!
    
    suite.benchmark("[NEW] Nested store, with rescope") {
        lastViewStore.send(true)
    }
}
