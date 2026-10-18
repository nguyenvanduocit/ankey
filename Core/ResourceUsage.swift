import Foundation

/// One reading of a process: the memory it holds and the CPU time it has used so far.
struct ResourceSample: Equatable {
    var footprintBytes: UInt64
    var peakFootprintBytes: UInt64
    var cpuSeconds: Double
    var threads: Int
    /// Seconds since the process started.
    var uptime: Double
    /// When the reading was taken, on a clock that only moves forward.
    var at: Double
}

/// What the numbers of two readings mean, and how the settings window writes them.
enum ResourceUsage {
    /// Percent of one core the process used between two readings. A busy multi-threaded process passes 100.
    static func cpuPercent(from earlier: ResourceSample, to later: ResourceSample) -> Double {
        let elapsed = later.at - earlier.at
        guard elapsed > 0 else { return 0 }
        return max(0, (later.cpuSeconds - earlier.cpuSeconds) / elapsed * 100)
    }

    /// `512 KB`, `25,3 MB`, `1,2 GB`, with the comma Vietnamese uses.
    static func size(_ bytes: UInt64) -> String {
        let kilo = 1024.0
        let value = Double(bytes)
        if value < kilo * kilo { return "\(Int((value / kilo).rounded())) KB" }
        if value < kilo * kilo * kilo { return decimal(value / (kilo * kilo)) + " MB" }
        return decimal(value / (kilo * kilo * kilo)) + " GB"
    }

    /// `0,3%`, `12%`: one decimal under ten, whole numbers above.
    static func percent(_ value: Double) -> String {
        (value < 10 ? decimal(value) : String(Int(value.rounded()))) + "%"
    }

    /// `45 giây`, `12 phút`, `1 giờ 12 phút`, `2 ngày 3 giờ`: the two biggest units.
    static func duration(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let days = total / 86_400
        let hours = total % 86_400 / 3600
        let minutes = total % 3600 / 60
        if days > 0 { return "\(days) ngày \(hours) giờ" }
        if hours > 0 { return "\(hours) giờ \(minutes) phút" }
        if minutes > 0 { return "\(minutes) phút" }
        return "\(total) giây"
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}
