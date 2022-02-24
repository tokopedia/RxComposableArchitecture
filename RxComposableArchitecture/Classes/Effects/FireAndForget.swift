import Foundation
import RxSwift

extension ObservableType {
    public static func fireAndForget(_ work: @escaping () -> Void) -> Observable<Element> {
        return Observable<Element>.deferred { () -> Observable<Self.Element> in
            work()
            return .empty()
        }
    }
}

extension ObservableType where Element == Never {
    public func fireAndForget<T>() -> Observable<T> {
        func absurd<A>(_: Never) -> A {}
        return map(absurd)
    }
}
