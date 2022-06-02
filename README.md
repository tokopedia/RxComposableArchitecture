# RxComposableArchitecture

The Composable Architecture (TCA, for short) is a library for building applications in a consistent and understandable way, with composition, testing, and ergonomics in mind. This library is based on PointFree's Swift Composable Architecture.

* [What is the Composable Architecture?](#what-is-the-composable-architecture)
* [Learn more](#learn-more)
* [Examples](#examples)
* [Basic usage](#basic-usage)
* [Requirements](#requirements)
* [Installation](#installation)
* [What is the differences between RxComposable and TCA](#what-is-the-differences-between-rxcomposable-and-tca)
* [License](#license)

## What is the Composable Architecture?

This library provides a few core tools that can be used to build applications of varying purpose and complexity. It provides compelling stories that you can follow to solve many problems you encounter day-to-day when building applications, such as:

* **State management**
  <br> How to manage the state of your application using simple value types, and share state across many screens so that mutations in one screen can be immediately observed in another screen.

* **Composition**
  <br> How to break down large features into smaller components that can be extracted to their own, isolated modules and be easily glued back together to form the feature.

* **Side effects**
  <br> How to let certain parts of the application talk to the outside world in the most testable and understandable way possible.

* **Testing**
  <br> How to not only test a feature built in the architecture, but also write integration tests for features that have been composed of many parts, and write end-to-end tests to understand how side effects influence your application. This allows you to make strong guarantees that your business logic is running in the way you expect.

* **Ergonomics**
  <br> How to accomplish all of the above in a simple API with as few concepts and moving parts as possible.

## Learn More

The Composable Architecture was designed over the course of many episodes on [Point-Free](https://www.pointfree.co), a video series exploring functional programming and the Swift language, hosted by [Brandon Williams](https://twitter.com/mbrandonw) and [Stephen Celis](https://twitter.com/stephencelis).

You can watch all of the episodes [here](https://www.pointfree.co/collections/composable-architecture), as well as a dedicated, multipart tour of the architecture from scratch: [part 1](https://www.pointfree.co/collections/composable-architecture/a-tour-of-the-composable-architecture/ep100-a-tour-of-the-composable-architecture-part-1), [part 2](https://www.pointfree.co/collections/composable-architecture/a-tour-of-the-composable-architecture/ep101-a-tour-of-the-composable-architecture-part-2), [part 3](https://www.pointfree.co/collections/composable-architecture/a-tour-of-the-composable-architecture/ep102-a-tour-of-the-composable-architecture-part-3) and [part 4](https://www.pointfree.co/collections/composable-architecture/a-tour-of-the-composable-architecture/ep103-a-tour-of-the-composable-architecture-part-4).

<a href="https://www.pointfree.co/collections/composable-architecture">
  <img alt="video poster image" src="https://d3rccdn33rt8ze.cloudfront.net/episodes/0069.jpeg" width="600">
</a>

## Examples

This repo comes with examples to demonstrate how to solve common problems with the RxComposableArchitecture. Check out [this](./Examples) directory to see them all


Looking for something more substantial? Check out the source code for [isowords](https://github.com/pointfreeco/isowords), an iOS word search game built in SwiftUI and the Composable Architecture.

## Basic Usage

To build a feature using the Composable Architecture you define some types and values that model your domain:

* **State**: A type that describes the data your feature needs to perform its logic and render its UI.
* **Action**: A type that represents all of the actions that can happen in your feature, such as user actions, notifications, event sources and more.
* **Environment**: A type that holds any dependencies the feature needs, such as API clients, analytics clients, etc.
* **Reducer**: A function that describes how to evolve the current state of the app to the next state given an action. The reducer is also responsible for returning any effects that should be run, such as API requests, which can be done by returning an `Effect` value.
* **Store**: The runtime that actually drives your feature. You send all user actions to the store so that the store can run the reducer and effects, and you can observe state changes in the store so that you can update UI.

The benefits of doing this is that you will instantly unlock testability of your feature, and you will be able to break large, complex features into smaller domains that can be glued together.

As a basic example, consider a UI that shows a number along with "+" and "−" buttons that increment and decrement the number. To make things interesting, suppose there is also a button that when tapped makes an API request to fetch a random fact about that number and then displays the fact in an alert.

The state of this feature would consist of an integer for the current count, as well as an optional string that represents the title of the alert we want to show (optional because `nil` represents not showing an alert):

```swift
struct AppState: Equatable {
  var count = 0
  var numberFactAlert: String?
}
```

Next we have the actions in the feature. There are the obvious actions, such as tapping the decrement button, increment button, or fact button. But there are also some slightly non-obvious ones, such as the action of the user dismissing the alert, and the action that occurs when we receive a response from the fact API request:

```swift
enum AppAction: Equatable {
  case factAlertDismissed
  case decrementButtonTapped
  case incrementButtonTapped
  case numberFactButtonTapped
  case numberFactResponse(Result<String, ApiError>)
}

struct ApiError: Error, Equatable {}
```

Next we model the environment of dependencies this feature needs to do its job. In particular, to fetch a number fact we need to construct an `Effect` value that encapsulates the network request. So that dependency is a function from `Int` to `Effect<String>`, where `String` represents the response from the request. Further, the effect will typically do its work on a background thread (as is the case with `URLSession`), and so we need a way to receive the effect's values on the main queue. We do this via a main queue scheduler, which is a dependency that is important to control so that we can write tests. We must use an `AnyScheduler` so that we can use a live `MainScheduler.instance` from `RxSwift` in production and a test scheduler in tests.

```swift
struct AppEnvironment {
  var mainQueue: SchedulerType
  var numberFact: (Int) -> Effect<String>
}
```

Next, we implement a reducer that implements the logic for this domain. It describes how to change the current state to the next state, and describes what effects need to be executed. Some actions don't need to execute effects, and they can return `.none` to represent that:

```swift
let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  switch action {
  case .factAlertDismissed:
    state.numberFactAlert = nil
    return .none

  case .decrementButtonTapped:
    state.count -= 1
    return .none

  case .incrementButtonTapped:
    state.count += 1
    return .none

  case .numberFactButtonTapped:
    return environment.numberFact(state.count)
      .receive(on: environment.mainQueue)
      .catchToEffect(AppAction.numberFactResponse)

  case let .numberFactResponse(.success(fact)):
    state.numberFactAlert = fact
    return .none

  case .numberFactResponse(.failure):
    state.numberFactAlert = "Could not load a number fact :("
    return .none
  }
}
```

And then finally we define the view that displays the feature. It holds onto a `Store<AppState, AppAction>` so that it can observe all changes to the state and re-render, and we can send all user actions to the store so that state changes. We must also introduce a struct wrapper around the fact alert to make it `HashDiffable`, which the `.alert` view modifier requires:

```swift
  class AppViewController: UIViewController {
    private let store: Store<AppState, AppAction>
    private let disposeBag = DisposeBag()

    init(store: Store<AppState, AppAction>) {
      self.store = store
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
      super.viewDidLoad()

      let countLabel = UILabel()
      let incrementButton = UIButton()
      let decrementButton = UIButton()
      let factButton = UIButton()

      // Omitted: Add subviews and set up constraints...

      store.subscribe(\.number)
        .map { "\($0.count)" }
        .subscribe(onNext: { [numberLabel] in
            countLabel.text = String($0)
        })
        .disposed(by: disposeBag)

	  store.subscribe(\.numberFactAlert)
        .subscribe(onNext: { [weak self] numberFactAlert in
          let alertController = UIAlertController(
            title: numberFactAlert, message: nil, preferredStyle: .alert
          )
          alertController.addAction(
            UIAlertAction(
              title: "Ok",
              style: .default,
              handler: { _ in self?.store.send(.factAlertDismissed) }
            )
          )
          self?.present(alertController, animated: true, completion: nil)
        })
        .disposed(by: disposeBag)
    }

    @objc private func incrementButtonTapped() {
      store.send(.incrementButtonTapped)
    }
    @objc private func decrementButtonTapped() {
      store.send(.decrementButtonTapped)
    }
    @objc private func factButtonTapped() {
      store.send(.numberFactButtonTapped)
    }
  }
```

It's important to note that we were able to implement this entire feature without having a real, live effect at hand. This is important because it means features can be built in isolation without building their dependencies, which can help compile times.

Once we are ready to display this view, for example in the scene delegate, we can construct a store. This is the moment where we need to supply the dependencies, and for now we can just use an effect that immediately returns a mocked string:

```swift
let viewController = AppViewController(store: Store(
    initialState: AppState(),
    reducer: appReducer,
    environment: AppEnvironment(
      mainQueue: MainScheduler.instance,
      numberFact: { number in Effect(value: "\(number) is a good number Brent") }
    )
))
```

And that is enough to get something on the screen to play around with. It's definitely a few more steps than if you were to do this in a vanilla SwiftUI way, but there are a few benefits. It gives us a consistent manner to apply state mutations, instead of scattering logic in some observable objects and in various action closures of UI components. It also gives us a concise way of expressing side effects. And we can immediately test this logic, including the effects, without doing much additional work.

### Testing

To test, you first create a `TestStore` with the same information that you would to create a regular `Store`, except this time we can supply test-friendly dependencies. In particular, we use a test scheduler instead of the live `DispatchQueue.main` scheduler because that allows us to control when work is executed, and we don't have to artificially wait for queues to catch up.

```swift
let scheduler = TestScheduler(initialClock: 0)

let store = TestStore(
  initialState: AppState(),
  reducer: appReducer,
  environment: AppEnvironment(
    mainQueue: scheduler,
    numberFact: { number in Effect(value: "\(number) is a good number Brent") }
  )
)
```

Once the test store is created we can use it to make an assertion of an entire user flow of steps. Each step of the way we need to prove that state changed how we expect. Further, if a step causes an effect to be executed, which feeds data back into the store, we must assert that those actions were received properly.

The test below has the user increment and decrement the count, then they ask for a number fact, and the response of that effect triggers an alert to be shown, and then dismissing the alert causes the alert to go away.

```swift
// Test that tapping on the increment/decrement buttons changes the count
store.send(.incrementButtonTapped) {
  $0.count = 1
}
store.send(.decrementButtonTapped) {
  $0.count = 0
}

// Test that tapping the fact button causes us to receive a response from the effect. Note
// that we have to advance the scheduler because we used `.receive(on:)` in the reducer.
store.send(.numberFactButtonTapped)

scheduler.advance()
store.receive(.numberFactResponse(.success("0 is a good number Brent"))) {
  $0.numberFactAlert = "0 is a good number Brent"
}

// And finally dismiss the alert
store.send(.factAlertDismissed) {
  $0.numberFactAlert = nil
}
```

That is the basics of building and testing a feature in the Composable Architecture. There are _a lot_ more things to be explored, such as composition, modularity, adaptability, and complex effects. The [Examples](./Examples) directory has a bunch of projects to explore to see more advanced usages.

### Debugging

The Composable Architecture comes with a number of tools to aid in debugging.

* `reducer.debug()` enhances a reducer with debug-printing that describes every action the reducer receives and every mutation it makes to state.

    ``` diff
    received action:
      AppAction.todoCheckboxTapped(id: UUID(5834811A-83B4-4E5E-BCD3-8A38F6BDCA90))
      AppState(
        todos: [
          Todo(
    -       isComplete: false,
    +       isComplete: true,
            description: "Milk",
            id: 5834811A-83B4-4E5E-BCD3-8A38F6BDCA90
          ),
          … (2 unchanged)
        ]
      )
    ```

* `reducer.signpost()` instruments a reducer with signposts so that you can gain insight into how long actions take to execute, and when effects are running.

    <img src="https://s3.amazonaws.com/pointfreeco-production/point-free-pointers/0044-signposts-cover.jpg" width="600">

## Requirements

The Composable Architecture depends on the Combine framework, so it requires minimum deployment targets of iOS 11.

## Installation

### Swift Package Manager
You can add ComposableArchitecture to an Xcode project by adding it as a package dependency.

  1. From the **File** menu, select **Add Packages...**
  2. Enter "https://github.com/tokopedia/RxComposableArchitecture" into the package repository URL text field
  3. Depending on how your project is structured:
      - If you have a single application target that needs access to the library, then add **ComposableArchitecture** directly to your application.
      - If you want to use this library from multiple Xcode targets, or mixing Xcode targets and SPM targets, you must create a shared framework that depends on **ComposableArchitecture** and then depend on that framework in all of your targets. For an example of this, check out the [Tic-Tac-Toe](./Examples/TicTacToe) demo application, which splits lots of features into modules and consumes the static library in this fashion using the **tic-tac-toe** Swift package.
### Cocoapods
Add this into your Podfile
```
pod "RxComposableArchitecture", , :git => 'https://github.com/tokopedia/RxComposableArchitecture', :tag => '0.17'
```

## What is the differences between RxComposable and TCA
- Use of `RxSwift` instead of `Combine` (to support iOS<13) as the Reactive backbone.
- Use of `HashDiffable` instead of `Identifiable`
- Effect only have 1 generic, doesn't have Error counterpart.
- We are not using `ViewStore`, because on UIKit, we don't need the presence of `ViewStore` yet.

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.