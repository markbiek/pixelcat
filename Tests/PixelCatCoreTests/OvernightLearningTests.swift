import Testing
import Foundation
@testable import PixelCatCore

@Suite struct OvernightLearningTests {
    /// A fixed calendar so tests don't depend on the machine's timezone.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 7, day: day, hour: hour, minute: minute
        ))!
    }

    @Test func thresholdIsTodayAt4AMWhenPast4AM() {
        #expect(
            OvernightLearning.threshold(before: date(29, 9), calendar: calendar)
                == date(29, 4)
        )
    }

    @Test func thresholdIsYesterdayAt4AMWhenBefore4AM() {
        #expect(
            OvernightLearning.threshold(before: date(29, 2), calendar: calendar)
                == date(28, 4)
        )
    }

    @Test func firstRunActivates() {
        #expect(OvernightLearning.shouldActivate(
            now: date(29, 9), lastActivation: nil, calendar: calendar
        ))
    }

    @Test func activatesWhenLastActivationWasBeforeThisMorning() {
        // Learned yesterday morning; it's now 9 AM the next day.
        #expect(OvernightLearning.shouldActivate(
            now: date(29, 9), lastActivation: date(28, 4, 30), calendar: calendar
        ))
    }

    @Test func doesNotActivateTwiceInOneDay() {
        // Already activated at 4:30 this morning; it's now 11 PM.
        #expect(!OvernightLearning.shouldActivate(
            now: date(29, 23), lastActivation: date(29, 4, 30), calendar: calendar
        ))
    }

    @Test func doesNotActivateEarlyMorningBeforeTheHour() {
        // Activated yesterday at 5 AM; it's now 3 AM — the next window
        // hasn't opened yet.
        #expect(!OvernightLearning.shouldActivate(
            now: date(29, 3), lastActivation: date(28, 5), calendar: calendar
        ))
    }

    @Test func activatesAtLaunchAfterDaysAway() {
        #expect(OvernightLearning.shouldActivate(
            now: date(29, 12), lastActivation: date(20, 4, 30), calendar: calendar
        ))
    }
}
