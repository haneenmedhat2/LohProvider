import SwiftUI

@MainActor
struct MerchantReportExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var store: MerchantReportsViewModel
    @StateObject private var model: MerchantReportExportViewModel
    @State private var saveTask: Task<Void, Never>?
    let period: MerchantReportPeriod
    let previewReport: MerchantReportSnapshot?

    init(period: MerchantReportPeriod, previewReport: MerchantReportSnapshot?, viewModel: MerchantReportExportViewModel? = nil) {
        self.period = period
        self.previewReport = previewReport
        _model = StateObject(wrappedValue: viewModel ?? MerchantReportExportViewModel())
    }

    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }
    private var periodLabel: String {
        previewReport == nil ? MerchantReportFormat.monthPeriod(period, arabic: arabic) : MerchantReportFormat.period(period, arabic: arabic)
    }
    // Keep the preparation layout stable while the native picker is presented.
    // The ready/saved state is shown only after the user returns from Files.
    private var displayedStage: MerchantReportExportViewModel.Stage {
        saveTask != nil || model.isFileExporterPresented ? .preparing : model.stage
    }
    private var sheetHeight: CGFloat {
        switch displayedStage {
        case .options: return model.error == nil ? 330 : 400
        case .preparing: return 370
        case .ready: return model.error == nil ? 440 : 510
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if displayedStage == .preparing {
                    MerchantReportExportPreparation()
                } else {
                    MerchantReportExportHeading(ready: displayedStage == .ready, saved: model.saved)
                    if displayedStage == .ready {
                        MerchantReportExportFileSummary(period: periodLabel).padding(.top, 16)
                    } else {
                        MerchantReportExportPeriodLabel(period: periodLabel).padding(.vertical, 20)
                    }
                    if let error = model.error {
                        MerchantFieldError(message: error.message(localize: text)).padding(.vertical, 10)
                    }
                    VStack(spacing: 10) {
                        Button(action: save) {
                            MerchantReportExportActionLabel(title: text("report_save_pdf"), secondary: false)
                        }.accessibilityIdentifier("reportExportSave")
                        ShareLink(item: MerchantReportTransferable(file: {
                            try await model.prepareFile(download: download)
                        }), preview: SharePreview(text("report_sales_report"), image: Image("LOHReportPDF"))) {
                            MerchantReportExportActionLabel(title: text("report_share"), secondary: true)
                        }.accessibilityIdentifier("reportExportShare")
                    }.buttonStyle(.plain).padding(.top, displayedStage == .ready ? 16 : 0)
                }
                Button(action: close) {
                    Text(text("nav_cancel")).merchantFont(15, .semibold)
                        .foregroundStyle(MerchantTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: displayedStage == .preparing ? 48 : 44)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(displayedStage == .preparing ? MerchantTheme.border : .clear))
                }.buttonStyle(.plain).padding(.top, displayedStage == .preparing ? 16 : 12)
                    .accessibilityIdentifier("reportExportCancel")
            }
            .foregroundStyle(MerchantTheme.heading).multilineTextAlignment(.center)
            .padding(.horizontal, 20).padding(.top, displayedStage == .options ? 24 : 32).padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(MerchantTheme.surface).presentationBackground(MerchantTheme.surface)
        .presentationCornerRadius(24).presentationDragIndicator(.visible)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(sheetHeight)])
        .fileExporter(isPresented: $model.isFileExporterPresented, document: MerchantReportPDFDocument(data: model.data), contentType: .pdf, defaultFilename: "LOH-Sales-Report", onCompletion: model.completeExport)
        .onDisappear {
            if !model.isFileExporterPresented { saveTask?.cancel(); model.cancel() }
        }
    }

    private func save() {
        guard saveTask == nil, !model.isFileExporterPresented else { return }
        saveTask = Task {
            defer { saveTask = nil }
            await model.prepareForSaving(download: download)
        }
    }

    private func close() {
        saveTask?.cancel()
        model.cancel()
        dismiss()
    }

    private func download() async throws -> Data {
        if let previewReport {
            let isArabic = arabic
            let worker = Task.detached(priority: .userInitiated) { MerchantReportPDF.render(previewReport, arabic: isArabic) }
            return await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
        }
        return try await store.download(period: period)
    }
}
