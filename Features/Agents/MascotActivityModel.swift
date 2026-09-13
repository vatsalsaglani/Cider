import Foundation
import Observation
import CiderDomain

/// Ephemeral presentation only: restored history never schedules a celebration.
@MainActor @Observable
final class MascotActivityModel {
    private(set) var reply: CiderMascotReply?
    @ObservationIgnored private var expiry: Task<Void, Never>?
    @ObservationIgnored private var animatedReply: UUID?

    func receive(_ notice: AgentNotice, at now: Date) {
        guard let next = CiderMascotReply(notice: notice, receivedAt: now), next.eventID != reply?.eventID else { return }
        expiry?.cancel(); reply = next
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        expiry = Task { [weak self] in
            do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }
            self?.reply = nil; self?.expiry = nil
        }
    }

    func claimBounce(_ id: UUID) -> Bool {
        guard reply?.eventID == id, animatedReply != id else { return false }
        animatedReply = id
        return true
    }

    func stop() { expiry?.cancel(); expiry = nil; reply = nil }
}
