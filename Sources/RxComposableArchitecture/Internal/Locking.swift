//
//  Locking.swift
//  RxComposableArchitecture_RxComposableArchitecture
//
//  Created by Jefferson Setiawan on 02/02/21.
//

import Foundation

extension UnsafeMutablePointer where Pointee == os_unfair_lock_s {
    @inlinable @discardableResult
    internal func sync<R>(_ work: () -> R) -> R {
        os_unfair_lock_lock(self)
        defer { os_unfair_lock_unlock(self) }
        return work()
    }
}

extension NSRecursiveLock {
    @inlinable @discardableResult
    @_spi(Internals) public func sync<R>(work: () -> R) -> R {
        lock()
        defer { self.unlock() }
        return work()
    }
}
