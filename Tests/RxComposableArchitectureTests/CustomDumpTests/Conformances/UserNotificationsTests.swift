#if canImport(UserNotifications)
  import RxComposableArchitecture
  import XCTest
  import UserNotifications
import CustomDump

  class UserNotificationsTests: XCTestCase {
    func testUNAuthorizationOptions() {
      var dump: String = ""
      customDump([.badge, .alert] as UNAuthorizationOptions, to: &dump)
      XCTAssertEqual(
        dump,
        """
        Set([
          UNAuthorizationOptions.alert,
          UNAuthorizationOptions.badge
        ])
        """
      )
    }
  }
#endif
