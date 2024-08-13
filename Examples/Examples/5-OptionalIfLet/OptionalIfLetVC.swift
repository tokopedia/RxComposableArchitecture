//
//  OptionalIfLetVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 06/06/22.
//

import RxComposableArchitecture
import RxSwift
import UIKit

class OptionalIfLetVC: UIScrollVC {
    private let explanationTextView: UITextView = {
        let textView = UITextView()
        textView.text = """
        IfLet is used usually when you have an optional property that you need to scoped.
        """
        textView.isScrollEnabled = false
        return textView
    }()
    
    private let textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private let switchLabelView: UILabel = {
        let label = UILabel()
        label.text = "Toggle Counter View"
        label.numberOfLines = 0
        return label
    }()
    private let switchView = UISwitch()
    
    private var counterView: CounterView?
    
    private let store: StoreOf<OptionalIfLet>
    
    private let stackView: UIStackView
    
    init(store: StoreOf<OptionalIfLet>){
        self.store = store
        stackView = UIStackView.vertical(subviews: [
            explanationTextView,
            textLabel,
            UIStackView.horizontal(subviews: [switchLabelView, switchView], spacing: 16)
        ], spacing: 8)
        stackView.alignment = .center
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentView.addSubview(stackView)
        stackView.fillSuperview(padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16))
        
        switchView.addTarget(self, action: #selector(didTapSwitch), for: .touchUpInside)
        bindState()
    }
    
    private func bindState() {
        store.subscribe(\.number)
            .subscribe(onNext: { [textLabel] in
                textLabel.text = "Last saved number: \($0)"
            })
            .disposed(by: disposeBag)
        
        store.scope(
            state: \.counter,
            action: OptionalIfLet.Action.counter
        ).ifLet(then: { [weak self] wrappedStore in
            let counterView = CounterView(store: wrappedStore)
            self?.counterView = counterView
            self?.stackView.addArrangedSubview(counterView)
        }, else: { [weak self] in
            self?.counterView?.removeFromSuperview()
            self?.counterView = nil
        })
        .disposed(by: disposeBag)
    }
    
    @objc private func didTapSwitch() {
        store.send(.didToggle)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
