import Benchmark
import RxComposableArchitecture

let storeScopeSuite = BenchmarkSuite(name: "Store scoping") { suite in
    let counterReducer = Reducer<Int, Bool, Void> { state, action, _ in
        if action {
            state += 1
            return .none
        } else {
            state -= 1
            return .none
        }
    }
    var store = Store(initialState: 0, reducer: counterReducer, environment: ())
    var viewStores: [Store<Int, Bool>] = [store]
    for _ in 1...5 {
        store = store.scope(state: { $0 })
        viewStores.append(store)
    }
    let lastViewStore = viewStores.last!
    
    suite.benchmark("Nested store") {
        lastViewStore.send(true)
    }
}

let newStoreScopeSuite = BenchmarkSuite(name: "[NEW] Store scoping, with rescope") { suite in
    let counterReducer = Reducer<Int, Bool, Void> { state, action, _ in
        if action {
            state += 1
            return .none
        } else {
            state -= 1
            return .none
        }
    }
    var store = Store(initialState: 0, reducer: counterReducer, environment: (), useNewScope: true)
    var viewStores: [Store<Int, Bool>] = [store]
    for _ in 1...5 {
        store = store.scope(state: { $0 })
        viewStores.append(store)
    }
    let lastViewStore = viewStores.last!
    
    suite.benchmark("[NEW] Nested store, with rescope") {
        lastViewStore.send(true)
    }
}
