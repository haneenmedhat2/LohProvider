// Run with python3 Scripts/run-checks.py; no app or backend required.
import Foundation

@main
struct MerchantLoginValidationChecks {
    @MainActor static func main() {
        let model = MerchantLoginViewModel()
        precondition(!model.validate(), "Empty credentials must fail")
        precondition(model.phoneErrorKey == "phone_required")
        precondition(model.passwordErrorKey == "password_required")
        model.password = "local-preview"
        for phone in ["512345678", "0512345678", "٠٥١٢٣٤٥٦٧٨", "05 123 45678"] {
            model.phone = phone
            precondition(model.validate(), "Expected valid Saudi number: \(phone)")
        }
        #if DEBUG
        for phone in ["123", "412345678", "5123456789", "abc512345678", "+966512345678"] {
            model.phone = phone
            precondition(model.validate(), "Debug builds accept nonstandard phone formats: \(phone)")
        }
        model.phone = "abc"
        precondition(!model.validate(), "A phone with no usable digits cannot be submitted")
        #else
        for phone in ["123", "412345678", "5123456789", "abc512345678", "+966512345678"] {
            model.phone = phone
            precondition(!model.validate(), "Expected invalid number: \(phone)")
        }
        #endif
        model.country = MerchantCountry.supported.first { $0.id == "KW" }!
        model.phone = "51234567"
        precondition(model.validate(), "Country selection must affect validation")
        model.country = MerchantCountry.supported[0]
        #if DEBUG
        precondition(model.validate(), "Debug builds skip country-specific phone format checks")
        #else
        precondition(!model.validate(), "Kuwaiti number must not validate as Saudi")
        #endif
        model.phone = "512345678"
        model.password = "   "
        precondition(!model.validate(), "Whitespace-only password must fail")
        model.password = "x"
        precondition(model.validate(), "Preview must not invent a backend password-length policy")
        model.passwordVisible = true
        model.clearCredentials()
        precondition(model.phone.isEmpty && model.password.isEmpty && !model.passwordVisible)
        print("Passed: empty fields, phone validation for this build, Arabic digits, country changes, password policy, credential clearing.")
    }
}
