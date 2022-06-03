//
//  PullbackVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import RxComposableArchitecture
import RxSwift
import UIKit

class PullbackVC: UIScrollVC {
    private let explanationTextView: UITextView = {
        let textView = UITextView()
        textView.text = """
        Pullback is used when you want to break the reducer to smaller part, in this example, the min and plus action is handled by ChildScopeNode.reducer, when doing this, make sure you combine it to your parent Reducer (see this file `internal static var reducer`)

        From PointFree Pullback is transforming predicates on small, specific data into predicates on large, general data. For example, given a predicate on integers we could pull it back to be a predicate on user models by projecting into the user’s id field.
        More info on pullback: https://www.pointfree.co/blog/posts/22-some-news-about-contramap
            https://www.pointfree.co/episodes/ep69-composable-state-management-state-pullbacks
        """
        textView.isScrollEnabled = false
        return textView
    }()
    
    private let textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private let textField: UITextField = {
        let text = UITextField()
        text.placeholder = "Please type here..."
        return text
    }()
    
    private let counterView: CounterView
    
    private let store: Store<PullbackState, PullbackAction>
    
    private var observation: NSKeyValueObservation?
    
    init(store: Store<PullbackState, PullbackAction>) {
        self.store = store
        counterView = CounterView(store: store.scope(
            state: \.counter,
            action: PullbackAction.counter
        ))
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let stack = UIStackView.vertical(subviews: [
            explanationTextView,
            textLabel,
            textField,
            counterView
        ], spacing: 8)
        stack.alignment = .center
        contentView.addSubview(stack)
        stack.fillSuperview(padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16))
        
        textField.delegate = self
        
        bindState()
    }
    
    private func bindState() {
        store.subscribe(\.text)
            .subscribe(onNext: { [textLabel] in
                textLabel.text = $0
            })
            .disposed(by: disposeBag)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PullbackVC: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        store.send(.textDidChange(textField.text ?? ""))
        return true
    }
}
