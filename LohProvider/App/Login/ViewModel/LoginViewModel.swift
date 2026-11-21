import Foundation
import Combine

@MainActor
final class MerchantLoginViewModel: BaseViewModel {
    @Published var phone = "" {
        didSet { if phone != oldValue { phoneErrorKey = nil } }
    }
    @Published var password = "" {
        didSet { if password != oldValue { passwordErrorKey = nil } }
    }
    @Published private(set) var countries = MerchantCountry.fallback
    @Published var country = MerchantCountry.fallback[0] {
        didSet { if country.countryCode != oldValue.countryCode { phoneErrorKey = nil } }
    }
    @Published var passwordVisible = false
    @Published private(set) var phoneErrorKey: String?
    @Published private(set) var passwordErrorKey: String?
    @Published private(set) var showLoading = false
    @Published private(set) var error: APIError?
    private let onAuthenticated: (String) async throws -> Void

    init(onAuthenticated: @escaping (String) async throws -> Void, responseHandler: ResponseHandler? = nil) {
        self.onAuthenticated = onAuthenticated
        super.init(responseHandler: responseHandler)
    }

    func loadCountries() async {
        do {
            let loaded: [MerchantCountry] = try await responseHandler.data(
                from: CountryEndpoints.list(), language: AppLanguageManager.shared.apiLanguage)
            try Task.checkCancellation()
            guard !loaded.isEmpty else { return }
            let selectedCountryCode = country.countryCode
            countries = loaded
            country = loaded.first(where: { $0.countryCode == selectedCountryCode }) ?? loaded[0]
        } catch is CancellationError {
            // The view was dismissed while the request was running.
        } catch {
            // Keep the local list available if the countries endpoint is temporarily unreachable.
        }
    }

    var normalizedPhone: String {
        phone.compactMap(\.wholeNumberValue).map(String.init).joined()
    }

    func validate() -> Bool {
        error = nil
        phoneErrorKey = nil
        passwordErrorKey = nil
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        #if !DEBUG
        let allowed = trimmed.allSatisfy { $0.wholeNumberValue != nil || $0 == " " || $0 == "-" }
        #endif
        let digits = normalizedPhone
        if trimmed.isEmpty {
            phoneErrorKey = "phone_required"
        } else {
        #if DEBUG
            if digits.count != MerchantPhoneInput.maxDigits { phoneErrorKey = "phone_invalid" }
        #else
            if !allowed || !country.acceptsNationalNumber(digits) { phoneErrorKey = "phone_invalid" }
        #endif
        }
        // The API owns password policy; never alter the password before sending it.
        if password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            passwordErrorKey = "password_required"
        }
        return phoneErrorKey == nil && passwordErrorKey == nil
    }

    func submit() async {
        guard !showLoading, validate() else { return }
        showLoading = true; error = nil
        defer { showLoading = false }
        do {
            let result: MerchantLoginToken = try await responseHandler.data(
                from: AuthEndpoints.login(
                    phone: normalizedPhone,
                    password: password,
                    deviceID: UserDefaults.pushNotificationToken ?? ""),
                language: AppLanguageManager.shared.apiLanguage)
            try Task.checkCancellation()
            guard !result.token.isEmpty else { throw APIError.invalidResponse }
            try await onAuthenticated(result.token)
            clearCredentials()
        } catch is CancellationError {
            // Leaving the screen cancels work without presenting a connection error.
        } catch {
            self.error = APIError.map(error)
        }
    }

    func clearCredentials() {
        phone = ""
        password = ""
        passwordVisible = false
    }
}
