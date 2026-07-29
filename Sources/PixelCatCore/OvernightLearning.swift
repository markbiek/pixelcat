import Foundation

/// When backlogged phrases become part of the vocabulary.
///
/// Pure date math, no I/O: the app supplies `now` and the persisted
/// last-activation timestamp, and asks whether the overnight window has
/// passed since. "First timer tick after 4 AM" falls out of calling this
/// from a periodic timer and at launch.
public enum OvernightLearning {
    public static let activationHour = 4

    /// The most recent occurrence of the activation hour at or before `now`.
    public static func threshold(before now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let todays = calendar.date(byAdding: .hour, value: activationHour, to: today)!
        if todays <= now { return todays }
        return calendar.date(byAdding: .day, value: -1, to: todays)!
    }

    public static func shouldActivate(
        now: Date,
        lastActivation: Date?,
        calendar: Calendar = .current
    ) -> Bool {
        guard let last = lastActivation else { return true }
        return last < threshold(before: now, calendar: calendar)
    }
}
