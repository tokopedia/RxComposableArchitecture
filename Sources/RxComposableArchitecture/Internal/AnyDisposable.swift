//
//  AnyDisposable.swift
//  RxComposableArchitecture_RxComposableArchitecture
//
//  Created by Jefferson Setiawan on 02/02/21.
//

import Foundation
import RxSwift

public final class AnyDisposable: Disposable, Hashable {
    private let _dispose: () -> Void

    public init(_ disposable: Disposable) {
        _dispose = disposable.dispose
    }
    
    public init(_ cancel: @escaping () -> Void) {
        _dispose = cancel
    }

    public func dispose() {
        _dispose()
    }

    public static func == (lhs: AnyDisposable, rhs: AnyDisposable) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
