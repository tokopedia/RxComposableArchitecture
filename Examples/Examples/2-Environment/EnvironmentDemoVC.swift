//
//  EnvironmentDemoVC.swift
//  Examples
//
//  Created by jefferson.setiawan on 02/06/22.
//

import RxComposableArchitecture
import UIKit

class EnvironmentDemoVC: UIScrollVC {
    private let explanationTextView: UITextView = {
        let textView = UITextView()
        textView.text = """
            In this example, you will learn how to use Environment.
            You'll also learn how to use side effect (such as networking and analytics)
            Because we can initialize the environment in init, you can easily swap the environment from the EnvironmentRoute.swift. You can try to change from .live to .mock
            """
        textView.isScrollEnabled = false
        return textView
    }()

    private let textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private let dateTextLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private let uuidTextLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private let loadingIndicator = UIActivityIndicatorView()

    private let reloadButton = UIButton.template(title: "Reload")
    private let getDateButton = UIButton.template(title: "Get new Date")
    private let getUUIDButton = UIButton.template(title: "Get new UUID")

    private let store: Store<EnvironmentState, EnvironmentAction>

    init(store: Store<EnvironmentState, EnvironmentAction>) {
        self.store = store
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let stack = UIStackView.vertical(
            subviews: [
                explanationTextView,
                UIStackView.vertical(subviews: [
                    UIStackView.horizontal(subviews: [textLabel, loadingIndicator]),
                    reloadButton,
                    UIView.divider(),
                ]),
                UIStackView.vertical(subviews: [dateTextLabel, getDateButton, UIView.divider()]),
                UIStackView.vertical(subviews: [uuidTextLabel, getUUIDButton]),
            ], spacing: 8)

        contentView.addSubview(stack)
        stack.fillSuperview(padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16))

        reloadButton.addTarget(self, action: #selector(didTapReload), for: .touchUpInside)
        getDateButton.addTarget(self, action: #selector(didTapGetDate), for: .touchUpInside)
        getUUIDButton.addTarget(self, action: #selector(didTapGenerateUUID), for: .touchUpInside)

        bindState()
        store.send(.didLoad)
    }

    private func bindState() {
        store.subscribe(\.text)
            .subscribe(onNext: { [textLabel] in
                textLabel.text = $0
            })
            .disposed(by: disposeBag)

        store.subscribe(\.uuidString)
            .subscribe(onNext: { [uuidTextLabel] in
                uuidTextLabel.text = $0
            })
            .disposed(by: disposeBag)

        store.subscribe(\.currentDate)
            .map {
                $0.map { date -> String in
                    let formatter = DateFormatter()
                    formatter.dateStyle = .full
                    formatter.timeStyle = .full
                    return formatter.string(from: date)
                }
            }
            .subscribe(onNext: { [dateTextLabel] in
                dateTextLabel.text = $0
            })
            .disposed(by: disposeBag)

        store.subscribe(\.alertMessage)
            .subscribe(onNext: { [weak self] message in
                if let message = message {
                    let alert = UIAlertController(
                        title: message, message: nil, preferredStyle: .alert)
                    let okAction = UIAlertAction(
                        title: "Ok", style: .default,
                        handler: { _ in
                            self?.store.send(.dismissAlert)
                        })
                    alert.addAction(okAction)
                    self?.navigationController?.present(alert, animated: true)
                }
            })
            .disposed(by: disposeBag)

        store.subscribe(\.isLoading)
            .subscribe(onNext: { [loadingIndicator] in
                if $0 {
                    loadingIndicator.startAnimating()
                } else {
                    loadingIndicator.stopAnimating()
                }
            })
            .disposed(by: disposeBag)
    }

    @objc private func didTapReload() {
        store.send(.refresh)
    }

    @objc private func didTapGetDate() {
        store.send(.getCurrentDate)
    }

    @objc private func didTapGenerateUUID() {
        store.send(.generateUUID)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
