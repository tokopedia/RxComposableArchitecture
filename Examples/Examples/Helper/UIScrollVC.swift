//
//  UIScrollVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import RxSwift
import UIKit

class UIScrollVC: UIViewController {
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    let contentView = UIView()
    
    let disposeBag = DisposeBag()
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    override func loadView() {
        super.loadView()
        setupScrollView()
        scrollView.backgroundColor = .systemBackground
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        let centerYConstraint = contentView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        centerYConstraint.priority = .defaultLow
        centerYConstraint.isActive = true
        
        let bottomContentViewConstraint = contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        bottomContentViewConstraint.priority = .defaultLow
        bottomContentViewConstraint.isActive = true
        
        scrollView.fill(to: view)
        
        contentView.anchor(
            top: scrollView.topAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor,
            centerX: scrollView.centerXAnchor
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
