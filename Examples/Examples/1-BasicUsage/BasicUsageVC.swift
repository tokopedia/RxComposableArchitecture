//
//  BasicUsageVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 17/05/22.
//

import RxComposableArchitecture
import RxSwift
import UIKit

class BasicUsageVC: UIScrollVC {
    private let explanationTextView: UILabel = {
        let text = UILabel()
        text.text = "This is a demo for Basic usage State, Action, Reducer, and how to bind it to the UI"
        text.numberOfLines = 0
        return text
    }()
    private let plusButton = UIButton.template(title: "+")
    
    private let minusButton = UIButton.template(title: "-")
    
    private let numberLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .largeTitle)
        return label
    }()
    
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .red
        return label
    }()
    
    private let store: Store<BasicState, BasicAction>
    
    init(store: Store<BasicState, BasicAction>) {
        self.store = store
        super.init()
        title = "Basic Usage of State, Action & Reducer"
    }
    
    override func loadView() {
        super.loadView()
        let horizontalStack = UIStackView.horizontal(subviews: [minusButton, numberLabel, plusButton])
        horizontalStack.alignment = .center
        let stack = UIStackView.vertical(subviews: [explanationTextView, horizontalStack, errorLabel], spacing: 16)
        stack.alignment = .center
        contentView.addSubview(stack)
        stack.fillSuperview()
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
