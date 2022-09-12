import Benchmark
import RxComposableArchitecture
import Foundation
import RxSwift

let effectSuite = BenchmarkSuite(name: "Effects") {
    $0.benchmark("Merged Effect.none (create, flat)") {
        doNotOptimizeAway(Effect<Int>.merge((1...100).map { _ in .none }))
    }
    
    $0.benchmark("Merged Effect.none (create, nested)") {
        var effect = Effect<Int>.none
        for _ in 1...100 {
            effect = .merge(.none)
        }
        doNotOptimizeAway(effect)
    }
    
    let effect = Effect<Int>.merge((1...100).map { _ in .none })
    var disposeBag = DisposeBag()
    var didComplete = false
    $0.benchmark("Merged Effect.none (sink)") {
        doNotOptimizeAway(
            effect.subscribe(onCompleted: {  didComplete = true }).disposed(by: disposeBag)
        )
    } tearDown: {
        precondition(didComplete)
    }
}
