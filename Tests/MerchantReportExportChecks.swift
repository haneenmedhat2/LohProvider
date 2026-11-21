import CoreGraphics
import Foundation
import PDFKit

@MainActor private final class ExportDownloadProbe {
    var count = 0
    var continuation: CheckedContinuation<Data, Error>?
    func download() async throws -> Data {
        count += 1
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
}

@main struct MerchantReportExportChecks {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("loh-export-checks-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let bytes = pdf()
        let model = MerchantReportExportViewModel(directory: directory)
        let probe = ExportDownloadProbe()
        let saving = Task { await model.prepareForSaving(download: probe.download) }
        while probe.continuation == nil { await Task.yield() }
        precondition(model.stage == .preparing && model.fileURL == nil && !model.saved && !model.isFileExporterPresented)
        await model.prepareForSaving { preconditionFailure("Repeated Save must not start another preparation") }
        precondition(probe.count == 1 && !model.isFileExporterPresented)
        let sharing = Task { try await model.prepareFile(download: probe.download) }
        await Task.yield()
        probe.continuation!.resume(returning: bytes)
        await saving.value
        let sharedURL = try await sharing.value
        precondition(probe.count == 1 && model.stage == .ready && !model.saved && model.isFileExporterPresented,
                     "Successful preparation must open Files automatically, without a second Save tap")
        precondition(model.fileURL == sharedURL && model.data == bytes)
        let writtenData = try Data(contentsOf: sharedURL)
        precondition(writtenData == bytes)
        let cachedURL = try await model.prepareFile { preconditionFailure("A ready report must not download again") }
        precondition(cachedURL == sharedURL)
        await model.prepareForSaving { preconditionFailure("An open file picker must not start another save") }
        precondition(model.isFileExporterPresented && probe.count == 1)
        // SwiftUI also dismisses the picker by updating its presentation binding.
        model.isFileExporterPresented = false
        await model.prepareForSaving { preconditionFailure("Retry after picker cancellation must reuse the prepared PDF") }
        precondition(model.isFileExporterPresented && model.fileURL == sharedURL && !model.saved)
        model.completeExport(.failure(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)))
        precondition(!model.saved && model.error == nil && model.stage == .ready && !model.isFileExporterPresented)
        model.completeExport(.success(sharedURL))
        precondition(model.saved && model.error == nil && !model.isFileExporterPresented)
        model.completeExport(.failure(APIError.offline))
        precondition(model.error != nil && model.fileURL == sharedURL)

        let invalid = MerchantReportExportViewModel(directory: directory)
        await invalid.prepareForSaving { Data("<html>expired download</html>".utf8) }
        precondition(invalid.stage == .options && invalid.error != nil && invalid.fileURL == nil && !invalid.isFileExporterPresented)
        await invalid.prepareForSaving { throw APIError.offline }
        precondition(invalid.stage == .options && invalid.error != nil && !invalid.isFileExporterPresented)
        await invalid.prepareForSaving { bytes }
        precondition(invalid.stage == .ready && invalid.error == nil && invalid.isFileExporterPresented)

        let cancelled = MerchantReportExportViewModel(directory: directory)
        let slow = ExportDownloadProbe()
        let waiting = Task { await cancelled.prepareForSaving(download: slow.download) }
        while slow.continuation == nil { await Task.yield() }
        cancelled.cancel()
        slow.continuation!.resume(returning: bytes)
        await waiting.value
        precondition(cancelled.stage == .options && cancelled.fileURL == nil && cancelled.error == nil && !cancelled.isFileExporterPresented)
        await cancelled.prepareForSaving { bytes }
        precondition(cancelled.stage == .ready && cancelled.isFileExporterPresented)

        let dismissed = MerchantReportExportViewModel(directory: directory)
        let pending = ExportDownloadProbe()
        let abandoned = Task { await dismissed.prepareForSaving(download: pending.download) }
        while pending.continuation == nil { await Task.yield() }
        abandoned.cancel()
        pending.continuation!.resume(returning: bytes)
        await abandoned.value
        precondition(dismissed.stage == .options && dismissed.fileURL == nil && !dismissed.isFileExporterPresented,
                     "Dismissing preparation must never open a late Files picker")

        let shareOnly = MerchantReportExportViewModel(directory: directory)
        _ = try await shareOnly.prepareFile { bytes }
        precondition(shareOnly.stage == .options && shareOnly.fileURL != nil && !shareOnly.isFileExporterPresented,
                     "Native sharing must not present the save-location picker")
        let unwritable = MerchantReportExportViewModel(directory: sharedURL)
        await unwritable.prepareForSaving { bytes }
        precondition(unwritable.stage == .options && unwritable.fileURL == nil && unwritable.error != nil && !unwritable.isFileExporterPresented)
        print("Passed: preparation-to-Files presentation, duplicate save suppression, picker cancellation/retry, native-share isolation, PDF validation, one download, cached reuse, cancelled-task protection, file errors and honest save confirmation.")
    }

    private static func pdf() -> Data {
        let output = NSMutableData()
        let consumer = CGDataConsumer(data: output)!
        var bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
        let context = CGContext(consumer: consumer, mediaBox: &bounds, nil)!
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 20, y: 20, width: 40, height: 40))
        context.endPDFPage()
        context.closePDF()
        return output as Data
    }
}
