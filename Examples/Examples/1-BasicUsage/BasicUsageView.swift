//
//  BasicUsageView.swift
//  Examples
//
//  Created by daniel.istyana on 25/07/23.
//

import SwiftUI
import RxComposableArchitecture

struct BasicUsageView: View {
    let store: StoreOf<Basic>
    
    var body: some View {
        WithViewStore(self.store) { viewStore in
            VStack {
                Text("This is a demo for Basic usage State, Action, Reducer, and how to bind it to the UI using SwiftUI")
                    .padding()
                Spacer()
                HStack(spacing: 48) {
                    Button {
                        viewStore.send(.didTapPlus)
                    } label: {
                        Label {
                            Text("+")
                                .font(.title3)
                        } icon: {
                            Image(systemName: "plus")
                        }
                        .labelStyle(.titleOnly)

                    }
                    
                    Text("\(viewStore.number)")
                        .font(.largeTitle)

                    
                    Button {
                        viewStore.send(.didTapMinus)
                    } label: {
                        Label {
                            Text("-")
                                .font(.title3)
                        } icon: {
                            Image(systemName: "plus")
                        }
                        .labelStyle(.titleOnly)

                    }
                }
                Spacer()
            }
            
        }
    }
}

struct BasicUsageView_Previews: PreviewProvider {
    static var previews: some View {
        BasicUsageView(store: Store(initialState: Basic.State(number: 0), reducer: Basic()))
    }
}
