//
//  AnyDisposable.swift
//  RxComposableArchitecture_RxComposableArchitecture
//
//  Created by Jefferson Setiawan on 02/02/21.
//

import Foundation
import RxSwift

internal final class AnyDisposable: Disposable, Hashable {
    internal let _dispose: () -> Void

    internal init(_ disposable: Disposable) {
        _dispose = disposable.dispose
    }

    internal func dispose() {
        _dispose()
    }

    internal static func == (lhs: AnyDisposable, rhs: AnyDisposable) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    internal func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
