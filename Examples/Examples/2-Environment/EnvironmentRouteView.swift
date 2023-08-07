//
//  EnvironmentRouteView.swift
//  Examples
//
//  Created by daniel.istyana on 26/07/23.
//

import RxComposableArchitecture
import SwiftUI

struct EnvironmentRouteView: View {
    var body: some View {
        List(EnvironmentRouteVC.Route.allCases, id: \.self) { route in
            NavigationLink(route.rawValue) {
                switch route {
                case .live:
                    EnvironmentDemoView(
                        store: Store(
                            initialState: Environment.State(),
                            reducer: Environment()
                                .dependency(\.envVCEnvironment, .live)
                        )
                    )
                case .mockSuccess:
                    EnvironmentDemoView(
                        store: Store(
                            initialState: Environment.State(),
                            reducer: Environment()
                                .dependency(\.envVCEnvironment, .mockSuccess)
                        )
                    )
                case .mockFailed:
                    EnvironmentDemoView(
                        store: Store(
                            initialState: Environment.State(),
                            reducer: Environment()
                                .dependency(\.envVCEnvironment, .mockFailed)
                        )
                    )
                case .mockRandom:
                    EnvironmentDemoView(
                        store: Store(
                            initialState: Environment.State(),
                            reducer: Environment()
                                .dependency(\.envVCEnvironment, .mockRandom)
                        )
                    )
                }
            }
        }
        .navigationTitle("Environment")
    }
}

struct EnvironmentDemoView: View {
    let store: StoreOf<Environment>
    var body: some View {
        WithViewStore(self.store) { viewStore in
            VStack {
                Text("In this example, you will learn how to use Environment. You'll also learn how to use side effect (such as networking and analytics) Because we can initialize the environment in init, you can easily swap the environment from the EnvironmentRoute.swift. You can try to change from .live to .mock")
                
                HStack {
                    Text(viewStore.text)
                        .font(.title3)
                    
                    if viewStore.isLoading {
                        Spacer()
                        ProgressView()
                    } else {
                        Spacer()
                    }
                }
                .padding(.top)
                
                Button {
                    viewStore.send(.refresh)
                } label: {
                    Text("Reload")
                        .font(.largeTitle)
                }
                
                RoundedRectangle(cornerRadius: 8)
                    .frame(height: 3)
                
                if let date = viewStore.currentDate {
                    HStack {
                        Text(DateFormatter.convertToString(date: date))
                            .font(.title3)
                        Spacer()
                    }
                }
                
                Button {
                    viewStore.send(.getCurrentDate)
                } label: {
                    Text("Get New Date")
                        .font(.largeTitle)
                }
                
                
                    .frame(height: 3)
                
                if viewStore.uuidString.isEmpty {
                    HStack {
                        Text("None")
                            .font(.title3)
                        Spacer()
                    }
                } else {
                    HStack {
                        Text(viewStore.uuidString)
                        Spacer()
                    }
                }

                Button {
                    viewStore.send(.generateUUID)
                } label: {
                    Text("Get New UUID")
                        .font(.largeTitle)
                }
            }
            .alert(
                isPresented: viewStore.binding(
                    get: \.isShowingAlert,
                    send: { _ in Environment.Action.dismissAlert }
                ), content: {
                    Alert(title: Text("Test"), message: Text("Test"))
                }
            )
            .padding()
        }
    }
}

struct EnvironmentRouteView_Previews: PreviewProvider {
    static var previews: some View {
        EnvironmentDemoView(
            store: Store(
                initialState: Environment.State(),
                reducer: Environment()
            )
        )
    }
}

extension DateFormatter {
    static func convertToString(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .full
        return dateFormatter.string(from: date)
    }
}
