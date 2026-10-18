import Darwin
import Foundation

/// Reads this process's own memory, CPU time and thread count from the kernel.
enum ProcessUsage {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Mach time units to seconds.
    private static func seconds(_ ticks: UInt64) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }

    static func sample() -> ResourceSample? {
        var usage = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
            }
        }
        guard status == 0 else { return nil }
        var task = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let threads = proc_pidinfo(getpid(), PROC_PIDTASKINFO, 0, &task, size) == size ? Int(task.pti_threadnum) : 0
        let now = mach_absolute_time()
        return ResourceSample(
            footprintBytes: usage.ri_phys_footprint,
            peakFootprintBytes: usage.ri_lifetime_max_phys_footprint,
            cpuSeconds: seconds(usage.ri_user_time + usage.ri_system_time),
            threads: threads,
            uptime: seconds(now - usage.ri_proc_start_abstime),
            at: seconds(now)
        )
    }
}
