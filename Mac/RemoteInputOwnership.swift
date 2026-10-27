/// Sender-queue state for arbitration between local and receiver input.
/// Epochs prevent already queued remote events from reclaiming local control.
struct RemoteInputOwnership {
    private(set) var epoch = 0
    private(set) var receiverActive = false

    mutating func accept(type: String, phase: String?, epoch receivedEpoch: Int?) -> Bool {
        if let receivedEpoch, receivedEpoch != epoch { return false }
        if type == "mouse", phase == "down" { receiverActive = true }
        return receiverActive
    }

    mutating func localActivity() -> Bool {
        guard receiverActive else { return false }
        receiverActive = false
        epoch &+= 1
        return true
    }

    mutating func reset() { receiverActive = false }
}
