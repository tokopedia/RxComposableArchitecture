//
//  BasicUsageVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 17/05/22.
//

import RxComposableArchitecture
import RxSwift
import UIKit

struct BasicState: Equatable {
    var number: Int
    var errorMessage: String?
}

enum BasicAction: Equatable {
    case didTapPlus
    case didTapMinus
}

let basicUsageReducer = Reducer<BasicState, BasicAction, Void> { state, action, _ in
    switch action {
    case .didTapMinus:
        guard state.number > 0 else {
            state.errorMessage = "Can't below 0"
            return .none
        }
        state.number -= 1
        state.errorMessage = nil
        return .none
    case .didTapPlus:
        state.number += 1
        state.errorMessage = nil
        return .none
    }
}

class BasicUsageVC: UIViewController {
    private let explanationTextView: UILabel = {
        let text = UILabel()
        text.text = "This is a demo for Basic usage State, Action, Reducer, and how to bind it to the UI"
        text.numberOfLines = 0
        return text
    }()
    private let plusButton: UIButton = {
        let btn = UIButton()
        btn.setTitle("+", for: .normal)
        btn.setTitleColor(.blue, for: .normal)
        return btn
    }()
    
    private let minusButton: UIButton = {
        let btn = UIButton()
        btn.setTitle("-", for: .normal)
        btn.setTitleColor(.blue, for: .normal)
        return btn
    }()
    
    private let numberLabel = UILabel()
    
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .red
        return label
    }()
    
    private let store: Store<BasicState, BasicAction>
    private let disposeBag = DisposeBag()
    
    init(store: Store<BasicState, BasicAction>) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        title = "Basic Usage"
    }
    
    override func loadView() {
        super.loadView()
        view.backgroundColor = .systemBackground
        let horizontalStack = UIStackView(arrangedSubviews: [minusButton, numberLabel, plusButton])
        horizontalStack.alignment = .center
        let stack = UIStackView(arrangedSubviews: [explanationTextView, horizontalStack, errorLabel])
        stack.axis = .vertical
        stack.alignment = .center
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor),
//            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
//            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        store.subscribe(\.number)
            .subscribe(onNext: { [numberLabel] in
                numberLabel.text = String($0)
            })
            .disposed(by: disposeBag)
        
        store.subscribe(\.errorMessage)
            .subscribe(onNext: { [errorLabel] in
                errorLabel.text = $0
            })
            .disposed(by: disposeBag)
        
        plusButton.addTarget(self, action: #selector(didTapPlus), for: .touchUpInside)
        minusButton.addTarget(self, action: #selector(didTapMinus), for: .touchUpInside)
    }
    
    @objc private func didTapPlus() {
        store.send(.didTapPlus)
    }
    
    @objc private func didTapMinus() {
        store.send(.didTapMinus)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
