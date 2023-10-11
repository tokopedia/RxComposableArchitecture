//
//  MockPageTemplate.swift
//  RxComposableArchitecture
//
//  Created by Wendy Liga on 07/07/21.
//

/**
 Use this template to help you create a list of behaviour on your `Example`, and also used it on MainApp's `BootstrapPicker`.
 Here is an example, I created a new VC named `MockViewController` to be used on `Example` and MainApp's `BootstrapPicker`.

 ## Example
 ```swift
  public final class MockViewController: MockPageTemplate {
      public init(isExample: Bool) {
          let mockNoInternet = Mock(
              title: "No Internet",
              apply: { [weak self] in
                  let noInternetEnvironment = HomeEnvironment(...)
                  Bootstrap.mock(environment: noInternetEnvironment)

                  if isExample {
                      let homeViewController = HomeViewController()
                      self?.navigationController.pushViewController(homeViewController, animated: true)
                  } else {
                      Toast.shared.display("Injected")
                  }
              }
          )

          var sections = [
              Section(
                  title: "Mock",
                  mocks: [mockNoInternet, ...],
                  footerTitle: "This section contains network-related mocks."
              ),
              ...
          ]
          super.init(sections: sections)
      }

      public required init?(coder _: NSCoder) {
          fatalError("init(coder:) has not been implemented")
      }
  }
 ```

 then on my Example `AppDelegate`. We recommend to place `MockViewController` on separate/new framework, so example and main app can import it.

 the parameter `isExample` here is very critical, because it gives flag to our `Mock` `apply(_:_:)` to push new viewController or not.
 on main app, we do not want to push viewController, but just apply `Bootstrap`
 ```swift
 internal func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
   window = UIWindow(frame: UIScreen.main.bounds)

 +   let viewController = MockViewController(isExample: true)
   let navController = UINavigationController(rootViewController: viewController)
   navController.navigationBar.isTranslucent = false
   window?.rootViewController = navController
   window?.makeKeyAndVisible()

   return true
 }
 ```
 */
#if DEBUG && canImport(UIKit)
    import UIKit

    public struct Section {
        public let title: String
        public let mocks: [Mock]
        public let footerTitle: String?

        public init(title: String, mocks: [Mock], footerTitle: String? = nil) {
            self.title = title
            self.mocks = mocks
            self.footerTitle = footerTitle
        }
    }

    // MARK: - Mock

    public struct Mock {
        public let title: String

        /// closure to apply the `Mock`,
        public let apply: () -> Void

        public init(title: String, apply: @escaping () -> Void) {
            self.title = title
            self.apply = apply
        }
    }

    open class MockPageTemplate: UITableViewController {
        // MARK: - Interface

        /// sections dataSource
        public var sections: [Section] {
            didSet {
                applySearchToSection(data: sections)
            }
        }

        // MARK: - Values

        private var searchKeyword: String?

        /// section that's filtered by `searchKeyword`
        private var filteredSections: [Section] = []

        // MARK: - Views

        private lazy var searchBar: UISearchBar = {
            let view = UISearchBar(frame: CGRect(x: 0, y: 0, width: 200, height: 20))
            view.placeholder = "search with name"
            view.delegate = self
            view.showsCancelButton = true

            if #available(iOS 13.0, *) {
                view.searchTextField.clearButtonMode = .never
            }

            return view
        }()

        private lazy var searchBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .search,
            target: self,
            action: #selector(showSearchBar)
        )

        // MARK: - Life Cycle

        /// Init
        /// - Parameters:
        ///   - sections: sections dataSource
        ///   - isExample: is used on `Example` ?
        public init(sections: [Section]) {
            self.sections = sections

            if #available(iOS 13.0, *) {
                super.init(style: .insetGrouped)
            } else {
                super.init(style: .grouped)
            }

            title = "Mocks"
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        }

        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override open func viewDidLoad() {
            super.viewDidLoad()

            navigationItem.rightBarButtonItem = searchBarButtonItem
        }

        // MARK: - Function

        private func applySearchToSection(data: [Section]) {
            guard let searchKeyword = searchKeyword, !searchKeyword.isEmpty else {
                filteredSections = data
                return
            }

            filteredSections = data
                .compactMap { section -> Section? in
                    let filteredMocks = section.mocks
                        .filter { $0.title.lowercased().contains(searchKeyword.lowercased()) }

                    if filteredMocks.isEmpty {
                        return nil
                    }

                    return Section(title: section.title, mocks: filteredMocks)
                }

            tableView.reloadData()
        }

        @objc
        private func showSearchBar() {
            navigationItem.titleView = searchBar
            navigationItem.rightBarButtonItem = nil
        }

        private func hideSearchBar() {
            navigationItem.rightBarButtonItem = searchBarButtonItem
            navigationItem.titleView = nil
        }
    }

    extension MockPageTemplate {
        override open func numberOfSections(in _: UITableView) -> Int {
            filteredSections.count
        }

        override open func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
            filteredSections[section].mocks.count
        }

        override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            filteredSections[indexPath.section].mocks[indexPath.row].apply()
        }

        override open func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") else {
                return UITableViewCell()
            }

            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.text = filteredSections[indexPath.section].mocks[indexPath.row].title

            return cell
        }

        override open func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
            filteredSections[section].title
        }

        override open func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
            filteredSections[section].footerTitle
        }
    }

    extension MockPageTemplate: UISearchBarDelegate {
        public func searchBarCancelButtonClicked(_: UISearchBar) {
            hideSearchBar()
        }

        public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchKeyword = searchBar.text
            applySearchToSection(data: sections)
            hideSearchBar()
        }

        public func searchBar(_: UISearchBar, textDidChange searchText: String) {
            searchKeyword = searchText
            applySearchToSection(data: sections)
        }
    }
#endif
