import SwiftUI

/// A preview-only catalog for reviewing the reusable merchant components in both languages.
private struct MerchantComponentsCatalog: View {
    let arabic: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: MerchantTheme.Spacing.large) {
                MerchantHeader(title: arabic ? "مكونات التصميم" : "Design components")
                MerchantCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(arabic ? "العناوين والبطاقات" : "Headings & cards").merchantFont(22, .bold)
                        Text(arabic ? "نص توضيحي للمكونات المشتركة" : "Reusable merchant interface components.")
                            .merchantFont(14).foregroundStyle(MerchantTheme.secondary)
                        HStack {
                            MerchantStatusBadge(title: arabic ? "نشط" : "Active")
                            MerchantStatusBadge(title: arabic ? "مغلق" : "Closed", kind: .neutral)
                            MerchantStatusBadge(title: arabic ? "خطأ" : "Error", kind: .error)
                        }
                    }
                }
                MerchantButton(title: arabic ? "متابعة" : "Continue", action: {})
                MerchantButton(title: arabic ? "إلغاء" : "Cancel", secondary: true, action: {})
                MerchantButton(title: arabic ? "جارٍ التحميل" : "Loading", isLoading: true, action: {})
                VStack(spacing: 8) {
                    MerchantFieldLabel(title: arabic ? "رقم الجوال" : "Mobile Number")
                    MerchantFieldContainer(hasError: true) {
                        Text("05123").merchantFont(14).padding(.horizontal, 16)
                        Spacer()
                        MerchantFieldIcon(name: "LOHPhone")
                    }
                    MerchantFieldError(message: merchantString("phone_invalid", arabic: arabic))
                }
                MerchantDialogView(title: arabic ? "تأكيد" : "Confirmation", message: arabic ? "هل تريد المتابعة؟" : "Would you like to continue?") {
                    MerchantButton(title: arabic ? "متابعة" : "Continue", action: {})
                }
            }
            .padding(20)
        }
        .background(MerchantTheme.background)
        .environment(\.locale, Locale(identifier: arabic ? "ar" : "en"))
        .environment(\.layoutDirection, arabic ? .rightToLeft : .leftToRight)
    }
}

struct MerchantComponents_Previews: PreviewProvider {
    static var previews: some View {
        MerchantComponentsCatalog(arabic: false).previewDisplayName("Merchant • English")
        MerchantComponentsCatalog(arabic: true).previewDisplayName("Merchant • العربية")
    }
}
