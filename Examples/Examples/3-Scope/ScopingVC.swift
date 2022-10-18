//
//  ScopingVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import RxComposableArchitecture
import RxSwift
import UIKit

class ScopingVC: UIScrollVC {
    private let explanationTextView: UITextView = {
        let textView = UITextView()
        textView.text = """
            Scope can means giving the child only what it need (ChildState, ChildAction) even ChildEnvironment. The purpose is to make sure that the child can't change or do what it should not do.
            """
        textView.isScrollEnabled = false
        return textView
    }()

    private let textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private let jumpTo100Button = UIButton.template(title: "Change to 100")

    private let counterView: CounterView

    private let store: Store<ScopingState, ScopingAction>

    init(store: Store<ScopingState, ScopingAction>) {
        self.store = store
        counterView = CounterView(
            store: store.scope(
                state: \.counter,
                action: ScopingAction.counter
            ))
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let stack = UIStackView.vertical(
            subviews: [
                explanationTextView,
                UIStackView.horizontal(subviews: [textLabel]),
                jumpTo100Button,
                counterView,
            ], spacing: 8)
        stack.alignment = .center

        contentView.addSubview(stack)
        stack.fillSuperview(padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16))

        jumpTo100Button.addTarget(self, action: #selector(didTapJump), for: .touchUpInside)
    }

    @objc private func didTapJump() {
        store.send(.didTapJump)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class CounterView: UIStackView {
    private let plusButton = UIButton.template(title: "+")

    private let minusButton = UIButton.template(title: "-")

    private let numberLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .largeTitle)
        return label
    }()

    private let store: Store<CounterState, CounterAction>
    private let disposeBag = DisposeBag()

    init(store: Store<CounterState, CounterAction>) {
        self.store = store
        super.init(frame: .zero)
        alignment = .center
        self.addArrangedSubview(minusButton)
        self.addArrangedSubview(numberLabel)
        self.addArrangedSubview(plusButton)

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
