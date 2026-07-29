import Foundation

/// When backlogged phrases become part of the vocabulary.
///
/// Pure date math, no I/O: the app supplies `now` and the persisted
/// last-activation timestamp, and asks whether the overnight window has
/// passed since. "First timer tick after 4 AM" falls out of calling this
/// from a periodic timer and at launch.
public enum OvernightLearning {
    public static let activationHour = 4

    /// The most recent occurrence of the activation hour (wall-clock 4 AM) at or before `now`.
    /// DST-aware: on spring-forward and fall-back days, returns the literal wall-clock 4 AM,
    /// not an elapsed-hour arithmetic result.
    public static func threshold(before now: Date, calendar: Calendar = .current) -> Date {
        let todays = calendar.date(bySettingHour: activationHour, minute: 0, second: 0, of: now)!
        if todays <= now { return todays }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        return calendar.date(bySettingHour: activationHour, minute: 0, second: 0, of: yesterday)!
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
