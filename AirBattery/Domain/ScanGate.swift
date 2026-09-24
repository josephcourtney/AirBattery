import Foundation

final class ExclusiveScanGate: @unchecked Sendable {
    private let lock = NSLock()
    private var inFlight = false

    func tryBegin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !inFlight else { return false }
        inFlight = true
        return true
    }

    func end() {
        lock.lock()
        inFlight = false
        lock.unlock()
    }
}
