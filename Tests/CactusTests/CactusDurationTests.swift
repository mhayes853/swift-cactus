import Cactus
import CustomDump
import Foundation
import Testing

@Suite("CactusDuration tests")
struct CactusDurationTests {
  @Test(
    "Equality",
    arguments: [
      (CactusDuration.seconds(1), CactusDuration.seconds(1), true),
      (.seconds(1), .seconds(2), false),
      (.seconds(1), .milliseconds(1000), true),
      (.milliseconds(1000), .milliseconds(1000), true),
      (.milliseconds(1001), .milliseconds(1001), true),
      (.nanoseconds(1000), .nanoseconds(1000), true),
      (.microseconds(1000), .microseconds(1000), true),
      (.seconds(1), .milliseconds(1001), false),
      (.nanoseconds(1_000_000_000), .milliseconds(1000), true),
      (.microseconds(1_323_000), .milliseconds(1323), true),
      (.microseconds(1_323_001), .milliseconds(1323), false),
      (.nanoseconds(1.323e+9), .milliseconds(1323), true),
      (.seconds(0.5), .milliseconds(500), true),
      (.seconds(0.5), .seconds(0.51), false),
      (.seconds(0.5), .milliseconds(501), false),
      (.nanoseconds(1323), .microseconds(1.323), true),
      (.microseconds(13230), .milliseconds(13.23), true),
      (.nanoseconds(13.23), .microseconds(0.01323), true),
      (.microseconds(500), .milliseconds(0.5), true),
      (.nanoseconds(0.5), .microseconds(0.0005), true),
      (.seconds(1), .seconds(1.0), true),
      (.nanoseconds(1), .nanoseconds(1.0), true),
      (.microseconds(1), .microseconds(1.0), true),
      (.milliseconds(1), .milliseconds(1.0), true),
      (.seconds(-1), .seconds(1), false),
      (.seconds(-1), -.seconds(1), true),
      (.seconds(-1), .seconds(-1), true),
      (.milliseconds(-1000), .seconds(-1), true),
      (.milliseconds(-1500), .seconds(-1.5), true),
      (.milliseconds(-1500), .nanoseconds(-1_500_000_000), true),
      (.nanoseconds(-1500), .microseconds(-1.5), true)
    ]
  )
  func equality(d1: CactusDuration, d2: CactusDuration, isEqual: Bool) {
    if isEqual {
      expectNoDifference(d1, d2)
    } else {
      withKnownIssue {
        expectNoDifference(d1, d2)
      }
    }
  }

  @Test(
    "Duration Equality",
    arguments: [
      (CactusDuration.seconds(1), Duration.seconds(1), true),
      (.seconds(1), .seconds(2), false),
      (.seconds(1), .milliseconds(1000), true),
      (.milliseconds(1000), .milliseconds(1000), true),
      (.milliseconds(1001), .milliseconds(1001), true),
      (.nanoseconds(1000), .nanoseconds(1000), true),
      (.microseconds(1000), .microseconds(1000), true),
      (.seconds(1), .milliseconds(1001), false),
      (.nanoseconds(1_000_000_000), .milliseconds(1000), true),
      (.microseconds(1_323_000), .milliseconds(1323), true),
      (.microseconds(1_323_001), .milliseconds(1323), false),
      (.nanoseconds(1.323e+9), .milliseconds(1323), true),
      (.seconds(0.5), .milliseconds(500), true),
      (.seconds(0.5), .seconds(0.51), false),
      (.seconds(0.5), .milliseconds(501), false),
      (.nanoseconds(1323), .microseconds(1.323), true),
      (.microseconds(13230), .milliseconds(13.23), true),
      (.nanoseconds(13.23), .microseconds(0.01323), true),
      (.microseconds(500), .milliseconds(0.5), true),
      (.nanoseconds(0.5), .microseconds(0.0005), true),
      (.seconds(1), .seconds(1.0), true),
      (.microseconds(1), .microseconds(1.0), true),
      (.milliseconds(1), .milliseconds(1.0), true),
      (.seconds(-1), .seconds(1), false),
      (.seconds(-1), .seconds(-1), true),
      (.milliseconds(-1000), .seconds(-1), true),
      (.milliseconds(-1500), .seconds(-1.5), true),
      (.milliseconds(-1500), .nanoseconds(-1_500_000_000), true),
      (.nanoseconds(-1500), .microseconds(-1.5), true)
    ]
  )
  @available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
  func durationEquality(d1: CactusDuration, d2: Duration, isEqual: Bool) {
    if isEqual {
      expectNoDifference(d1, CactusDuration(duration: d2))
      expectNoDifference(Duration(duration: d1), d2)
    } else {
      withKnownIssue {
        expectNoDifference(d1, CactusDuration(duration: d2))
      }
      withKnownIssue {
        expectNoDifference(Duration(duration: d1), d2)
      }
    }
  }

  @Test(
    "Comparability",
    arguments: [
      (CactusDuration.seconds(1), CactusDuration.seconds(1.1), true),
      (.seconds(1), .seconds(2), true),
      (.seconds(1), .milliseconds(1001), true),
      (.milliseconds(1000), .milliseconds(1000), false),
      (.nanoseconds(999_999_999), .milliseconds(1000), true),
      (.microseconds(1_322_995), .milliseconds(1323), true),
      (.seconds(0.49), .milliseconds(500), true),
      (.seconds(0.5), .seconds(0.51), true),
      (.seconds(0.5), .milliseconds(501), true),
      (.nanoseconds(1324), .microseconds(1.323), false),
      (.microseconds(13181), .milliseconds(13.23), true),
      (.nanoseconds(13.22), .microseconds(0.01323), true),
      (.microseconds(501), .milliseconds(0.5), false),
      (.seconds(-1), .seconds(1), true),
      (.seconds(-1), .seconds(-1), false),
      (.milliseconds(-999), .seconds(-1), false),
      (.milliseconds(-1501), .seconds(-1.5), true)
    ]
  )
  func comparability(d1: CactusDuration, d2: CactusDuration, isLessThan: Bool) {
    expectNoDifference(d1 < d2, isLessThan)
  }

  @Test(
    "Addition",
    arguments: [
      (CactusDuration.seconds(1), CactusDuration.seconds(1), CactusDuration.seconds(2)),
      (.seconds(1), .seconds(2), .seconds(3)),
      (.seconds(1), .milliseconds(1000), .seconds(2)),
      (.milliseconds(1000), .milliseconds(1000), .seconds(2)),
      (.milliseconds(1001), .milliseconds(1001), .milliseconds(2002)),
      (.nanoseconds(1000), .nanoseconds(1000), .nanoseconds(2000)),
      (.microseconds(1000), .microseconds(1000), .microseconds(2000)),
      (.seconds(1), .milliseconds(1001), .milliseconds(2001)),
      (.seconds(1.5), .milliseconds(750), .seconds(2.25)),
      (.seconds(1.5), .milliseconds(1750), .seconds(3.25)),
      (.seconds(1.5), .milliseconds(-500), .seconds(1)),
      (.seconds(1.5), .milliseconds(-2000), .seconds(-0.5)),
      (.seconds(1.5), .milliseconds(-3000), .seconds(-1.5)),
      (.seconds(-0.5), .milliseconds(1000), .seconds(0.5)),
      (.zero, .milliseconds(-1), .milliseconds(-1)),
      (.seconds(1.5), .milliseconds(-4500), .seconds(-3)),
      (.seconds(1.5), .milliseconds(-1700), .seconds(-0.2)),
      (.seconds(1.5), .zero, .seconds(1.5)),
      (.zero, .zero, .zero),
      (.milliseconds(5900), .milliseconds(5900), .milliseconds(11_800)),
      (.milliseconds(5500), .milliseconds(5400), .milliseconds(10_900)),
      (.seconds(-10), .milliseconds(-1000), .seconds(-11)),
      (.seconds(-10), .milliseconds(1000), .seconds(-9)),
      (.milliseconds(-3300), .milliseconds(4100), .milliseconds(800)),
      (.milliseconds(-3300), .milliseconds(3900), .milliseconds(600)),
      (.milliseconds(-3300), .milliseconds(4900), .milliseconds(1600)),
      (.milliseconds(-3300), .milliseconds(5300), .milliseconds(2000)),
      (.milliseconds(1300), .milliseconds(1900), .milliseconds(3200)),
      (.milliseconds(-3100), .milliseconds(2100), .milliseconds(-1000)),
      (.milliseconds(-3100), .milliseconds(2200), .milliseconds(-900))
    ]
  )
  func addition(d1: CactusDuration, d2: CactusDuration, summed: CactusDuration) {
    expectNoDifference(d1 + d2, summed)
  }

  @Test(
    "Subtraction",
    arguments: [
      (CactusDuration.seconds(1), CactusDuration.seconds(1), CactusDuration.zero),
      (.seconds(1), .seconds(2), .seconds(-1)),
      (.seconds(1), .milliseconds(1000), .zero),
      (.milliseconds(1000), .milliseconds(1000), .zero),
      (.milliseconds(1001), .milliseconds(1001), .zero),
      (.nanoseconds(1000), .nanoseconds(1000), .zero),
      (.microseconds(1000), .microseconds(1000), .zero),
      (.seconds(1), .milliseconds(1001), .milliseconds(-1)),
      (.seconds(1.5), .milliseconds(750), .seconds(0.75)),
      (.seconds(1.5), .milliseconds(1750), .seconds(-0.25)),
      (.seconds(1.5), .milliseconds(-500), .seconds(2)),
      (.seconds(1.5), .milliseconds(2000), .seconds(-0.5)),
      (.seconds(1.5), .milliseconds(4500), .seconds(-3)),
      (.seconds(1.5), .milliseconds(1700), .seconds(-0.2)),
      (.zero, .milliseconds(-1), .milliseconds(1)),
      (.seconds(1.5), .zero, .seconds(1.5)),
      (.seconds(0.5), .seconds(0.75), .seconds(-0.25)),
      (.zero, .zero, .zero),
      (.seconds(-10), .milliseconds(-1000), .seconds(-9)),
      (.seconds(-1.5), .seconds(3.25), .seconds(-4.75)),
      (.seconds(-1.25), .seconds(2.75), .seconds(-4)),
      (.seconds(5), .seconds(5.75), .seconds(-0.75)),
      (.seconds(5), .seconds(6.75), .seconds(-1.75)),
      (.seconds(5.75), .seconds(6.5), .seconds(-0.75)),
      (.seconds(5.75), .seconds(7.5), .seconds(-1.75)),
      (.seconds(5), .seconds(4.75), .milliseconds(250)),
      (.seconds(5.75), .seconds(4.5), .seconds(1.25)),
      (.seconds(5.75), .seconds(5.5), .seconds(0.25)),
      (.seconds(1.5), .seconds(0.5), .seconds(1)),
      (.seconds(1.5), .milliseconds(400), .milliseconds(1100))
    ]
  )
  func subtraction(d1: CactusDuration, d2: CactusDuration, subbed: CactusDuration) {
    expectNoDifference(d1 - d2, subbed)
  }

  @Test(
    "Integer Multiplication",
    arguments: [
      (CactusDuration.seconds(1), 0, CactusDuration.zero),
      (.seconds(1), 10, .seconds(10)),
      (.seconds(5), 10, .seconds(50)),
      (.milliseconds(5500), 10, .seconds(55)),
      (.nanoseconds(5123), 126, .nanoseconds(645_498)),
      (.nanoseconds(5123), -126, .nanoseconds(-645_498)),
      (.nanoseconds(-5123), 126, .nanoseconds(-645_498)),
      (.nanoseconds(-5123), -126, .nanoseconds(645_498))
    ]
  )
  func integerMultiplication(d1: CactusDuration, d2: Int, multiplied: CactusDuration) {
    expectNoDifference(d1 * d2, multiplied)
  }

  @Test(
    "Integer Division",
    arguments: [
      (CactusDuration.seconds(1), 1, CactusDuration.seconds(1)),
      (.zero, 10, .zero),
      (.seconds(1), 10, .milliseconds(100)),
      (.seconds(5), 10, .milliseconds(500)),
      (.milliseconds(5500), 10, .seconds(0.55)),
      (.nanoseconds(5123), 1, .nanoseconds(5123)),
      (.nanoseconds(5000), 100, .nanoseconds(50)),
      (.nanoseconds(-5000), 100, .nanoseconds(-50)),
      (.nanoseconds(5000), -100, .nanoseconds(-50)),
      (.nanoseconds(-5000), -100, .nanoseconds(50))
    ]
  )
  func integerDivision(d1: CactusDuration, d2: Int, divided: CactusDuration) {
    expectNoDifference(d1 / d2, divided)
  }

  @Test(
    "Division",
    arguments: [
      (CactusDuration.seconds(1), CactusDuration.seconds(1), 1),
      (.nanoseconds(5), .milliseconds(2), 2.5e-06),
      (.milliseconds(5), .milliseconds(5), 1),
      (.milliseconds(5), .microseconds(2), 2500),
      (.milliseconds(5), .milliseconds(2), 2.5),
      (.nanoseconds(5), .nanoseconds(5), 1),
      (.nanoseconds(5), .seconds(5), 1e-09),
      (.milliseconds(5), .milliseconds(-2), -2.5),
      (.milliseconds(-5), .milliseconds(2), -2.5),
      (.milliseconds(-5), .milliseconds(-2), 2.5),
      (.microseconds(55), .milliseconds(100), 0.00055),
      (.milliseconds(55), .microseconds(123), 447.1544715447154),
      (.milliseconds(5.75), .microseconds(2), 2875)
    ]
  )
  func division(d1: CactusDuration, d2: CactusDuration, divided: Double) {
    expectNoDifference(d1 / d2, divided)
  }

  @Test("Attoseconds")
  @available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
  func attoseconds() {
    let d = CactusDuration(attoseconds: 123_456_789_123_456_789_123_456_789)
    expectNoDifference(d.attoseconds, 123_456_789_123_456_789_123_456_789)
    expectNoDifference(d.components.seconds, 123_456_789)
  }

  @Test(
    "Creates From Seconds And Attoseconds Components",
    arguments: [
      (
        CactusDuration(secondsComponent: 1, attosecondsComponent: 2_000_000_000_000_000_000),
        CactusDuration.seconds(3)
      ),
      (
        CactusDuration(secondsComponent: 1, attosecondsComponent: 1_500_000_000_000_000_000),
        .seconds(2.5)
      ),
      (
        CactusDuration(secondsComponent: 1, attosecondsComponent: 500_000_000_000_000_000),
        .seconds(1.5)
      ),
      (
        CactusDuration(secondsComponent: 1, attosecondsComponent: -500_000_000_000_000_000),
        .seconds(0.5)
      ),
      (
        CactusDuration(secondsComponent: -1, attosecondsComponent: -500_000_000_000_000_000),
        .seconds(-1.5)
      ),
      (
        CactusDuration(secondsComponent: -1, attosecondsComponent: 500_000_000_000_000_000),
        .seconds(-0.5)
      )
    ]
  )
  func createsFromSecondsAndAttosecondsComponents(d1: CactusDuration, d2: CactusDuration) {
    expectNoDifference(d1, d2)
  }

  @Test(
    "Codable",
    arguments: [
      CactusDuration.seconds(1),
      .seconds(1.23),
      .milliseconds(123_456),
      .microseconds(123_456_789),
      .nanoseconds(203_248_938_162),
      .seconds(129.19)
    ]
  )
  func codable(d: CactusDuration) throws {
    let data = try JSONEncoder().encode(d)
    expectNoDifference(try JSONDecoder().decode(CactusDuration.self, from: data), d)
  }
}
