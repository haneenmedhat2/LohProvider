import Foundation
import Combine

/// Coordinates the app-wide maintenance overlay and read requests waiting for recovery.
@MainActor
final class MerchantMaintenanceViewModel: ObservableObject {
    static let shared = MerchantMaintenanceViewModel()

    @Published private(set) var isPresented = false
    @Published private(set) var isRetrying = false
    @Published private(set) var retryMessage: String?

    private struct WaitingRequest {
        let continuation: CheckedContinuation<Void, Error>
    }

    private var checkAvailability: (() async throws -> Bool)?
    private var waitingRequests: [UUID: WaitingRequest] = [:]
    private var revision = 0

    /// Queue a GET request until the service is available again.
    func waitForRecovery(checkAvailability: @escaping () async throws -> Bool) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                waitingRequests[id] = WaitingRequest(continuation: continuation)
                self.checkAvailability = self.checkAvailability ?? checkAvailability
                revision += 1
                isPresented = true
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.waitingRequests.removeValue(forKey: id)?.continuation.resume(throwing: CancellationError())
            }
        }
        try Task.checkCancellation()
    }

    /// Show maintenance for a write request without ever replaying that request.
    func present(checkAvailability: @escaping () async throws -> Bool) {
        self.checkAvailability = self.checkAvailability ?? checkAvailability
        revision += 1
        isPresented = true
    }

    func retry() async {
        guard !isRetrying, let checkAvailability else { return }
        isRetrying = true
        retryMessage = nil
        let retryRevision = revision
        defer { isRetrying = false }

        do {
            let available = try await checkAvailability()
            try Task.checkCancellation()
            guard available, revision == retryRevision else {
                retryMessage = "maintenance_still_unavailable"
                return
            }
            self.checkAvailability = nil
            isPresented = false
            let requests = waitingRequests.values
            waitingRequests.removeAll()
            requests.forEach { $0.continuation.resume() }
        } catch is CancellationError {
            // Cancellation leaves maintenance visible and does not resume reads.
        } catch {
            retryMessage = "maintenance_retry_failed"
        }
    }
}
