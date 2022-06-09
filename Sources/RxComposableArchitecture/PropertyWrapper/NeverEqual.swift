//
//  NeverEqual.swift
//  
//
//  Created by jefferson.setiawan on 03/06/22.
//

/*
 This PropertyWrapper is used for the UI that doesn't have an actual clear state, for example is `scrollToTop`,
 We only give the instruction about what to do, code example:
 ```swift
 struct EmitState: Equatable {
     var scrollToTop: Stateless?
 }

 enum EmitAction: Equatable {
     case didTapScrollToTop
     case resetScrollToTop
 }

 // reducer

 Reducer {
   switch action {
     case .didTapScrollToTop:
         state.scrollToTop = Stateless()
         return Effect(value: .resetScrollToTop)
     case .resetScrollToTop:
         state.scrollToTop = nil
         return .none
   }
 }
 ```
 
 By default, if `scrollToTop` property never get resetted, it will never emit again even though you are sending multiple `.didTapScrollToTop` action to the reducer.
 This is because the `store.subscribe` has `distinctUntilChanged`, so the `subscribe` will only be emitted once it's not equal from the previous property.
 
 We usually do this juggling (set and reset) because we don't know when the right time to reset the property, and when PointFree enhance its store.send mechanism, this mechanism will not work.
 
 When using the NeverEqual, you don't need to reset the state again just to make it not equal.
 ```swift
 struct EmitState: Equatable {
     @NeverEqual var scrollToTop: Stateless?
 }
 
 Reducer {
   switch action {
     case .didTapScrollToTop:
         state.scrollToTop = Stateless()
         return .none
    }
 }
 
 // UI
 
 store.subscribeNeverEqual(\.$scrollToTop)
    .subscribe(onNext: { ... })
 ```
 Behind the scene, the property wrapper will increment the number everytime you set it to new value, so it will not equal.
 
*/
@propertyWrapper
 public struct NeverEqual<Value> {
     private var value: Value
     private var numberOfIncrement: UInt8 = 0

     public var wrappedValue: Value {
         get { value }
         set {
             value = newValue
             if numberOfIncrement == .max {
                 numberOfIncrement = 0
             } else {
                 numberOfIncrement += 1
             }
         }
     }

     public var projectedValue: NeverEqual<Value> { self }

     public init(wrappedValue: Value) {
         self.value = wrappedValue
     }
 }

 extension NeverEqual: Equatable where Value: Equatable {}
