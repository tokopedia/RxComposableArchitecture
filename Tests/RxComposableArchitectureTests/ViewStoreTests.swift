import RxComposableArchitecture
import RxSwift
import XCTest
import Combine

@MainActor
internal final class ViewStoreTests: XCTestCase {
    internal var disposeBag = DisposeBag()
    
    override func setUp() {
        super.setUp()
        self.disposeBag = DisposeBag()
        equalityChecks = 0
        subEqualityChecks = 0
    }
    
    func testPublisherFirehose() {
        let store = Store<Int, Void>(initialState: 0, reducer: EmptyReducer())
        let viewStore = ViewStore(store, observe: { $0 })
        var emissionCount = 0
        
        viewStore.observable
            .subscribe(onNext: { _ in
                emissionCount += 1
            })
            .disposed(by: self.disposeBag)
        
        XCTAssertEqual(emissionCount, 1)
        viewStore.send(())
        XCTAssertEqual(emissionCount, 1)
        viewStore.send(())
        XCTAssertEqual(emissionCount, 1)
        viewStore.send(())
        XCTAssertEqual(emissionCount, 1)
    }
    
    func testEqualityChecks() {
        let store = Store<State, Void>(initialState: State(), reducer: EmptyReducer())
        
        let store1 = store.scope(state: { $0 }, action: { $0 })
        let store2 = store1.scope(state: { $0 }, action: { $0 })
        let store3 = store2.scope(state: { $0 }, action: { $0 })
        let store4 = store3.scope(state: { $0 }, action: { $0 })
        
        let viewStore1 = ViewStore(store1, observe: { $0 } )
        let viewStore2 = ViewStore(store2, observe: { $0 } )
        let viewStore3 = ViewStore(store3, observe: { $0 } )
        let viewStore4 = ViewStore(store4, observe: { $0 } )
        
        viewStore1.observable
            .subscribe(onNext: { _ in })
            .disposed(by: self.disposeBag)
        viewStore2.observable
            .subscribe(onNext: { _ in })
            .disposed(by: self.disposeBag)
        viewStore3.observable
            .subscribe(onNext: { _ in })
            .disposed(by: self.disposeBag)
        viewStore4.observable
            .subscribe(onNext: { _ in })
            .disposed(by: self.disposeBag)
        
        viewStore1.observable
            .map(\.substate)
            .subscribe(onNext: { _ in })
            .disposed(by: self.disposeBag)
        viewStore2.observable
            .map(\.substate)
            .subscribe(onNext: { _ in })
            .disposed(by: self.disposeBag)
        viewStore3.observable
            .map(\.substate)
            .subscribe(onNext: { _ in })
            .disposed(by: self.disposeBag)
        viewStore4.observable
            .map(\.substate)
            .subscribe(onNext: { _ in })
            .disposed(by: self.disposeBag)
        
        XCTAssertEqual(0, equalityChecks)
        XCTAssertEqual(0, subEqualityChecks)
        viewStore4.send(())
        XCTAssertEqual(4, equalityChecks)
        XCTAssertEqual(4, subEqualityChecks)
        viewStore4.send(())
        XCTAssertEqual(8, equalityChecks)
        XCTAssertEqual(8, subEqualityChecks)
        viewStore4.send(())
        XCTAssertEqual(12, equalityChecks)
        XCTAssertEqual(12, subEqualityChecks)
        viewStore4.send(())
        XCTAssertEqual(16, equalityChecks)
        XCTAssertEqual(16, subEqualityChecks)
    }
    
    func testAccessViewStoreStateInPublisherSink() {
        let reducer = Reduce<Int, Void> { count, _ in
            count += 1
            return .none
        }
        
        let store = Store(initialState: 0, reducer: reducer)
        let viewStore = ViewStore(store, observe: { $0 })
        
        var results: [Int] = []
        
        viewStore.observable
            .subscribe(onNext: { _ in results.append(viewStore.state) })
            .disposed(by: self.disposeBag)
        
        viewStore.send(())
        viewStore.send(())
        viewStore.send(())
        
        XCTAssertEqual([0, 1, 2, 3], results)
    }
    
    func testWillSet() {
        var cancellables: Set<AnyCancellable> = []
        let reducer = Reduce<Int, Void> { count, _ in
            count += 1
            return .none
        }
        
        let store = Store(initialState: 0, reducer: reducer)
        let viewStore = ViewStore(store, observe: { $0 })
        
        var results: [Int] = []
        
        viewStore.objectWillChange
            .sink { _ in results.append(viewStore.state) }
            .store(in: &cancellables)
        
        viewStore.send(())
        viewStore.send(())
        viewStore.send(())
        
        XCTAssertEqual([0, 1, 2], results)
    }
    
    func testPublisherOwnsViewStore() {
        let reducer = Reduce<Int, Void> { count, _ in
            count += 1
            return .none
        }
        let store = Store(initialState: 0, reducer: reducer)

        var results: [Int] = []
        ViewStore(store, observe: { $0 })
            .observable
            .subscribe(onNext: { results.append($0) })
            .disposed(by: self.disposeBag)


        ViewStore(store, observe: { $0 }).send(())
        
        ViewStore(store, observe: { $0 })
            .observable
            .subscribe(onNext: { results.append($0) })
            .disposed(by: self.disposeBag)

        XCTAssertEqual(results, [0, 1])
    }
    
    func testStorePublisherSubscriptionOrder() {
        let reducer = Reduce<Int, Void> { count, _ in
            count += 1
            return .none
        }
        let store = Store(initialState: 0, reducer: reducer)
        let viewStore = ViewStore(store, observe: { $0 })
        
        var results: [Int] = []
        
        viewStore.observable
            .subscribe(onNext: { _ in results.append(0) })
            .disposed(by: self.disposeBag)
        
        viewStore.observable
            .subscribe(onNext: { _ in results.append(1) })
            .disposed(by: self.disposeBag)
        
        viewStore.observable
            .subscribe(onNext: { _ in results.append(2) })
            .disposed(by: self.disposeBag)
        
        
        XCTAssertEqual(results, [0, 1, 2])
        
        for _ in 0..<9 {
            viewStore.send(())
        }
        
        XCTAssertEqual(results, Array(repeating: [0, 1, 2], count: 10).flatMap { $0 })
    }
    
    func testSendWhile() async {
        enum Action {
            case response
            case tapped
        }
        let reducer = Reduce<Bool, Action> { state, action in
            switch action {
            case .response:
                state = false
                return .none
            case .tapped:
                state = true
                return .task { .response }
            }
        }
        
        let store = Store(initialState: false, reducer: reducer)
        let viewStore = ViewStore(store, observe: { $0 })
        
        XCTAssertEqual(viewStore.state, false)
        await viewStore.send(.tapped, while: { $0 })
        XCTAssertEqual(viewStore.state, false)
    }
    
    func testSuspend() {
        let expectation = self.expectation(description: "await")
        Task {
            enum Action {
                case response
                case tapped
            }
            let reducer = Reduce<Bool, Action> { state, action in
                switch action {
                case .response:
                    state = false
                    return .none
                case .tapped:
                    state = true
                    return .task { .response }
                }
            }
            
            let store = Store(initialState: false, reducer: reducer)
            let viewStore = ViewStore(store, observe: { $0 })
            
            XCTAssertEqual(viewStore.state, false)
            _ = { viewStore.send(.tapped) }()
            XCTAssertEqual(viewStore.state, true)
            await viewStore.yield(while: { $0 })
            XCTAssertEqual(viewStore.state, false)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testAsyncSend() async throws {
        enum Action {
            case tap
            case response(Int)
        }
        let store = Store(initialState: 0, reducer: Reduce<Int, Action> { state, action in
            switch action {
            case .tap:
                return .task {
                    return .response(42)
                }
            case let .response(value):
                state = value
                return .none
            }
        })
        
        let viewStore = ViewStore(store, observe: { $0 })
        
        XCTAssertEqual(viewStore.state, 0)
        await viewStore.send(.tap).finish()
        XCTAssertEqual(viewStore.state, 42)
    }
    
    func testAsyncSendCancellation() async throws {
        enum Action {
            case tap
            case response(Int)
        }
        let store = Store(initialState: 0, reducer: Reduce<Int, Action> { state, action in
            switch action {
            case .tap:
                return .task {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
                    return .response(42)
                }
            case let .response(value):
                state = value
                return .none
            }
        })
        
        let viewStore = ViewStore(store, observe: { $0 })
        
        XCTAssertEqual(viewStore.state, 0)
        let task = viewStore.send(.tap)
        task.cancel()
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        XCTAssertEqual(viewStore.state, 0)
    }
}

private struct State: Equatable {
    var substate = Substate()
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        equalityChecks += 1
        return lhs.substate == rhs.substate
    }
}

private struct Substate: Equatable {
    var name = "Blob"
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        subEqualityChecks += 1
        return lhs.name == rhs.name
    }
}

private var equalityChecks = 0
private var subEqualityChecks = 0
