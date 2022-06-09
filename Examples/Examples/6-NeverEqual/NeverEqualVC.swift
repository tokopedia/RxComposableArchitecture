//
//  NeverEqualVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import RxComposableArchitecture
import RxSwift
import UIKit

class NeverEqualVC: UIScrollVC {
    private let explanationTextView: UILabel = {
        let text = UILabel()
        text.text = "This is a demo of NeverEqual property wrapper usage."
        text.numberOfLines = 0
        return text
    }()
    private let showAlertButton = UIButton.template(title: "Show Alert")
    
    private let tallView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemMint
        view.heightAnchor.constraint(equalToConstant: 400).isActive = true
        return view
    }()
    
    private let tallView2: UIView = {
        let view = UIView()
        view.backgroundColor = .systemTeal
        view.heightAnchor.constraint(equalToConstant: 700).isActive = true
        return view
    }()
    
    private let scrollToTopButton = UIButton.template(title: "Scroll to Top")
    
    private let store: Store<NeverEqualState, NeverEqualAction>
    
    init(store: Store<NeverEqualState, NeverEqualAction>) {
        self.store = store
        super.init()
        title = "NeverEqual Demo"
    }
    
    override func loadView() {
        super.loadView()
        let stack = UIStackView.vertical(subviews: [
            explanationTextView, showAlertButton, tallView, tallView2, scrollToTopButton
        ], spacing: 16)
        contentView.addSubview(stack)
        stack.fillSuperview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        store.subscribeNeverEqual(\.$showAlert)
            .subscribe(onNext: { [weak self] message in
                if let message = message {
                    let alert = UIAlertController(title: message, message: nil, preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "Ok", style: .default)
                    alert.addAction(okAction)
                    self?.navigationController?.present(alert, animated: true)
                }
            })
            .disposed(by: disposeBag)
        
        store.subscribeNeverEqual(\.$scrollToTop)
            .filter { $0 != nil }
            .subscribe(onNext: { [weak self] _ in
                self?.scrollView.scrollToTop()
            })
            .disposed(by: disposeBag)
        
        showAlertButton.addTarget(self, action: #selector(didTapShowAlert), for: .touchUpInside)
        scrollToTopButton.addTarget(self, action: #selector(didTapScrollToTop), for: .touchUpInside)
    }
    
    @objc private func didTapShowAlert() {
        store.send(.didTapShowAlert)
    }
    
    @objc private func didTapScrollToTop() {
        store.send(.didTapScrollToTop)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension UIScrollView {
    public func scrollToTop(animated: Bool = true) {
        let inset = self.contentInset
        
        self.setContentOffset(CGPoint(x: -inset.left, y: -inset.top), animated: animated)
    }
}
