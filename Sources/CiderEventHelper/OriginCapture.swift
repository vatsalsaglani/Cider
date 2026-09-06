import AppKit
import Darwin
import CiderDomain

// Only PID ancestry and GUI application identity; no command lines or environment dumps.
func captureOrigin() -> AgentOrigin? {
    var pid = getppid()
    var visited = Set<pid_t>()
    for _ in 0..<32 {
        guard pid > 1, visited.insert(pid).inserted else { break }
        if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular,
           let bundle = app.bundleIdentifier, let launched = app.launchDate {
            return AgentOrigin(bundleID: bundle, processID: pid, launched: launched, name: app.localizedName ?? bundle)
        }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { break }
        pid = pid_t(info.pbi_ppid)
    }
    return nil
}
