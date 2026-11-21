import Foundation

@MainActor
private final class StubTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var response = HTTPResponse(statusCode: 200, data: Data())
    var failure: Error?
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        if let failure { throw failure }
        return response
    }
    func respond(_ json: String, status: Int = 200) {
        failure = nil
        response = .init(statusCode: status, data: Data(json.utf8))
    }
}

private final class MemoryTokens: TokenStoring {
    var value: String?
    var failSaving = false
    var failDeleting = false
    init(_ value: String? = nil) { self.value = value }
    func read() throws -> String? { value }
    func save(_ token: String) throws {
        if failSaving { throw APIError.credentialStorage }
        value = token
    }
    func delete() throws {
        if failDeleting { throw APIError.credentialStorage }
        value = nil
    }
}

@MainActor
private final class StubAuth: MerchantAuthServicing {
    static let merchant = MerchantProfile(id: "42", name: "Test Store", phone: "512345678", email: "store@example.test")
    var loginCalls = 0
    var profileCalls = 0
    var logoutCalls = 0
    var deleteCalls = 0
    var languageCalls = 0
    var loginAction: (MerchantCredentials) async throws -> String = { _ in "test-token" }
    var profileAction: (String) async throws -> MerchantProfile = { _ in StubAuth.merchant }
    var logoutAction: (String) async throws -> Void = { _ in }
    var deleteAction: (String) async throws -> Void = { _ in }
    var languageAction: (String, String) async throws -> Void = { _, _ in }
    func login(_ credentials: MerchantCredentials) async throws -> String {
        loginCalls += 1
        return try await loginAction(credentials)
    }
    func profile(token: String) async throws -> MerchantProfile {
        profileCalls += 1
        return try await profileAction(token)
    }
    func logout(token: String) async throws {
        logoutCalls += 1
        try await logoutAction(token)
    }
    func deleteAccount(token: String) async throws {
        deleteCalls += 1
        try await deleteAction(token)
    }
    func changeLanguage(_ language: String, token: String) async throws {
        languageCalls += 1
        try await languageAction(language, token)
    }
}

@main
struct MerchantAPIAndSessionChecks {
    struct Value: Decodable { let number: Int }
    @MainActor static func main() async throws {
        try requestEncoding()
        try await responses()
        try await authentication()
        try await sessions()
        try await concurrentOperations()
        try await accountDeletion()
        try await profileRefresh()
        try await profileCaching()
        try await languageChanges()
        print("Passed: merchant request encoding, HTTP/backend failures, cancellation, auth routes, secure-session lifecycle, restore/retry, profile refresh, language changes, stale responses, duplicate requests, and credential failures.")
    }

    @MainActor static func profileCaching() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let baseURL = URL(string: "https://merchant.example/api/")!
        let cache = DiskProfileCache(baseURL: baseURL, directory: directory)
        let profile = MerchantProfile(id: "cached", name: "Cached Store", phone: "0512345678", email: nil,
                                      image: URL(string: "https://merchant.example/store.png"))
        let changed = MerchantProfile(id: "cached", name: "Updated Store", phone: "0512345678", email: "store@example.test",
                                      image: URL(string: "https://merchant.example/new-image.png"))
        precondition(cache.read(token: "cache-token") == nil)
        cache.save(profile, token: "cache-token")
        let reopened = DiskProfileCache(baseURL: baseURL, directory: directory)
        precondition(reopened.read(token: "cache-token") == profile, "All profile fields, including the image, survive relaunch")
        precondition(reopened.read(token: "another-account") == nil && reopened.read(token: "") == nil)
        precondition(DiskProfileCache(baseURL: URL(string: "https://other.example/api/")!, directory: directory)
            .read(token: "cache-token") == nil, "Environments must not share profiles")
        let files = try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("MerchantProfile"), includingPropertiesForKeys: nil)
        precondition(files.count == 1)
        let saved = try String(contentsOf: files[0], encoding: .utf8)
        precondition(!saved.contains("cache-token"), "The cache must not persist the authentication token")

        let auth = StubAuth()
        let tokens = MemoryTokens("cache-token")
        var pending: CheckedContinuation<MerchantProfile, Error>?
        auth.profileAction = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let session = MerchantAuthState(auth: auth, tokens: tokens, profileCache: reopened)
        let restoring = Task { await session.restoreIfNeeded() }
        while pending == nil { await Task.yield() }
        precondition(session.profile == profile && session.state == .signedIn, "Show cache before the network finishes")
        try await session.refreshProfile()
        precondition(auth.profileCalls == 1, "Opening the profile during restoration must not fetch twice")
        pending!.resume(throwing: APIError.offline)
        await restoring.value
        precondition(session.profile == profile && session.state == .signedIn && session.error == .offline)
        auth.profileAction = { _ in changed }
        try await session.refreshProfile()
        precondition(cache.read(token: "cache-token") == changed && session.profile == changed && session.error == nil)

        // A late response after logout must not write the profile back to disk.
        pending = nil
        auth.profileAction = { _ in try await withCheckedThrowingContinuation { pending = $0 } }
        let refreshing = Task { try await session.refreshProfile() }
        while pending == nil { await Task.yield() }
        await session.signOut()
        pending!.resume(returning: profile)
        do { try await refreshing.value; preconditionFailure("Late refresh should be cancelled") }
        catch is CancellationError {}
        precondition(cache.read(token: "cache-token") == nil && session.profile == nil)

        cache.save(profile, token: "old-token")
        tokens.value = "new-token"
        auth.profileAction = { _ in throw APIError.offline }
        let differentAccount = MerchantAuthState(auth: auth, tokens: tokens, profileCache: cache)
        await differentAccount.restoreIfNeeded()
        precondition(differentAccount.profile == nil && differentAccount.state == .unavailable)
        auth.profileAction = { _ in changed }
        try await differentAccount.signIn(.init(phone: "0512345678", password: "test"))
        precondition(cache.read(token: "test-token") == changed && cache.read(token: "old-token") == nil)
        auth.profileAction = { _ in throw APIError.unauthenticated(nil) }
        await differentAccount.restore()
        precondition(differentAccount.state == .signedOut && cache.read(token: "test-token") == nil)

        // No token, account deletion, and corrupt snapshots must never resurrect cached identity.
        cache.save(profile, token: "cache-token")
        let signedOut = MerchantAuthState(auth: auth, tokens: MemoryTokens(), profileCache: cache)
        await signedOut.restoreIfNeeded()
        precondition(signedOut.profile == nil && cache.read(token: "cache-token") == nil)
        tokens.value = "cache-token"
        auth.profileAction = { _ in profile }
        let deleting = MerchantAuthState(auth: auth, tokens: tokens, profileCache: cache)
        await deleting.restoreIfNeeded()
        try await deleting.deleteAccount()
        precondition(cache.read(token: "cache-token") == nil)
        cache.save(profile, token: "cache-token")
        try Data("corrupt".utf8).write(to: files[0])
        precondition(cache.read(token: "cache-token") == nil)
        cache.save(profile, token: "cache-token")
        precondition(cache.read(token: "cache-token") == profile)
        // Disk failure is best-effort and cannot break authentication.
        let unwritable = DiskProfileCache(baseURL: baseURL, directory: files[0])
        unwritable.save(profile, token: "cache-token")
        precondition(unwritable.read(token: "cache-token") == nil)
    }

    static func requestEncoding() throws {
        let configuration = APIConfiguration.live
        precondition(configuration.baseURL.absoluteString == "https://upgrade.loh.com.sa/api/")
        let endpoint = APIRequest(path: "vendor/login", method: .post,
            query: [.init(name: "_method", value: "put"), .init(name: "name", value: "عصير & tea")],
            body: .multipart(["phone": "512345678", "password": "p&=\"ع\r\nss"]))
        let request = try endpoint.urlRequest(configuration: configuration, language: "ar", token: "secret-token")
        precondition(request.url?.path == "/api/vendor/login" && request.httpMethod == "POST")
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        precondition(query.first?.name == "_method" && query.last?.value == "عصير & tea")
        precondition(request.value(forHTTPHeaderField: "lang") == "ar")
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
        precondition(request.value(forHTTPHeaderField: "x-api-key") == nil)
        precondition(request.timeoutInterval == 30)
        let contentType = request.value(forHTTPHeaderField: "Content-Type")!
        let boundary = contentType.components(separatedBy: "boundary=").last!
        let body = String(data: request.httpBody!, encoding: .utf8)!
        precondition(body.contains("name=\"phone\"\r\n\r\n512345678\r\n"))
        precondition(body.contains("p&=\"ع\r\nss") && body.hasSuffix("--\(boundary)--\r\n"))
        precondition(endpoint.diagnosticSummary == "POST vendor/login")
        let json = Data(#"{"count":2,"name":"عصير"}"#.utf8)
        let jsonRequest = try APIRequest(path: "vendor/example", method: .post, body: .json(json))
            .urlRequest(configuration: configuration, language: "en", token: nil)
        precondition(jsonRequest.httpBody == json && jsonRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let get = try APIRequest(path: "vendor/profile").urlRequest(configuration: configuration, language: "fr", token: nil)
        precondition(get.httpBody == nil && get.value(forHTTPHeaderField: "Authorization") == nil)
        precondition(get.value(forHTTPHeaderField: "Content-Type") == nil && get.value(forHTTPHeaderField: "lang") == "en")
        for path in ["https://other.example/api", "../login", "/vendor/login", "vendor/login?secret=x"] {
            do {
                _ = try APIRequest(path: path).urlRequest(configuration: configuration, language: "en", token: nil)
                preconditionFailure("Invalid endpoint accepted")
            } catch { precondition(error as? APIError == .configuration) }
        }
    }

    @MainActor static func responses() async throws {
        let transport = StubTransport()
        var language = "en"
        let client = DefaultResponseHandler(transport: transport, language: { language })
        let endpoint = APIRequest(path: "vendor/profile")
        var unauthorized: [String] = []
        client.onUnauthorized = { unauthorized.append($0) }
        transport.respond(#"{"key":"success","msg":"OK","data":{"number":7}}"#)
        let value: Value = try await client.send(endpoint, token: "old-token")
        precondition(value.number == 7)
        language = "ar"
        let _: Value = try await client.send(endpoint)
        precondition(transport.requests.last?.value(forHTTPHeaderField: "lang") == "ar")
        transport.respond(#"{"key":"unauthenticated","msg":"Please login again"}"#)
        await expectError(.unauthenticated("Please login again")) { let _: Value = try await client.send(endpoint, token: "old-token") }
        precondition(unauthorized == ["old-token"])
        transport.respond("", status: 401)
        await expectError(.unauthenticated(nil)) { let _: Value = try await client.send(endpoint) }
        precondition(unauthorized.count == 1, "Unauthenticated login must not invalidate another session")
        transport.respond(#"{"key":"blocked","msg":"Blocked"}"#)
        await expectError(.unauthenticated("Blocked")) { let _: Value = try await client.send(endpoint, token: "blocked-token") }
        transport.respond(#"{"key":"fail","msg":"Wrong password","data":[],"errors":{"password":["Invalid"]}}"#)
        await expectError(.server(message: "Wrong password", fields: ["password": ["Invalid"]])) { let _: Value = try await client.send(endpoint) }
        transport.respond(#"{"message":"Validation failed","errors":{"phone":"Required"}}"#, status: 422)
        await expectError(.server(message: "Validation failed", fields: ["phone": ["Required"]])) { let _: Value = try await client.send(endpoint) }
        transport.respond(#"{"key":"needActive","msg":"Activate account"}"#)
        await expectError(.server(message: "Activate account", fields: [:])) { let _: Value = try await client.send(endpoint) }
        transport.respond(#"{"key":"success","data":{"number":7}}"#, status: 503)
        await expectError(.http(status: 503, message: nil)) { let _: Value = try await client.send(endpoint) }
        transport.respond("<html>bad gateway</html>")
        await expectError(.invalidResponse) { let _: Value = try await client.send(endpoint) }
        transport.respond(#"{"key":"success","data":null}"#)
        await expectError(.invalidResponse) { let _: Value = try await client.send(endpoint) }
        transport.respond(#"{"key":"success","msg":"Signed out"}"#)
        try await client.sendWithoutData(endpoint)
        transport.respond("", status: 204)
        try await client.sendWithoutData(endpoint)
        transport.failure = URLError(.timedOut)
        await expectError(.timeout) { let _: Value = try await client.send(endpoint) }
        transport.failure = URLError(.notConnectedToInternet)
        await expectError(.offline) { let _: Value = try await client.send(endpoint) }
        transport.failure = URLError(.cancelled)
        do { let _: Value = try await client.send(endpoint); preconditionFailure("Cancellation swallowed") }
        catch is CancellationError {} catch { preconditionFailure("Unexpected cancellation error") }
    }

    @MainActor static func authentication() async throws {
        let transport = StubTransport()
        let client = DefaultResponseHandler(transport: transport, language: { "en" })
        var deviceToken: String?
        let auth = MerchantAuthService(client: client, deviceID: { deviceToken })
        transport.respond(#"{"key":"success","data":{"token":"signed-in-token","id":42}}"#)
        let token = try await auth.login(.init(phone: "512345678", password: "unchanged password "))
        precondition(token == "signed-in-token")
        let login = transport.requests.last!
        let fields = String(data: login.httpBody!, encoding: .utf8)!
        precondition(login.url?.path == "/api/vendor/login" && login.httpMethod == "POST")
        precondition(fields.contains("unchanged password ") && fields.contains("ios"))
        precondition(fields.contains("name=\"device_id\"\r\n\r\n\r\n"))
        precondition(login.value(forHTTPHeaderField: "Authorization") == nil)
        let staticAuth = MerchantAuthService(client: client)
        _ = try await staticAuth.login(.init(phone: "512345678", password: "test"))
        let staticFields = String(data: transport.requests.last!.httpBody!, encoding: .utf8)!
        precondition(staticFields.contains("name=\"device_id\"\r\n\r\nloh-provider-ios-static\r\n"))
        deviceToken = "test-push-token"
        _ = try await auth.login(.init(phone: "512345678", password: "test"))
        let deviceFields = String(data: transport.requests.last!.httpBody!, encoding: .utf8)!
        precondition(deviceFields.contains("name=\"device_id\"\r\n\r\ntest-push-token\r\n"))
        transport.respond(#"{"key":"success","data":{"id":42,"store_name":"Test Store","name":"Owner","full_phone":"+966512345678","phone":"512345678","email":null,"image":""}}"#)
        let profile = try await auth.profile(token: token)
        precondition(profile.id == "42" && profile.name == "Test Store" && profile.phone == "+966512345678" && profile.email == nil)
        precondition(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer signed-in-token")
        transport.respond(#"{"key":"success","msg":"Signed out"}"#)
        try await auth.logout(token: token)
        precondition(transport.requests.last?.url?.path == "/api/vendor/sign-out" && transport.requests.last?.httpMethod == "DELETE")
        transport.respond(#"{"key":"success","data":{"id":42}}"#)
        await expectError(.invalidResponse) { _ = try await auth.login(.init(phone: "512345678", password: "test")) }
        transport.respond(#"{"key":"success","data":{"token":" "}}"#)
        await expectError(.invalidResponse) { _ = try await auth.login(.init(phone: "512345678", password: "test")) }
        transport.respond(#"{"key":"success","data":{"token":"token\r\ninjected"}}"#)
        await expectError(.invalidResponse) { _ = try await auth.login(.init(phone: "512345678", password: "test")) }
    }

    @MainActor static func sessions() async throws {
        let auth = StubAuth()
        let tokens = MemoryTokens()
        let session = MerchantAuthState(auth: auth, tokens: tokens)
        await session.restoreIfNeeded()
        precondition(session.state == .signedOut && auth.profileCalls == 0)
        let oldIdentity = session.identity
        try await session.signIn(.init(phone: "512345678", password: "test"))
        precondition(session.state == .signedIn && session.profile == StubAuth.merchant)
        precondition(tokens.value == "test-token" && session.identity != oldIdentity)
        session.invalidate(token: "other-session")
        precondition(session.state == .signedIn)
        let relaunched = MerchantAuthState(auth: auth, tokens: tokens)
        await relaunched.restoreIfNeeded()
        precondition(relaunched.state == .signedIn && auth.loginCalls == 1)
        let calls = auth.profileCalls
        await relaunched.restoreIfNeeded()
        precondition(auth.profileCalls == calls)
        auth.logoutAction = { _ in throw APIError.offline }
        await session.signOut()
        precondition(session.state == .signedOut && session.profile == nil && tokens.value == nil)

        tokens.value = "retained-token"
        auth.profileAction = { _ in throw APIError.offline }
        let offline = MerchantAuthState(auth: auth, tokens: tokens)
        await offline.restoreIfNeeded()
        precondition(offline.state == .unavailable && tokens.value == "retained-token" && offline.error == .offline)
        auth.profileAction = { _ in StubAuth.merchant }
        await offline.restore()
        precondition(offline.state == .signedIn)
        auth.profileAction = { _ in throw APIError.unauthenticated(nil) }
        await offline.restore()
        precondition(offline.state == .signedOut && tokens.value == nil && offline.profile == nil)

        auth.profileAction = { _ in throw APIError.timeout }
        try await offline.signIn(.init(phone: "512345678", password: "test"))
        precondition(offline.state == .unavailable && tokens.value == "test-token", "Profile failure must retain the newly authenticated session for retry")
        auth.profileAction = { _ in StubAuth.merchant }
        await offline.restore()
        precondition(offline.state == .signedIn)

        let badTokens = MemoryTokens()
        badTokens.failSaving = true
        let unsaved = MerchantAuthState(auth: auth, tokens: badTokens)
        await unsaved.restoreIfNeeded()
        await expectError(.credentialStorage) { try await unsaved.signIn(.init(phone: "512345678", password: "test")) }
        precondition(unsaved.state == .signedOut && unsaved.token == nil)
        badTokens.failSaving = false
        auth.profileAction = { _ in StubAuth.merchant }
        try await unsaved.signIn(.init(phone: "512345678", password: "test"))
        badTokens.failDeleting = true
        await unsaved.signOut()
        precondition(unsaved.state == .signedIn && unsaved.error == .credentialStorage, "Do not claim logout while retaining a restorable token")
    }

    @MainActor static func concurrentOperations() async throws {
        var continuation: CheckedContinuation<Void, Never>?
        var calls = 0
        let model = MerchantLoginViewModel { credentials in
            calls += 1
            precondition(credentials.phone == "512345678" && credentials.password == " kept ")
            await withCheckedContinuation { continuation = $0 }
            try Task.checkCancellation()
        }
        model.phone = "٠٥١٢٣٤٥٦٧٨"; model.password = " kept "
        let first = Task { await model.submit() }
        while continuation == nil { await Task.yield() }
        await model.submit()
        precondition(calls == 1 && model.isLoading)
        continuation?.resume(); await first.value
        precondition(model.phone.isEmpty && model.password.isEmpty && !model.isLoading)

        let auth = StubAuth()
        let tokens = MemoryTokens("expired-token")
        var pending: CheckedContinuation<MerchantProfile, Never>?
        auth.profileAction = { _ in await withCheckedContinuation { pending = $0 } }
        let session = MerchantAuthState(auth: auth, tokens: tokens)
        let restore = Task { await session.restoreIfNeeded() }
        while pending == nil { await Task.yield() }
        session.invalidate(token: "expired-token")
        pending?.resume(returning: StubAuth.merchant)
        await restore.value
        precondition(session.state == .signedOut && session.profile == nil && tokens.value == nil, "Late profile response must not restore an expired session")

        var loginResult: CheckedContinuation<String, Never>?
        auth.loginAction = { _ in await withCheckedContinuation { loginResult = $0 } }
        let login = Task { try await session.signIn(.init(phone: "512345678", password: "test")) }
        while loginResult == nil { await Task.yield() }
        login.cancel()
        loginResult?.resume(returning: "cancelled-login-token")
        do { try await login.value; preconditionFailure("Cancelled login succeeded") }
        catch is CancellationError {} catch { preconditionFailure("Wrong cancellation error") }
        precondition(tokens.value == nil && session.state == .signedOut)
    }

    @MainActor static func accountDeletion() async throws {
        let auth = StubAuth()
        let tokens = MemoryTokens()
        let session = MerchantAuthState(auth: auth, tokens: tokens)
        await session.restoreIfNeeded()
        await expectError(.unauthenticated(nil)) { try await session.deleteAccount() }
        precondition(auth.deleteCalls == 0)
        try await session.signIn(.init(phone: "512345678", password: "test"))
        let identity = session.identity
        auth.deleteAction = { _ in throw APIError.offline }
        await expectError(.offline) { try await session.deleteAccount() }
        precondition(session.state == .signedIn && session.profile != nil && tokens.value == "test-token")
        precondition(!session.isDeletingAccount && session.error == .offline)

        auth.deleteAction = { _ in throw CancellationError() }
        do { try await session.deleteAccount(); preconditionFailure("Cancellation was swallowed") }
        catch is CancellationError {}
        precondition(session.state == .signedIn && tokens.value == "test-token" && !session.isDeletingAccount)

        var pending: CheckedContinuation<Void, Never>?
        auth.deleteAction = { token in
            precondition(token == "test-token")
            await withCheckedContinuation { pending = $0 }
        }
        let deletion = Task { try await session.deleteAccount() }
        while pending == nil { await Task.yield() }
        let calls = auth.deleteCalls
        await expectError(.requestInProgress) { try await session.deleteAccount() }
        await expectError(.requestInProgress) { try await session.signIn(.init(phone: "512345678", password: "test")) }
        await session.signOut()
        await session.restore()
        precondition(session.isDeletingAccount && session.state == .signedIn && tokens.value == "test-token")
        precondition(auth.deleteCalls == calls && auth.logoutCalls == 0)
        pending!.resume()
        try await deletion.value
        precondition(session.state == .signedOut && session.profile == nil && session.token == nil && tokens.value == nil)
        precondition(session.identity != identity && !session.isDeletingAccount && session.error == nil)

        try await session.signIn(.init(phone: "512345678", password: "test"))
        auth.deleteAction = { _ in }
        tokens.failDeleting = true
        await expectError(.credentialStorage) { try await session.deleteAccount() }
        precondition(session.state == .unavailable && session.profile == nil && session.error == .credentialStorage)
        tokens.failDeleting = false
        await session.signOut()
        precondition(session.state == .signedOut && tokens.value == nil)

        try await session.signIn(.init(phone: "512345678", password: "test"))
        pending = nil
        auth.deleteAction = { _ in await withCheckedContinuation { pending = $0 } }
        let stale = Task { try await session.deleteAccount() }
        while pending == nil { await Task.yield() }
        session.invalidate(token: "test-token")
        let clearedIdentity = session.identity
        pending!.resume()
        try await stale.value
        precondition(session.state == .signedOut && session.identity == clearedIdentity && session.error == .unauthenticated(nil))

        try await session.signIn(.init(phone: "512345678", password: "test"))
        auth.deleteAction = { _ in throw APIError.unauthenticated(nil) }
        await expectError(.unauthenticated(nil)) { try await session.deleteAccount() }
        precondition(session.state == .signedOut && tokens.value == nil)
    }

    @MainActor static func profileRefresh() async throws {
        let auth = StubAuth()
        let tokens = MemoryTokens("profile-token")
        let session = MerchantAuthState(auth: auth, tokens: tokens)
        await session.restoreIfNeeded()
        let identity = session.identity
        let updated = MerchantProfile(id: "42", name: "Updated Store", phone: "512345679", email: "updated@example.test")
        auth.profileAction = { token in
            precondition(token == "profile-token")
            return updated
        }
        try await session.refreshProfile()
        precondition(auth.profileCalls == 2 && session.profile == updated)
        precondition(session.state == .signedIn && session.identity == identity, "Refresh must preserve navigation")

        auth.profileAction = { _ in throw APIError.offline }
        await expectError(.offline) { try await session.refreshProfile() }
        precondition(session.state == .signedIn && session.profile == updated && tokens.value == "profile-token")
        auth.profileAction = { _ in throw URLError(.cancelled) }
        do { try await session.refreshProfile(); preconditionFailure("Cancellation swallowed") }
        catch is CancellationError {}
        precondition(session.profile == updated)

        var pending: CheckedContinuation<MerchantProfile, Never>?
        auth.profileAction = { _ in await withCheckedContinuation { pending = $0 } }
        let earlier = Task { try await session.refreshProfile() }
        while pending == nil { await Task.yield() }
        auth.profileAction = { _ in StubAuth.merchant }
        try await session.refreshProfile()
        pending!.resume(returning: updated)
        do { try await earlier.value; preconditionFailure("An older refresh was accepted") }
        catch is CancellationError {}
        precondition(session.profile == StubAuth.merchant && session.identity == identity)

        pending = nil
        auth.profileAction = { _ in await withCheckedContinuation { pending = $0 } }
        let stale = Task { try await session.refreshProfile() }
        while pending == nil { await Task.yield() }
        await session.signOut()
        pending!.resume(returning: updated)
        do { try await stale.value; preconditionFailure("Signed-out refresh was accepted") }
        catch is CancellationError {}
        precondition(session.profile == nil && session.state == .signedOut && tokens.value == nil)
        await expectError(.unauthenticated(nil)) { try await session.refreshProfile() }

        auth.profileAction = { _ in StubAuth.merchant }
        try await session.signIn(.init(phone: "512345678", password: "test"))
        auth.profileAction = { _ in throw APIError.unauthenticated(nil) }
        await expectError(.unauthenticated(nil)) { try await session.refreshProfile() }
        precondition(session.state == .signedOut && session.profile == nil && tokens.value == nil)
    }

    @MainActor static func languageChanges() async throws {
        let auth = StubAuth()
        let tokens = MemoryTokens("language-token")
        let session = MerchantAuthState(auth: auth, tokens: tokens)
        await session.restoreIfNeeded()
        auth.languageAction = { language, token in
            precondition(language == "en" && token == "language-token")
        }
        try await session.changeLanguage("en")
        precondition(auth.languageCalls == 1 && session.state == .signedIn)
        await expectError(.configuration) { try await session.changeLanguage("fr") }
        precondition(auth.languageCalls == 1)
        auth.languageAction = { _, _ in throw APIError.timeout }
        await expectError(.timeout) { try await session.changeLanguage("ar") }
        precondition(session.state == .signedIn && tokens.value == "language-token")

        var pending: CheckedContinuation<Void, Never>?
        auth.languageAction = { language, token in
            precondition(language == "ar" && token == "language-token")
            await withCheckedContinuation { pending = $0 }
        }
        let change = Task { try await session.changeLanguage("ar") }
        while pending == nil { await Task.yield() }
        await expectError(.requestInProgress) { try await session.changeLanguage("en") }
        precondition(auth.languageCalls == 3)
        await session.signOut()
        pending!.resume()
        do { try await change.value; preconditionFailure("Language change for a signed-out account was accepted") }
        catch is CancellationError {}
        await expectError(.unauthenticated(nil)) { try await session.changeLanguage("en") }
        precondition(auth.languageCalls == 3 && tokens.value == nil)

        try await session.signIn(.init(phone: "512345678", password: "test"))
        auth.languageAction = { _, _ in throw APIError.unauthenticated(nil) }
        await expectError(.unauthenticated(nil)) { try await session.changeLanguage("en") }
        precondition(session.state == .signedOut && session.profile == nil && tokens.value == nil)
    }

    @MainActor static func expectError(_ expected: APIError, file: StaticString = #fileID, line: UInt = #line,
                                      operation: () async throws -> Void) async {
        do { try await operation(); preconditionFailure("Expected failure", file: file, line: line) }
        catch { precondition(error as? APIError == expected, "Unexpected error: \(error)", file: file, line: line) }
    }
}
