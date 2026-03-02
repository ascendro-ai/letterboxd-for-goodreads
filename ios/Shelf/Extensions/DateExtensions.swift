import Foundation

extension Date {
    // Relative date thresholds: 60s (minute), 3600s (hour), 86400s (day), 604800s (week).
    var feedTimestamp: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = Calendar.current.isDate(self, equalTo: now, toGranularity: .year)
                ? "MMM d"
                : "MMM d, yyyy"
            return formatter.string(from: self)
        }
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
}
