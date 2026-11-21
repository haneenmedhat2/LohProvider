import SwiftUI
import AVFoundation
import VisionKit

struct MerchantBarcodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onFailure: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode, onFailure: onFailure) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode()], qualityLevel: .balanced,
                                                recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
                                                isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        do { try scanner.startScanning() }
        catch { DispatchQueue.main.async { onFailure() } }
        return scanner
    }
    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
        controller.delegate = nil
    }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        let onFailure: () -> Void
        private var accepted = false
        init(onCode: @escaping (String) -> Void, onFailure: @escaping () -> Void) {
            self.onCode = onCode; self.onFailure = onFailure
        }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !accepted else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let code = barcode.payloadStringValue {
                    accepted = true
                    dataScanner.stopScanning()
                    onCode(code)
                    return
                }
            }
        }
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            dataScanner.stopScanning()
            onFailure()
        }
    }
}
