//
//  NestedScopeVC.swift
//  Examples
//
//  Created by andhika.setiadi on 22/05/23.
//

import RxComposableArchitecture
import RxSwift
import UIKit

struct Parent: ReducerProtocol {
    internal struct State: Equatable {
        internal var text: String = ""
        internal var childrenState = Children.State(number: 0)
    }
    
    internal enum Action: Equatable {
        case textDidChange(String)
        case childrenAction(Children.Action)
    }
    
    var body: some ReducerProtocolOf<Parent> {
        Scope(state: \.childrenState, action: /Action.childrenAction) {
            Children()
        }
        
        Reduce(self.core)
    }
    
    func core(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .childrenAction(.didTapPlus):
            print(">>> Parent - trackerDidTapPlus")
            return .none

        case let .textDidChange(text):
            state.text = ">>> Parent - You write: \(text)"
            return .none

        default:
            return .none
        }
    }
}

class NestedScopeVC: UIScrollVC {
    private let textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private let childrenView: ChildrenView
    
    private let store: StoreOf<Parent>
    
    init(store: StoreOf<Parent>) {
        self.store = store
        
        childrenView = ChildrenView(
            store: store.scope(
                state: \.childrenState,
                action: Parent.Action.childrenAction
            )
        )
        
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let stack = UIStackView.vertical(
            subviews: [
                UIStackView.horizontal(subviews: [textLabel]),
                childrenView
            ],
            spacing: 8
        )
        
        stack.alignment = .leading
        
        contentView.addSubview(stack)
        stack.fillSuperview(padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16))
    }
        
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct Children: ReducerProtocol {
    internal struct State: Equatable {
        internal var number: Int
        internal var grandChildrenState = GrandChildren.State(text: "initial string grandchildren")
    }
    
    internal enum Action: Equatable {
        case didTapPlus
        case didTapMinus
        case grandChildAction(GrandChildren.Action)
    }
    
    var body: some ReducerProtocolOf<Children> {
        Scope(state: \.grandChildrenState, action: /Action.grandChildAction) {
            GrandChildren()
        }
        
        Reduce(self.core)
    }
    
    func core(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .didTapPlus:
            print(">>> Children - trackerDidTapPlus")
            state.number += 1
            return .none
            
        case .grandChildAction(.didTap):
            state.number = Int.random(in: 0...100)
            return .none
        
        default:
            return .none
        }
    }
}


class ChildrenView: UIStackView {
    private let plusButton = UIButton.template(title: "+")
    
    private let minusButton = UIButton.template(title: "-")
    
    private let numberLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .largeTitle)
        return label
    }()
    
    private let grandChildrenView: GrandChildrenView
    
    private let store: StoreOf<Children>
    private let disposeBag = DisposeBag()
    
    init(store: StoreOf<Children>) {
        self.store = store
        
        self.grandChildrenView = GrandChildrenView(
            store: store.scope(
                state: \.grandChildrenState,
                action: Children.Action.grandChildAction
            )
        )
        
        super.init(frame: .zero)
        
        axis = .vertical
        alignment = .leading
        spacing = 16
        
        let innerStack = UIStackView.horizontal(
            subviews: [
                minusButton,
                numberLabel,
                plusButton
            ]
        )
        
        self.addArrangedSubview(innerStack)
        self.addArrangedSubview(grandChildrenView)
        
        bindState()
        plusButton.addTarget(self, action: #selector(didTapPlus), for: .touchUpInside)
        minusButton.addTarget(self, action: #selector(didTapMinus), for: .touchUpInside)
    }
    
    @objc private func didTapPlus() {
        store.send(.didTapPlus)
    }
    
    @objc private func didTapMinus() {
        store.send(.didTapMinus)
    }
    
    private func bindState() {
        store.subscribe(\.number)
            .subscribe(onNext: { [numberLabel] in
                numberLabel.text = String($0)
            })
            .disposed(by: disposeBag)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct GrandChildren: ReducerProtocol {
    internal struct State: Equatable {
        internal var text: String
    }
    
    internal enum Action: Equatable {
        case didTap
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .didTap:
            state.text = "Dummy GrandChildren"
            return .none
        }
    }
}

class GrandChildrenView: UIStackView {
    
    private let dummyButton = UIButton.template(title: "-+++++-")
    
    private let store: StoreOf<GrandChildren>
    private let disposeBag = DisposeBag()
    
    init(store: StoreOf<GrandChildren>) {
        self.store = store
        
        super.init(frame: .zero)
        
        axis = .vertical
        alignment = .leading
        
        addArrangedSubview(dummyButton)
        fillSuperview()
        
        dummyButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }
    
    @objc private func handleTap() {
        store.send(.didTap)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
