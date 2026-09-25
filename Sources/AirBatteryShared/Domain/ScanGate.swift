import Foundation

package final class ExclusiveScanGate: @unchecked Sendable {
    private let lock = NSLock()
    private var inFlight = false

    package init() {}

    package func tryBegin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !inFlight else { return false }
        inFlight = true
        return true
    }

    package func end() {
        lock.lock()
        inFlight = false
        lock.unlock()
    }
}
