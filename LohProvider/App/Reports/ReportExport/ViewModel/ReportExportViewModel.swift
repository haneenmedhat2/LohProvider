import Combine
import Foundation
import PDFKit

@MainActor
final class MerchantReportExportViewModel: ObservableObject {
    enum Stage { case options, preparing, ready }
    typealias Download = @MainActor () async throws -> Data

    @Published private(set) var stage: Stage = .options
    @Published private(set) var data = Data()
    @Published private(set) var fileURL: URL?
    @Published private(set) var error: APIError?
    @Published private(set) var saved = false
    @Published var isFileExporterPresented = false

    private let directory: URL
    private var preparation: Task<(Data, URL), Error>?
    private var generation = UUID()
    private var saveAttempt = UUID()

    init(directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("LOHReports", isDirectory: true)) {
        self.directory = directory
    }

    func prepareForSaving(download: @escaping Download) async {
        guard !Task.isCancelled, stage != .preparing, !isFileExporterPresented else { return }
        let attempt = UUID()
        saveAttempt = attempt
        stage = .preparing
        error = nil
        await Task.yield()
        do {
            _ = try await prepareFile(download: download)
            try Task.checkCancellation()
            guard saveAttempt == attempt else { return }
            stage = .ready
            isFileExporterPresented = true
        } catch {
            guard saveAttempt == attempt else { return }
            stage = .options
        }
    }

    /// ShareLink requests this file lazily while the native share sheet is open.
    /// Save and Share reuse one validated PDF and one in-flight download.
    func prepareFile(download: @escaping Download) async throws -> URL {
        try Task.checkCancellation()
        if let fileURL { return fileURL }
        error = nil
        if preparation == nil {
            generation = UUID()
            let folder = directory
            preparation = Task {
                let bytes = try await download()
                try Task.checkCancellation()
                guard let document = PDFDocument(data: bytes), document.pageCount > 0 else {
                    throw APIError.invalidResponse
                }
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let destination = folder.appendingPathComponent("LOH-Sales-Report-\(UUID().uuidString).pdf")
                try bytes.write(to: destination, options: .atomic)
                return (bytes, destination)
            }
        }
        let operation = generation
        let pending = preparation!
        do {
            let (bytes, url) = try await withTaskCancellationHandler {
                try await pending.value
            } onCancel: { pending.cancel() }
            try Task.checkCancellation()
            guard generation == operation else { throw CancellationError() }
            data = bytes
            fileURL = url
            preparation = nil
            return url
        } catch {
            if generation == operation {
                preparation = nil
                if !(error is CancellationError) { self.error = APIError.map(error) }
            }
            throw error
        }
    }

    func completeExport(_ result: Result<URL, Error>) {
        isFileExporterPresented = false
        switch result {
        case .success:
            saved = true
            error = nil
        case .failure(let failure):
            let nsError = failure as NSError
            if nsError.domain != NSCocoaErrorDomain || nsError.code != NSUserCancelledError {
                error = APIError.map(failure)
            }
        }
    }

    func cancel() {
        isFileExporterPresented = false
        saveAttempt = UUID()
        generation = UUID()
        preparation?.cancel()
        preparation = nil
        if stage == .preparing { stage = .options }
    }
}
