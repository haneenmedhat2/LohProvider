import SwiftUI
import UIKit

struct MerchantLoginView: View {
    @Environment(\.locale) private var locale
    @StateObject private var model: MerchantLoginViewModel
    @State private var showingCountries = false
    @State private var signInTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case phone, password }
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }
    private var phoneFocused: Binding<Bool> {
        Binding(get: { focusedField == .phone },
                set: { focusedField = $0 ? .phone : nil })
    }

    init(onAuthenticated: @escaping (String) async throws -> Void, responseHandler: ResponseHandler? = nil) {
        _model = StateObject(wrappedValue: MerchantLoginViewModel(
            onAuthenticated: onAuthenticated, responseHandler: responseHandler))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    MerchantBrandHeader(arabic: arabic)
                        .padding(.top, arabic ? 24 : 32)
                    welcome.padding(.top, arabic ? 24 : 16)
                    loginCard.padding(.top, arabic ? 16 : 20)
                        .padding(.horizontal, arabic ? 16 : 20)
                    footer.padding(.top, arabic ? 12 : 20)
                }
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(MerchantTheme.loginBackground.ignoresSafeArea())
        }
        .sheet(isPresented: $showingCountries) {
            countryPicker.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(text("done")) {
                    focusedField = nil
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }.tint(MerchantTheme.brand)
            }
        }
        .accessibilityIdentifier("merchantLogin")
        .onDisappear { signInTask?.cancel() }
        .task { await model.loadCountries() }
    }

    private var welcome: some View {
        VStack(spacing: arabic ? 6 : 6) {
            Text(text("welcome")).merchantFont(arabic ? 30 : 32, .black)
                .foregroundStyle(arabic ? MerchantTheme.heading : MerchantTheme.ink)
                .frame(minHeight: 45)
            Text(text("login_subtitle")).merchantFont(14)
                .foregroundStyle(MerchantTheme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
    }

    private var loginCard: some View {
        MerchantCard(padding: 20, radius: arabic ? 24 : MerchantTheme.Radius.loginCard, elevated: true) {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    MerchantFieldLabel(title: text("mobile_number"))
                    phoneField
                    MerchantFieldError(message: model.phoneErrorKey.map(text))
                }
                VStack(spacing: 8) {
                    MerchantFieldLabel(title: text("password"))
                    passwordField
                    MerchantFieldError(message: model.passwordErrorKey.map(text))
                }
                .padding(.top, arabic ? 20 : 16)
                MerchantFieldError(message: model.error?.message(localize: text))
                    .padding(.top, model.error == nil ? 0 : 12)
                MerchantButton(title: text("sign_in"), isLoading: model.showLoading, action: signIn)
                    .padding(.top, arabic ? 24 : 20)
                    .accessibilityIdentifier("signInButton")
                HStack(spacing: 6) {
                    Image("LOHShield").resizable().scaledToFit().frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    Text(text("secure_data")).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                }
                .frame(maxWidth: .infinity).padding(.top, 14)
            }
            .padding(.vertical, arabic ? 4 : 0)
        }
        .disabled(model.showLoading)
    }

    private var phoneField: some View {
        MerchantFieldContainer(hasError: model.phoneErrorKey != nil, focused: focusedField == .phone) {
            Button {
                focusedField = nil
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                showingCountries = true
            } label: {
                HStack(spacing: 4) {
                    Text(model.country.dialCode).merchantFont(14, .semibold)
                    Image("LOHChevron").resizable().scaledToFit().frame(width: 14, height: 14)
                }
                .environment(\.layoutDirection, .leftToRight)
                .foregroundStyle(MerchantTheme.body)
                .padding(.horizontal, 12).frame(minHeight: 52)
                .background(arabic ? MerchantTheme.background : MerchantTheme.surface)
                .overlay(alignment: .trailing) { Rectangle().fill(MerchantTheme.border).frame(width: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text("country_code"))
            .accessibilityValue(model.country.dialCode)
            .accessibilityIdentifier("countryCodeButton")
            MerchantLoginPhoneTextField(text: $model.phone,
                                        isFocused: phoneFocused,
                                        placeholder: text("phone_placeholder"),
                                        accessibilityLabel: text("mobile_number"),
                                        doneTitle: text("done"))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
            MerchantFieldIcon(name: "LOHPhone")
        }
    }

    private var passwordField: some View {
        MerchantFieldContainer(hasError: model.passwordErrorKey != nil, focused: focusedField == .password) {
            Button {
                model.passwordVisible.toggle()
                focusedField = .password
            } label: {
                Image("LOHEye").resizable().scaledToFit().frame(width: 20, height: 20)
                    .opacity(model.passwordVisible ? 0.55 : 1)
                    .frame(width: 44, height: 52)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text(model.passwordVisible ? "hide_password" : "show_password"))
            .accessibilityIdentifier("passwordVisibilityButton")
            Group {
                if model.passwordVisible {
                    TextField(text("password_placeholder"), text: $model.password)
                } else {
                    SecureField(text("password_placeholder"), text: $model.password)
                }
            }
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .onSubmit(signIn)
            .focused($focusedField, equals: .password)
            .merchantFont(14).foregroundStyle(MerchantTheme.body)
            .padding(.horizontal, 12)
            .multilineTextAlignment(arabic ? .trailing : .leading)
            .accessibilityLabel(text("password"))
            .accessibilityIdentifier("passwordField")
            MerchantFieldIcon(name: "LOHLock")
        }
        // The Figma password row keeps the eye on the left in both languages.
        .environment(\.layoutDirection, .leftToRight)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Image(arabic ? "LOHCityArabic" : "LOHCityEnglish")
                .resizable().scaledToFit()
                .frame(maxWidth: arabic ? 390 : 350)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                (Text(text("copyright_prefix")).foregroundColor(MerchantTheme.muted)
                 + Text(text("brand_name")).foregroundColor(MerchantTheme.brand)
                 + Text(text("copyright_suffix")).foregroundColor(MerchantTheme.muted))
                    .merchantFont(arabic ? 11 : 12)
                Text(text("version")).merchantFont(11).foregroundStyle(MerchantTheme.muted.opacity(0.7))
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, arabic ? 0 : 20)
    }

    private var countryPicker: some View {
        VStack(spacing: 0) {
            HStack {
                Text(text("select_country")).merchantFont(20, .bold)
                Spacer()
                Button(text("done")) { showingCountries = false }.merchantFont(14, .semibold)
            }
            .padding(24)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.countries) { country in
                        Button {
                            model.country = country
                            showingCountries = false
                        } label: {
                            HStack {
                                Text(country.displayName(arabic: arabic))
                                Spacer()
                                Text(country.dialCode).environment(\.layoutDirection, .leftToRight)
                                Image(systemName: model.country == country ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(model.country == country ? MerchantTheme.brand : MerchantTheme.muted)
                            }
                            .merchantFont(15).foregroundStyle(MerchantTheme.body).padding(16)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }.padding(.horizontal, 16)
            }
        }
        .background(MerchantTheme.background).tint(MerchantTheme.brand)
    }

    private func signIn() {
        guard !model.showLoading, signInTask == nil else { return }
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard model.validate() else { return }
        signInTask = Task {
            await model.submit()
            signInTask = nil
        }
    }
}

private struct MerchantLoginPhoneTextField: UIViewRepresentable {
    @Environment(\.locale) private var locale
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let accessibilityLabel: String
    let doneTitle: String

    private var isArabic: Bool { locale.language.languageCode?.identifier == "ar" }

    private var appFont: UIFont {
        let name = "\(isArabic ? "Cairo" : "Poppins")-Regular"
        if let font = UIFont(name: name, size: 14) { return font }
        let fallback = UIFont.systemFont(ofSize: 14)
        return UIFont(descriptor: fallback.fontDescriptor.withDesign(.rounded) ?? fallback.fontDescriptor, size: 14)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = .phonePad
        field.textContentType = .telephoneNumber
        field.font = appFont
        field.textColor = UIColor(MerchantTheme.body)
        field.tintColor = UIColor(MerchantTheme.brand)
        field.textAlignment = isArabic ? .right : .left
        field.semanticContentAttribute = .forceLeftToRight
        field.accessibilityIdentifier = "phoneField"

        let toolbar = UIToolbar()
        toolbar.items = [.flexibleSpace(), UIBarButtonItem(title: doneTitle, style: .done,
                                                         target: context.coordinator, action: #selector(Coordinator.doneTapped))]
        toolbar.sizeToFit()
        field.inputAccessoryView = toolbar
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.font = appFont
        field.textAlignment = isArabic ? .right : .left
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = isArabic ? .right : .left
        paragraph.baseWritingDirection = isArabic ? .rightToLeft : .leftToRight
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .font: appFont,
            .foregroundColor: UIColor(MerchantTheme.placeholder),
            .paragraphStyle: paragraph
        ])
        field.accessibilityLabel = accessibilityLabel
        (field.inputAccessoryView as? UIToolbar)?.items?.last?.title = doneTitle
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? uiView.intrinsicContentSize.width, height: 44)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MerchantLoginPhoneTextField
        init(_ parent: MerchantLoginPhoneTextField) { self.parent = parent }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            guard let current = textField.text,
                  let textRange = Range(range, in: current) else { return false }
            let updated = current.replacingCharacters(in: textRange, with: string)
            let value = MerchantPhoneInput.sanitized(updated)
            let cursor = MerchantPhoneInput.sanitized(String(current[..<textRange.lowerBound]) + string).count
            textField.text = value
            if let position = textField.position(from: textField.beginningOfDocument, offset: cursor) {
                textField.selectedTextRange = textField.textRange(from: position, to: position)
            }
            if parent.text != value { parent.text = value }
            return false
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            let value = MerchantPhoneInput.sanitized(textField.text ?? "")
            if textField.text != value { textField.text = value }
            if parent.text != value { parent.text = value }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            textFieldDidChangeSelection(textField)
            if parent.isFocused { parent.isFocused = false }
        }

        @objc func doneTapped() {
            parent.isFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

    }
}
