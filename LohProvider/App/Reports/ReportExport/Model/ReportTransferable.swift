import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct MerchantReportTransferable: Transferable {
    let file: @Sendable () async throws -> URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { report in
            SentTransferredFile(try await report.file())
        }
    }
}
