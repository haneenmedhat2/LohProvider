import SwiftUI
import AVFoundation
import VisionKit

struct MerchantOrderScannerView: View {
    @EnvironmentObject private var store: MerchantOffersViewModel
    @EnvironmentObject private var coordinator: MerchantTabsCoordinator
    @Environment(\.locale) private var locale
    @State private var ready = false
    @State private var unavailable = false
    @State private var accepted = false
    @State private var scannerID = UUID()
    @State private var verificationTask: Task<Void, Never>?
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(text("nav_scan_barcode")).merchantFont(20, .bold).foregroundStyle(MerchantTheme.heading)
                Spacer()
                Button(text("nav_close")) {
                    verificationTask?.cancel(); store.cancelVerification(); coordinator.sheet = nil
                }.merchantFont(14, .semibold)
            }
            Text(text("offers_scan_hint")).merchantFont(14).foregroundStyle(MerchantTheme.secondary)
            if ready && !unavailable {
                MerchantBarcodeScanner { code in
                    guard !accepted else { return }
                    accepted = true
                    verificationTask = Task {
                        let success = await store.verifyPurchase(code, method: .barcode)
                        if success || store.verificationError != nil { coordinator.sheet = nil }
                    }
                } onFailure: {
                    ready = false; unavailable = true
                }
                .id(scannerID).clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxHeight: .infinity)
            } else if unavailable {
                Spacer()
                Text(text("offers_camera_unavailable")).merchantFont(15).foregroundStyle(MerchantTheme.secondary).multilineTextAlignment(.center)
                Spacer()
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
            if store.isVerifying { ProgressView() }
            if let error = store.verificationAPIError {
                MerchantOfferFailureView(error: error) {
                    accepted = false; scannerID = UUID()
                    if let id = store.verificationOrderID { store.beginVerification(for: id) }
                }
            }
            MerchantButton(title: text("nav_order_code"), secondary: true) { coordinator.sheet = .orderCode }
                .disabled(store.isVerifying)
        }.padding(20).padding(.top, 12).background(.white)
            .onDisappear { verificationTask?.cancel() }
            .task {
                guard DataScannerViewController.isSupported else { unavailable = true; return }
                let allowed = await AVCaptureDevice.requestAccess(for: .video)
                guard !Task.isCancelled else { return }
                ready = allowed && DataScannerViewController.isAvailable
                unavailable = !ready
            }
    }
}
