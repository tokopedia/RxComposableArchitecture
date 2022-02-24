//
//  Deprecated.swift
//  RxComposableArchitecture_RxComposableArchitecture
//
//  Created by Jefferson Setiawan on 22/03/21.
//

extension Reducer {
    @available(*, deprecated, renamed: "optional()")
    public var optional: Reducer<State?, Action, Environment> {
        self.optional()
    }
}
