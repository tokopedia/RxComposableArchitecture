//
//  UIKit+Helper.swift
//  Examples
//
//  Created by jefferson.setiawan on 03/06/22.
//

import UIKit

extension UIButton {
    static func template(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .largeTitle)
        return button
    }
}

extension UIStackView {
    static func vertical(subviews: [UIView], spacing: CGFloat = 0) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: subviews)
        stack.axis = .vertical
        stack.spacing = spacing
        return stack
    }

    static func horizontal(subviews: [UIView], spacing: CGFloat = 0) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: subviews)
        stack.axis = .horizontal
        stack.spacing = spacing
        return stack
    }
}

extension UIView {
    static func divider() -> UIView {
        let view = UIView()
        view.backgroundColor = .gray
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 2)
        ])
        return view
    }
}
