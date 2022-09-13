import Benchmark
import RxComposableArchitecture

Benchmark.main([
    defaultBenchmarkSuite,
    effectSuite,
    storeScopeSuite,
    newStoreScopeSuite,
])
