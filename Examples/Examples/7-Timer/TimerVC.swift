//
//  TimerVC.swift
//  Examples
//
//  Created by victor.cuaca on 07/10/22.
//

import RxComposableArchitecture
import RxSwift
import UIKit

class TimerVC: UIScrollVC {
    private let explanationTextView: UILabel = {
        let text = UILabel()
        text.text = "This is a demo of a timer."
        text.numberOfLines = 0
        return text
    }()
    
    private let tickCountLabel = UILabel()
       
    private let store: Store<TimerState, TimerAction>
    
    init(store: Store<TimerState, TimerAction>) {
        self.store = store
        super.init()
        title = "Timer Demo"
    }
    
    override func loadView() {
        super.loadView()
        let stack = UIStackView.vertical(subviews: [
            explanationTextView, tickCountLabel
        ], spacing: 16)
        stack.alignment = .center
        contentView.addSubview(stack)
        stack.fillSuperview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        store.subscribe(\.tickCount)
            .subscribe(onNext: { [tickCountLabel] tickCount in
                tickCountLabel.text = "\(tickCount)"
            })
            .disposed(by: disposeBag)
        
        store.send(.onDidLoad)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
