import SwiftUI
import UIKit

/// Keep phone editing in one native control, including its text direction and focus.
struct MerchantSupportPhoneField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let accessibilityLabel: String
    let doneTitle: String

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = .phonePad
        field.textContentType = .telephoneNumber
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.font = .systemFont(ofSize: 14)
        field.textColor = UIColor(MerchantTheme.body)
        field.tintColor = UIColor(MerchantTheme.brand)
        field.textAlignment = .left
        field.contentVerticalAlignment = .center
        field.semanticContentAttribute = .forceLeftToRight
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .leftToRight
        paragraph.alignment = .left
        field.defaultTextAttributes = [.font: field.font!, .foregroundColor: field.textColor!, .paragraphStyle: paragraph]
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.accessibilityIdentifier = "support_phone_field"
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)

        let toolbar = UIToolbar()
        toolbar.items = [.flexibleSpace(), UIBarButtonItem(title: doneTitle, style: .done,
                                                         target: context.coordinator, action: #selector(Coordinator.done))]
        toolbar.tintColor = UIColor(MerchantTheme.brand)
        toolbar.sizeToFit()
        field.inputAccessoryView = toolbar
        context.coordinator.field = field
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        // Avoid replacing the editing buffer/selection on every binding update.
        if field.text != text { field.text = text }
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .font: field.font!, .foregroundColor: UIColor(MerchantTheme.placeholder)
        ])
        field.accessibilityLabel = accessibilityLabel
        (field.inputAccessoryView as? UIToolbar)?.items?.last?.title = doneTitle
        context.coordinator.synchronizeFocus()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? uiView.intrinsicContentSize.width, height: 44)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    static func dismantleUIView(_ uiView: UITextField, coordinator: Coordinator) {
        uiView.delegate = nil
        uiView.removeTarget(coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        coordinator.field = nil
        uiView.resignFirstResponder()
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MerchantSupportPhoneField
        weak var field: UITextField?
        init(_ parent: MerchantSupportPhoneField) { self.parent = parent }

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

        @objc func textChanged(_ field: UITextField) {
            let value = MerchantPhoneInput.sanitized(field.text ?? "")
            if field.text != value { field.text = value }
            if parent.text != value { parent.text = value }
        }
        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }
        func textFieldDidEndEditing(_ textField: UITextField) {
            textChanged(textField)
            if parent.isFocused { parent.isFocused = false }
        }
        @objc func done() {
            parent.isFocused = false
            field?.resignFirstResponder()
        }
        func synchronizeFocus() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let field, field.window != nil else { return }
                if parent.isFocused && !field.isFirstResponder { field.becomeFirstResponder() }
                else if !parent.isFocused && field.isFirstResponder { field.resignFirstResponder() }
            }
        }
    }
}
