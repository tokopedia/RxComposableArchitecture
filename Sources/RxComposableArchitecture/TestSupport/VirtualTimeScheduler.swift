#if DEBUG
    import Foundation
    import RxSwift

    // swiftlint:disable explicit_acl
    // this is mostly a copy pasted code, so don't wanna bother much with linting
    /// A modified version of RxSwift's VirtualTimeScheduler to support advancing by relative time
    open class _VirtualTimeScheduler<Converter: VirtualTimeConverterType>:
        SchedulerType
    {
        public typealias VirtualTime = Converter.VirtualTimeUnit
        public typealias VirtualTimeInterval = Converter.VirtualTimeIntervalUnit

        private var _running: Bool

        private var _clock: VirtualTime

        fileprivate var _schedulerQueue: PriorityQueue<VirtualSchedulerItem<VirtualTime>>
        private var _converter: Converter

        private var _nextId = 0

        /// - returns: Current time.
        public var now: RxTime {
            return _converter.convertFromVirtualTime(clock)
        }

        /// - returns: Scheduler's absolute time clock value.
        public var clock: VirtualTime {
            return _clock
        }

        /// Creates a new virtual time scheduler.
        ///
        /// - parameter initialClock: Initial value for the clock.
        public init(initialClock: VirtualTime, converter: Converter) {
            _clock = initialClock
            _running = false
            _converter = converter
            _schedulerQueue = PriorityQueue(
                hasHigherPriority: {
                    switch converter.compareVirtualTime($0.time, $1.time) {
                    case .lessThan:
                        return true
                    case .equal:
                        return $0.id < $1.id
                    case .greaterThan:
                        return false
                    }
                }, isEqual: { $0 === $1 }
            )
            #if TRACE_RESOURCES
                _ = Resources.incrementTotal()
            #endif
        }

        /**
     Schedules an action to be executed immediately.
     - parameter state: State passed to the action to be executed.
     - parameter action: Action to be executed.
     - returns: The disposable object used to cancel the scheduled action (best effort).
     */
        public func schedule<StateType>(
            _ state: StateType, action: @escaping (StateType) -> Disposable
        )
            -> Disposable
        {
            return scheduleRelative(state, dueTime: .nanoseconds(0)) { a in
                action(a)
            }
        }

        /**
     Schedules an action to be executed.
     - parameter state: State passed to the action to be executed.
     - parameter dueTime: Relative time after which to execute the action.
     - parameter action: Action to be executed.
     - returns: The disposable object used to cancel the scheduled action (best effort).
     */
        public func scheduleRelative<StateType>(
            _ state: StateType, dueTime: RxTimeInterval, action: @escaping (StateType) -> Disposable
        ) -> Disposable {
            let time = now.addingTimeInterval(dueTime.convertToSecondsInterval)
            let absoluteTime = _converter.convertToVirtualTime(time)
            let adjustedTime = adjustScheduledTime(absoluteTime)
            return scheduleAbsoluteVirtual(state, time: adjustedTime, action: action)
        }

        /**
     Schedules an action to be executed after relative time has passed.
     - parameter state: State passed to the action to be executed.
     - parameter time: Absolute time when to execute the action. If this is less or equal then `now`, `now + 1`  will be used.
     - parameter action: Action to be executed.
     - returns: The disposable object used to cancel the scheduled action (best effort).
     */
        public func scheduleRelativeVirtual<StateType>(
            _ state: StateType, dueTime: VirtualTimeInterval,
            action: @escaping (StateType) -> Disposable
        ) -> Disposable {
            let time = _converter.offsetVirtualTime(clock, offset: dueTime)
            return scheduleAbsoluteVirtual(state, time: time, action: action)
        }

        /**
     Schedules an action to be executed at absolute virtual time.
     - parameter state: State passed to the action to be executed.
     - parameter time: Absolute time when to execute the action.
     - parameter action: Action to be executed.
     - returns: The disposable object used to cancel the scheduled action (best effort).
     */
        public func scheduleAbsoluteVirtual<StateType>(
            _ state: StateType, time: Converter.VirtualTimeUnit,
            action: @escaping (StateType) -> Disposable
        ) -> Disposable {
            MainScheduler.ensureExecutingOnScheduler()

            let compositeDisposable = CompositeDisposable()

            let item = VirtualSchedulerItem(
                action: {
                    let dispose = action(state)
                    return dispose
                }, time: time, id: _nextId
            )

            _nextId += 1

            _schedulerQueue.enqueue(item)

            _ = compositeDisposable.insert(item)

            return compositeDisposable
        }

        /// Adjusts time of scheduling before adding item to schedule queue.
        open func adjustScheduledTime(_ time: Converter.VirtualTimeUnit)
            -> Converter.VirtualTimeUnit
        {
            return time
        }

        /// Runs the scheduler until it has no scheduled items left.
        public func run() {
            MainScheduler.ensureExecutingOnScheduler()

            if _running {
                return
            }

            _running = true
            repeat {
                guard let next = findNext() else {
                    break
                }

                if _converter.compareVirtualTime(next.time, clock).greaterThan {
                    _clock = next.time
                }

                next.invoke()
                _schedulerQueue.remove(next)
            } while _running

            _running = false
        }

        func findNext() -> VirtualSchedulerItem<VirtualTime>? {
            while let front = _schedulerQueue.peek() {
                if front.isDisposed {
                    _schedulerQueue.remove(front)
                    continue
                }

                return front
            }

            return nil
        }

        /// Advances the scheduler's clock to the specified time, running all work till that point.
        ///
        /// - parameter virtualTime: Absolute time to advance the scheduler's clock to.
        public func advance(to virtualTime: VirtualTime) {
            MainScheduler.ensureExecutingOnScheduler()

            if _running {
                fatalError("Scheduler is already running")
            }

            _running = true
            repeat {
                guard let next = findNext() else {
                    break
                }

                if _converter.compareVirtualTime(next.time, virtualTime).greaterThan {
                    break
                }

                if _converter.compareVirtualTime(next.time, clock).greaterThan {
                    _clock = next.time
                }

                next.invoke()
                _schedulerQueue.remove(next)
            } while _running

            _clock = virtualTime
            _running = false
        }

        public func advance(by virtualInterval: VirtualTimeInterval) {
            let absoluteTime = _converter.offsetVirtualTime(clock, offset: virtualInterval)

            advance(to: absoluteTime)
        }

        #if TRACE_RESOURCES
            deinit {
                _ = Resources.decrementTotal()
            }
        #endif
    }

    // MARK: description

    extension _VirtualTimeScheduler: CustomDebugStringConvertible {
        /// A textual representation of `self`, suitable for debugging.
        public var debugDescription: String {
            return _schedulerQueue.debugDescription
        }
    }

    final class VirtualSchedulerItem<Time>:
        Disposable
    {
        typealias Action = () -> Disposable

        let action: Action
        let time: Time
        let id: Int

        var isDisposed: Bool {
            return disposable.isDisposed
        }

        var disposable = SingleAssignmentDisposable()

        init(action: @escaping Action, time: Time, id: Int) {
            self.action = action
            self.time = time
            self.id = id
        }

        func invoke() {
            disposable.setDisposable(action())
        }

        func dispose() {
            disposable.dispose()
        }
    }

    extension VirtualSchedulerItem:
        CustomDebugStringConvertible
    {
        var debugDescription: String {
            return "\(time)"
        }
    }

    extension VirtualTimeComparison {
        /// lhs < rhs.
        var lessThan: Bool {
            return self == .lessThan
        }

        /// lhs > rhs
        var greaterThan: Bool {
            return self == .greaterThan
        }

        /// lhs == rhs
        var equal: Bool {
            return self == .equal
        }
    }
#endif
