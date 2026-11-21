# LohProvider — Project Analysis

Reviewed: **19 October 2026**

**Current source organization:** see [Section 32](#32-shared-offers-layout-and-project-wide-feature-folders) for the feature folders and one-view-per-file convention. Earlier sections describe historical implementation states.

Sections 1–10 record the initial review before API implementation. See **Section 11** for networking/authentication, **Section 12** for offers, **Section 13** for Debug API logging, **Section 14** for the earlier Firebase setup, **Section 15** for the current temporary static device ID, **Section 16** for completion of the Vendor/Auth services, and **Section 17** for the Arabic offers design and app branding update.

## 1. Executive assessment

LohProvider is an iPhone merchant application for LOH / Last One Hour. Its active SwiftUI interface covers login, offers, order verification and delivery, reports, settlements, account settings, and support in Arabic and English.

**The current launch path is an interactive design prototype using local fixtures.** Login validates input and opens the merchant interface without authenticating against a server. Delivery confirmation and ticket creation change session memory. Reports and settlements use sample data. The repository also retains a separate transport application with networking, authentication, trips, chat, maps, and notifications; that application is not the current entry point.

The supplied Figma page closely matches the merchant feature structure. The supplied Postman collection provides a relevant `Vendor` API group, but the Swift source has no `vendor/` endpoints. Connecting the merchant features requires explicit API models and services, resolution of several contract ambiguities, and production session handling.

## 2. Sources and review boundaries

| Source | Review performed |
| --- | --- |
| [Project configuration](LohProvider.xcodeproj/project.pbxproj) and Swift source | Entry points, navigation, feature stores, networking, localization, dependencies, and configuration inspected. |
| [Figma merchant page](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=13-2760) | Read page metadata for `13:2760`, named `تطبيق المقدم`; visually inspected the offers, verification, and delivery section. |
| [NewLoh Postman collection](/Users/haneen/Desktop/NewLoh.postman_collection-3.json) | Parsed request definitions, variables, authentication declarations, and saved response shapes. This source is outside the repository. |
| [Existing checks](Tests) | Compiled and ran all eight standalone Swift check programs successfully. |

No API requests were sent and no collection scripts were executed. Saved Postman examples are evidence of the supplied contract, not confirmation of current server behavior. This review did not perform a full iOS app build, simulator walkthrough, device camera test, or pixel-by-pixel Figma comparison. Credential values are intentionally omitted from this document.

## 3. Project inventory and technology

| Item | Observed configuration |
| --- | --- |
| Project / shared scheme | `LohProvider.xcodeproj` / `LohProvider` |
| Application target | One application target; no XCTest or UI test target declared |
| Platform | iPhone, iOS 16.4 and later; device and simulator platforms |
| Language / UI | Swift 5 language mode, SwiftUI, UIKit bridges, Combine |
| Version | Marketing version `1.0`; build `1` |
| Bundle identifier | `com.aait.LohProviderr` |
| Build structure | Xcode filesystem-synchronized `LohProvider` group |
| Appearance | Merchant root explicitly uses light mode |
| Localization | Arabic and English, with runtime locale and layout-direction switching |
| Source size | 255 app Swift files, approximately 19,815 lines, including comments and blank lines |
| Merchant feature files | 32 Swift files under `App/Merchant*`, plus shared components and the merchant coordinator |
| Checks | Eight standalone Swift programs in `Tests/` |

### Directory responsibilities

| Directory | Responsibility |
| --- | --- |
| `LohProvider/Core/` | App entry point, alternate legacy roots, delegate, Info.plist, and assets |
| `LohProvider/App/Merchant*/` | Active merchant screens, local state, sample models, scanner, and PDF export |
| `LohProvider/App/AuthCycle/`, `HomeCycle/`, `OrdersCycle/`, `MoreCycle/`, `ChatCycle/` | Retained transport application features |
| `LohProvider/Coordinator/` | Generic navigation stack, merchant routing, and legacy coordinators |
| `LohProvider/Networking/` | Alamofire request execution, typed endpoints, response decoding, and legacy endpoints |
| `LohProvider/Shared/DesignSystem/` | LOH colors, typography, reusable controls, and Cairo fonts |
| `LohProvider/Shared/Localization/` | Language preferences and localized string tables |
| `LohProvider/Shared/` | Additional controls, validation, storage wrappers, maps, and utilities |
| `LohProvider/FCM/` | Firebase configuration and legacy notification payload models |
| `Scripts/` | Optional Poppins font installation script |

### Direct package dependencies

Versions below come from [Package.resolved](LohProvider.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved), not a check for newer releases.

| Package | Resolved version | Role in this repository |
| --- | --- | --- |
| Alamofire | 5.10.2 | Legacy HTTP execution and multipart uploads |
| Kingfisher | 8.5.0 | Remote image loading |
| Firebase iOS SDK | 12.6.0 | Linked Core, Messaging, Analytics, App Check, AI, and In-App Messaging products |
| Google Maps SDK | 10.4.0 | Retained map and tracking views |
| Socket.IO Client Swift | `master`, revision `42da871d9369f290d6ec4930636c40672143905b` | Legacy chat and location sockets |
| Lottie | 4.5.2 | Animation helpers |
| IQKeyboardManager | 8.0.1 | Keyboard management dependency |

These packages remain target dependencies even where the merchant flow does not use them. Socket.IO is configured against a branch, although the lockfile records a specific revision. Dependency pruning and a tagged Socket.IO requirement would make the intended merchant build easier to maintain.

## 4. Architecture and runtime behavior

### Active merchant flow

1. [NewSwiftUIBaseApp](LohProvider/Core/NewSwiftUIBaseApp.swift) launches [MerchantDesignRootView](LohProvider/App/MerchantNavigation/DesignRoot/View/MerchantDesignRootView.swift).
2. The root owns an in-memory `signedIn` Boolean and observes `AppLanguageManager`.
3. [MerchantLoginViewModel](LohProvider/App/MerchantLogin/ViewModel/MerchantLoginViewModel.swift) validates the selected country's phone format and a nonempty password. Successful validation clears the credentials and invokes the sign-in callback.
4. [MerchantTabsView](LohProvider/App/MerchantNavigation/Tabs/View/MerchantTabsView.swift) creates the navigation coordinator and offer, report, and support stores.
5. Four tabs expose **Offers**, **Reports**, **Settlements**, and **Account**. Each owns an independent `BaseCoordinator<MerchantRoute>` stack.
6. Switching tabs preserves their navigation history. Reselecting a tab returns it to its root. Shared sheets handle code entry, scanning, report periods, and export.
7. Logout resets navigation and removes the merchant tab hierarchy. Reentering creates fresh sample stores. App relaunch also returns to login.

The merchant code uses SwiftUI views with observable stores and a dedicated login view model. This is a lightweight separation of view, state, and navigation, rather than a complete service/repository architecture. Most models still use fixture identifiers and locally generated values.

### Retained legacy flow

[AppRootView](LohProvider/Core/AppRoot/View/AppRootView.swift), `AppCoordinator`, and `RootCoordinatorView` describe a separate splash → authentication → home/orders/more flow. Its view models inherit `BaseViewModel` and call transport-oriented endpoints. The merchant flow only reuses selected infrastructure, including the generic navigation coordinator and language manager.

The networking path is:

```text
Legacy view model
  → BaseViewModel
  → Endpoint<BaseResponse<T>>
  → DefaultResponseHandler
  → DefaultNetworkExecuter / Alamofire
  → JSON decoder
```

`ResponseHandler` and `NetworkExecuter` protocols provide useful injection points. The current executor sends JSON for ordinary request bodies and uses multipart only when `uploads` is nonempty. That behavior needs attention because the Vendor collection uses form-data even for requests without files.

## 5. Figma coverage and implemented features

The supplied page contains **56 merchant screen frames: 28 Arabic and 28 English**, plus a component section. The main screens use a **390 × 844** reference frame. The table maps design states to source areas; it does not claim exact visual parity.

| Figma section | Screen frames | Corresponding code | Current behavior |
| --- | ---: | --- | --- |
| [01 · Login](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=111-6285) | 2 | `App/MerchantLogin/` | Country selection, Arabic-digit normalization, password visibility, local validation |
| [02 · Offers, Verification & Order Delivery](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=111-6286) | 14 | `App/MerchantOffers/` | Search, sorting, detail lists, code/scanner entry, invalid/expired/used-code handling, local delivery confirmation |
| [03 · Reports & Downloads](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=111-6287) | 14 | `App/MerchantReports/` | Period selection, aggregate/detail displays, PDF preparation, save/share, failure and cancellation handling |
| [04 · Settlements](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=111-6288) | 4 | `App/MerchantSettlements/` | Six sample settlements and detail screens |
| [05 · Account & Language](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=111-6289) | 12 | `App/MerchantAccount/` | Sample profile, staged language selection, success state, logout confirmation |
| [06 · Support & Tickets](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=111-6290) | 10 | `App/MerchantSupport/` | Sample tickets and conversations, validated local ticket creation, submitted state |

### Feature details

- **Offers and delivery:** Four offers and sample orders live in [MerchantOfferStore](LohProvider/App/MerchantOffers/Shared/ViewModel/MerchantOfferStore.swift). Search supports both languages. Verification is bound to a particular order; cancellation clears that verification, and repeated delivery is rejected locally. The fixture clock defaults to 26 May 2026, so expiry checks do not follow today's date.
- **Scanning:** [MerchantOrderScannerView](LohProvider/App/MerchantOffers/OrderScanner/View/MerchantOrderScannerView.swift) uses VisionKit's `DataScannerViewController` and camera authorization. Unsupported devices or unavailable cameras expose a manual-entry alternative. Scanned payloads pass through the same local code validator.
- **Reports:** [MerchantReportStore](LohProvider/App/MerchantReports/Shared/ViewModel/MerchantReportStore.swift) generates daily fixtures from 1 January 2025 through 26 May 2026. Presets mean 7 days, 30 days, 90 days, and year-to-date. Totals and average order values use integer halalas; per-offer sales are an illustrative 45%/32%/remainder split.
- **PDF export:** [MerchantReportPDF](LohProvider/App/MerchantReports/ReportExport/ViewModel/MerchantReportPDF.swift) renders a paginated, localized PDF from the displayed snapshot. The export view offers the system file exporter and share sheet. Temporary PDFs use a `LOHReports` directory; explicit cleanup is not implemented.
- **Settlements:** [MerchantSettlement](LohProvider/App/MerchantSettlements/Shared/Model/MerchantSettlement.swift) uses integer halalas and a fixed 25% commission. Recipient accounts are absent from its samples. These values are prototype rules, not an established backend settlement contract.
- **Support:** [MerchantSupportStore](LohProvider/App/MerchantSupport/Shared/ViewModel/MerchantSupportStore.swift) validates name, Saudi-format phone, a title up to 100 characters, and details up to 1,000 characters. Submissions remain in memory. Ticket details display messages but have no reply composer or service connection.
- **Account and language:** Profile data is a fixed preview. Language changes apply only after confirmation, persist in preferences, and update locale and RTL direction. A change in the resolved system language supersedes the stored in-app override.

### Design implementation observations

[LOHTheme](LohProvider/Shared/DesignSystem/Shared/Model/LOHTheme.swift) centralizes semantic colors, spacing, radii, and font selection. Merchant strings use a separate `Merchant.strings` table, avoiding collisions with legacy text. Both language tables contain **208 unique keys**, with identical key sets.

Cairo font files are bundled. Poppins is referenced by the typography and PDF code but is not currently bundled or registered, so English uses a system-font fallback. [install-loh-poppins.py](Scripts/install-loh-poppins.py) can download and register those fonts; it was not run during this analysis. Accessibility labels and identifiers exist in several controls, but large-text behavior, VoiceOver navigation, and the complete bilingual layout still need device/UI review.

## 6. Supplied API collection

The collection is named **NewLoh**, uses Postman Collection v2.1, and contains **90 requests**: 19 Settings, 43 Client, and 28 Vendor. The **Vendor** group is the relevant starting point for this app. Eighteen Vendor requests have saved examples; ten do not.

### Environment and authentication

| Configuration | Value / implication |
| --- | --- |
| Collection `base-url` | `loh.test/api/`; local-looking hostname without an explicit URL scheme |
| Collection `url` | `https://loh.com.sa/api/` |
| Collection `dev-url` | `https://staging.loh.com.sa/api/` |
| Existing app base URL | `https://ctfapp.com.sa/api/`; belongs to the retained transport configuration |
| Vendor requests | Mostly reference `{{base-url}}vendor/...` |
| Generic chat requests | Reference `{{baseUrl}}...`; `baseUrl` is not declared in this collection |
| Authentication | Most protected Vendor requests explicitly use Bearer authentication; the collection and Vendor folders declare no inherited authentication |

The collection includes credential-related variables. Their presence does not establish validity, and their values should not be copied into app source or this document. Select and configure a confirmed environment before integration. The old hardcoded `x-api-key` header is not established as a requirement by the inspected Vendor request headers.

### Vendor endpoint-to-feature map

Paths below are relative to the API base. Braced IDs replace sample IDs. Query examples describe collection entries, not a complete supported-value specification.

| Feature | Method and path | Inputs / integration notes |
| --- | --- | --- |
| Login | `POST vendor/login` | Form-data: `phone`, `password`, `device_id`, `device_type`; no saved response |
| Logout | `DELETE vendor/sign-out` | Bearer auth; no saved response |
| Profile | `GET vendor/profile` | Bearer auth; no saved response |
| Delete account | `DELETE vendor/delete-account` | Request inherits auth, but no parent auth is declared; verify required authentication |
| Offer list / home | `GET vendor/home-page` | `sort_by=low_price` is enabled; `name` example is disabled; response contains pagination and `coupons` |
| Offer customers | `GET vendor/coupon-users/{id}` | Optional-looking `filter` example is disabled; example returns customer/purchase rows |
| Offer detail | `GET vendor/coupon-details/{id}` | Saved response duplicates the customer-row shape; detail contract needs confirmation |
| Order detail | `GET vendor/order-details/{orderID}` | User confirmed on 28 October that the path takes the order's own API ID; this overrides the older collection label (Section 46). |
| Coupon sale | `GET vendor/coupon-sales/{id}` | Example includes quantity, purchase code, price, LOH amount, and user details |
| Confirm delivery | `POST vendor/deliver-coupon/{print_code}?_method=put` | Collection uses method override; success example has `key` and `msg` without `data` |
| Report summary | `GET vendor/report` | Enabled query: `filter=custom`, `from`, `to`; no saved response |
| Detailed report | `GET vendor/detailed-report` | Same example query fields; no saved response |
| Download report | `GET vendor/download-report/{from}/{to}` | Path examples use `MM-YYYY`; response type and date semantics are undocumented |
| Settlements | `GET vendor/my-receipts` | Saved response is a financial summary object, not a dated receipt list |
| Settlement detail | `GET vendor/settlement-details/{id}` | Same saved financial summary shape |
| Create support ticket | `POST vendor/support-request` | Form-data: `user_name`, `phone`, `title`, `complaint`; no saved response |
| Support tickets | `GET vendor/support-tickets` | No saved response |
| Support ticket detail | `GET vendor/support-tickets/{id}` | No saved response |
| Start ticket chat | `POST vendor/support-tickets/{id}/start-chat` | No saved response |
| Send ticket message | `POST vendor/send-message/{id}` | Form-data: `message`; confirm whether path ID is a room ID |
| Notifications | `GET vendor/notifications` | `page` and `paginate` examples are disabled |
| Unread count | `GET vendor/count-notifications` | Bearer auth |
| Delete notification | `DELETE vendor/delete-notification/{id}` | Bearer auth |
| Delete all notifications | `DELETE vendor/delete-notifications` | Bearer auth |

The remaining four Vendor-group requests use the undefined `{{baseUrl}}` variable: `GET get-chats`, `POST start-chat?user_id=...`, `POST send-message/{id}`, and `GET leave-room/{id}`. Do not assume their host, path prefix, or authentication matches the merchant support endpoints. Two GET requests also contain a sample form-data `message` field, which should be clarified before reproducing it in a client.

### Response models and reusable infrastructure

- Saved examples generally use `key`, `msg`, and optional `data`. This aligns structurally with the existing [BaseResponse](LohProvider/Networking/BaseResponse/BaseResponse.swift). Confirm the complete response-key vocabulary and HTTP-error behavior before reuse.
- Home data wraps `coupons` and `pagination`. The existing [Pagination](LohProvider/Networking/Pagination.swift) already maps the example's misspelled `perv_page_url` field.
- Coupon summaries include `id`, `name`, `purchase_times`, `stay`, `total_price`, `loh_total_amount`, `created_at`, and `currency`. Their mapping to active-offer counts, unit prices, and design dashboard totals is not fully specified.
- Customer/purchase examples contain `purchase_code`, `deliver_status`, and `used_status`. These need explicit backend-to-domain status mappings instead of assuming one local `delivered` Boolean is sufficient.
- Money values in the inspected examples are strings. Convert through `Decimal` and define currency units and rounding before mapping to integer halalas; do not decode them directly as existing fixture integers.
- Settlement examples include `deserved_amount`, marketer percentage amounts, `app_percentage_type`, `app_percentage`, `app_percentage_amount`, and `currency`. They do not establish the prototype's fixed 25% rule or provide its complete list/detail fields.
- Login, profile, support creation/list/detail/start-chat, and report summary/detail/download lack saved responses. These are the ten Vendor requests without examples, together with logout.

## 7. Integration gaps and priorities

Priorities below concern making the merchant app service-backed. They distinguish deliberate prototype behavior from defects in a completed production implementation.

| Priority | Finding and evidence | Recommended action |
| --- | --- | --- |
| P0 | Merchant login only changes local state; no active merchant feature calls the Vendor API. | Introduce merchant authentication, session state, service protocols, response models, and loading/error handling. Keep fixtures available through explicit preview/mock implementations. |
| P0 | [NetworkConstants](LohProvider/Networking/NetworkConstants.swift) points to CTF, while the supplied contract uses LOH environments. | Add an explicit environment configuration and Vendor endpoint group; confirm the intended base URL. |
| P0 | Local verification requires exactly six digits. The delivery request example has nine digits, while saved purchase-code examples have ten. | Establish the canonical code format and barcode payload. Preserve codes as strings, including leading zeros; do not carry the six-digit restriction into production without confirmation. |
| P0 | Figma separates order verification from delivery confirmation, but the collection has no clearly identified read-only code-verification endpoint. | Confirm how to resolve a scanned/entered code without delivering the order. Use the delivery endpoint only after explicit confirmation; define server-side repeat-delivery and expiry behavior. |
| P0 | Core login/report/support schemas are missing; settlement and order/detail samples do not clearly match their screens. | Obtain representative success, empty, validation, unauthorized, and failure responses. Confirm ID semantics, pagination, timestamps, and money fields before implementing DTOs. |
| P1 | Existing request bodies use JSON unless uploads are present; collection login/support bodies use form-data without files. | Add a deliberate encoding option or confirm the server also accepts JSON. Preserve the documented delivery method override until a direct PUT contract is confirmed. |
| P1 | Merchant login supports six country codes, but `vendor/login` has no `country_code` field. Support validation only accepts Saudi-format numbers. | Agree on the server phone representation and supported regions, then share normalization rules across affected features. |
| P1 | Report periods, clocks, sales splits, financial rules, and profile data are fixture-driven. | Replace them with service data. Define timezone, report presets, date formats, commission semantics, and whether exported PDFs come from the server or local rendering. |
| P1 | Offer sort options are recent/sales/name; collection only demonstrates `low_price`. | Confirm allowed sort values and map the UI choices explicitly. Handle paginated search and aggregated dashboard statistics. |
| P1 | Support conversations are display-only, while the collection contains start-chat and send-message routes. | Confirm the required reply experience and room-ID contract, then add messaging and refresh behavior if in scope. |
| P1 | [UserDefaults storage](LohProvider/Shared/Foundation/UserDefaults.swift) stores legacy access tokens and user data in preferences. [Requestable](LohProvider/Networking/HandelRequest/Requestable.swift) logs all headers and bodies in Debug; response logging prints entire JSON payloads. | Use Keychain-backed merchant credentials and redact authentication and personal fields before reusing the network layer with real accounts. |
| P1 | `AppDelegate` configures Firebase but is not registered by the current `@main` app. The Firebase plist bundle ID is `com.aait.CaptainNashmy`, different from the target. | If merchant notifications are required, supply matching Firebase/APNs configuration and connect the lifecycle and merchant routes deliberately. |
| P2 | Poppins is missing, the merchant root forces light mode, and large-text/device coverage has not been established. | Complete the intended typography and validate bilingual layouts, accessibility, camera fallback, and PDF output against the design scope. |
| P2 | Legacy transport features and unused merchant placeholder views remain in the app source tree. No checked-in CI workflow, test runner, or README was found. | Establish the retained legacy scope, remove or isolate obsolete code when authorized, and add reproducible build/check documentation and CI. |

The current [DefaultNetworkExecuter](LohProvider/Networking/HandleResponse/DefaultNetworkExecuter.swift) also does not explicitly validate HTTP status codes before decoding. Integration should map transport failures and HTTP statuses alongside the application's `key` response field. Client-side delivery checks alone cannot establish authoritative redemption state across devices.

## 8. Validation performed

| Check | Result | Coverage |
| --- | --- | --- |
| `AppLanguageChecks` | Passed | Preferred language resolution, regional codes, override persistence, Settings changes, RTL |
| `MerchantLanguageSelectionChecks` | Passed | Draft selection, apply/cancel behavior, success dismissal, persistence |
| `MerchantLoginValidationChecks` | Passed | Empty fields, phone formats, Arabic digits, country changes, credential clearing |
| `MerchantNavigationChecks` | Passed | Independent stacks, tab reselection, routes, modal dismissal, logout reset |
| `MerchantSettlementChecks` | Passed | Sample totals, rounding, lookup, localization, settlement navigation |
| `MerchantSupportChecks` | Passed | Required fields, length limits, phone normalization, local submissions, navigation |
| `MerchantOfferChecks` | Passed | Search/sort, code validation, expiry/used codes, verification isolation, cancellation, repeated delivery |
| `MerchantReportChecks` | Passed | Date presets, inclusive ranges, invalid-range preservation, totals, averages, comparisons |
| Project and Info.plist syntax | Passed | `plutil -lint` on both files |
| Merchant localization key parity | Passed | 208 keys per language; no duplicate keys or differences between language key sets |

The eight checks are standalone `@main` programs using `precondition`, not XCTest tests registered with the shared scheme. They were compiled with `xcrun swiftc` and run on the local macOS host, with binaries and module cache under `/tmp/loh-project-analysis-checks`. Passing them verifies the covered model/coordinator behavior; it does not verify the full app or any backend integration.

Current command, run from the repository root (the runner now also includes the API checks added in Sections 11–12):

```sh
python3 Scripts/run-checks.py
```

For a full simulator build after the required Xcode/package environment is available, use the following command. **It was not run for this documentation task.**

```sh
xcodebuild \
  -project LohProvider.xcodeproj \
  -scheme LohProvider \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 9. Suggested implementation sequence

1. **Resolve the API contract:** Confirm environment, phone and device fields, code verification versus delivery, response models, monetary units, report downloads, and support chat identifiers. Fix undefined collection variables and clarify inherited authentication.
2. **Establish merchant services:** Add Vendor endpoints, explicit request encoding, DTO-to-domain mapping, error mapping, credential storage, and session-aware routing. Preserve local fixtures for previews and automated checks.
3. **Connect login and offers:** Implement authentication, profile retrieval, paginated offers/search/sort, order lookup, and server-confirmed delivery. Cover invalid, expired, already-used, unauthorized, and network-failure states.
4. **Connect reports and settlements:** Replace generated data and fixed commission assumptions. Decide the authoritative PDF source and validate totals, date ranges, and localized output.
5. **Connect support and optional notifications:** Persist tickets remotely, load conversation history, implement replies if required, and configure matching push services if those routes are in scope.
6. **Complete release verification:** Add a repeatable test/build workflow; test on simulator and device; review all 56 design states, both languages, permissions, accessibility, session expiry, and cancellation. Reduce legacy dependencies after their required scope is established.

## 10. Open decisions

- Which LOH API environment should development use, and what are the canonical Vendor login response and session-expiry rules?
- How does the backend resolve an order code before delivery, and what are the supported code lengths, barcode contents, and identifier meanings?
- Are the settlement list/detail examples complete? Which fields supply dates, order counts, account details, gross sales, commissions, and transferred totals?
- Which report presets, date formats, response schemas, and download content types are supported?
- Does the merchant app need editable profile data, ticket replies, notifications, or account deletion beyond the inspected Figma screen inventory?
- Should the legacy transport features remain in this target, move to a separate target/module, or be removed in later work?

These decisions affect the next implementation phase. They do not prevent using the current merchant prototype for design review.

## 11. Implementation update: API foundation and authentication

Implemented on 19 October 2026 using the requested base URL, **`https://upgrade.loh.com.sa/api/`**.

- [Merchant API configuration and requests](LohProvider/Networking/Merchant/MerchantAPIRequest.swift) build JSON and form-data requests, including multipart forms without attachments. Merchant headers include the current language and an optional Bearer token; they do not inherit the transport application's API key.
- [MerchantAPIClient](LohProvider/Networking/Merchant/MerchantAPIClient.swift) handles HTTP failures, HTTP-200 backend failures, validation messages, cancellation, timeouts, and malformed responses. The Alamofire adapter uses an ephemeral session, does not automatically retry mutations, and does not log credentials, headers, or response bodies.
- [MerchantAuthService](LohProvider/Services/MerchantAuthService.swift) implements Vendor login, profile, and sign-out. [MerchantSession](LohProvider/Session/MerchantSession.swift) restores saved sessions through the profile endpoint, handles expiry, and prevents stale responses from restoring a cleared session.
- Tokens are stored in [Keychain](LohProvider/Session/MerchantTokenStore.swift), scoped to the bundle and API base URL. Logout clears local credentials even if the remote logout request fails. A local storage failure is surfaced instead of claiming successful logout.
- The login screen now submits credentials asynchronously, prevents duplicate submissions, and shows localized failures. Profile/account screens display the retrieved account. A failed profile fetch retains the token and presents retry/logout controls. Preview authentication is explicitly injected and compiled only in Debug.
- At this stage, offers, reports, settlements, and support still used fixtures. Section 12 supersedes the offers status.

### Verified and pending contract details

The upgrade server was checked with an unauthenticated profile request and login validation requests. Both authentication and validation failures returned HTTP 200 with `key` / `msg`. The collection's sample merchant account was rejected with an invalid-mobile-number response. The user elected to test successful sign-in themselves.

Until that test, successful decoding expects a shared auth envelope with a nonempty **`data.token`**, followed by a profile object under **`data`** with an integer or string **`id`**. The profile supports `store_name`/`name`, `full_phone`/`phone`, nullable `email`, and optional `image`. A different Vendor success schema will produce the localized unexpected-response error and needs an explicit model adjustment.

The login request sends normalized national phone digits, the unchanged password, and `device_type=ios`, consistent with the supplied Vendor example. `device_id` is always included. It initially used the stored push token; as requested on 21 October 2026, the app now sends the fixed value `loh-provider-ios-static` (Section 15). Non-Saudi country selection without `country_code` and successful authenticated behavior remain live-contract checks.

### Validation and manual acceptance

Run `python3 Scripts/run-checks.py` from the project root. All nine check programs passed, including the new [API/session checks](Tests/MerchantAPIAndSessionChecks.swift). A Debug iOS simulator build also succeeded. Existing warnings remain in legacy coordinator code.

For the live check: sign in with a valid merchant account, confirm Account → Profile shows the correct data, relaunch to verify session restoration, and log out to return to login. Also confirm invalid credentials show the backend message and failed profile loading offers retry. A full successful login/profile/logout exchange has not yet been verified against this server.

## 12. Implementation update: offers, customers, and purchase details

The next API step connects the offers screens to **`https://upgrade.loh.com.sa/api/`** through the same authenticated client as the merchant session. [MerchantDependencies](LohProvider/Session/MerchantDependencies.swift) owns the shared client/service setup; each signed-in session gets a fresh [MerchantOfferStore](LohProvider/App/MerchantOffers/Shared/ViewModel/MerchantOfferStore.swift). Fixture offers and local redemption are available only through the explicit Debug preview initializer.

### Connected behavior

| Screen/action | Request and mapping |
| --- | --- |
| Offer list, search, sort, pagination | `GET vendor/home-page`, with `name` when nonempty, `sort_by`, and `page`. Reads `data.coupons` and `data.pagination`. |
| Offer summary | Selected coupon from the list: name, sales count, total sales, LOH amount, and creation date. |
| Offer customer list | `GET vendor/coupon-users/{couponID}`. Reads the saved array shape with customer name/phone, purchase code, delivery status, and usage status. |
| Purchase detail refresh | `GET vendor/order-details/{orderID}` using the order ID from `coupon-details`, as clarified in Section 46. Matches the returned purchase by code/customer; coupon and customer IDs are not sent as the route ID. |

The collection's **query description**, beyond the sample URL, explicitly lists `newest`, `oldest`, `high_price`, and `low_price`. These replace the prototype's unsupported sales/name sorting. Search is debounced, and search/sort/language changes start a new first-page request. Pull-to-refresh and load-more controls expose loading, empty, error, and retry states in both languages. Pagination requests remain on the configured API origin and ignore server-supplied next-page URLs. Duplicate coupons are merged by ID; stale search/page results cannot replace a newer result set.

Amounts use `Decimal` to convert riyals to integer halalas, rejecting invalid precision and overflow. `total_price` is displayed directly as the coupon's total; it is not multiplied by purchase count. Header counters show the server's matching-offer count and the number currently loaded, rather than fabricated global sales/active-order aggregates from a partial page.

Missing images use a neutral placeholder. No active status, unit price, purchase date, or expiry date is invented. `deliver_status` and `used_status` are displayed as returned; the timestamp in `used_status` is not treated as a purchase or expiry date. Purchase codes remain strings, including leading zeros. Purchase identity combines coupon ID and purchase code so repeated purchases by the same customer remain distinct.

### Contract limits and remaining work

- These authenticated response models are based on saved Postman examples; successful live offers/customer/detail calls still need testing with the user's account. The user previously elected to test sign-in themselves.
- The saved `coupon-details` and `order-details` responses duplicate the `coupon-users` array. The live coupon-detail response is mapped in Section 39; Sections 46–47 cover the corrected order-ID path and live single-order response.
- `coupon-sales/{id}` is not called because the identifier's relationship to customer rows is unconfirmed. Quantity, individual purchase price, and commission details from that response are not fabricated.
- Live code/scanner verification and delivery remain unavailable until the read-only code lookup, identifier/code format, expiry rules, and delivery response are established. Live stores reject the prototype's local verify/deliver operations. This phase sends no delivery mutations.
- Reports, settlements, and support still use fixtures and remain subsequent integration work.

### Validation and manual acceptance

Run `python3 Scripts/run-checks.py`. The ten programs include [MerchantOfferAPIChecks](Tests/MerchantOfferAPIChecks.swift), which exercise request encoding/auth/language, the supplied response shapes, exact money conversion, pagination/retry/deduplication, stale search/page responses, cancellation, cleared sessions, purchase matching, and live/preview separation. Tests use synthetic data and do not call the API.

All ten programs passed. The offer API checks also passed when compiled without `DEBUG`, confirming they do not depend on preview fixtures. The Debug iOS simulator build succeeded. Arabic and English each contain 232 unique localization keys, with matching key sets and no missing offer-screen references.

For live acceptance: sign in, confirm the offers and matching count, search using Arabic and English, try all four sorts, load another page, and pull to refresh. Open an offer and purchase to compare names, codes, phone numbers, and statuses with the merchant data. Check an empty search and network failure/retry. Change language and confirm requests and labels update. Log out and sign in again to confirm prior customer data is cleared. Successful authenticated server responses and a device walkthrough remain pending.

## 13. Implementation update: Debug API logging

Added on **20 October 2026**, following the console format in the legacy `Requestable` and `ResponseHandler` implementations.

[MerchantAPILogger](LohProvider/Networking/Merchant/MerchantAPILogger.swift) now prints each merchant request's URL, method, headers, query parameters, and body. Multipart forms print their field dictionary. Responses print the HTTP status and formatted JSON before validation or decoding, so unsuccessful responses are visible too. Transport failures print their error domain, code, description, and user-info dictionary. A shared request ID links each request to its response or failure.

Logging is enabled only under `DEBUG`. As requested on **21 October 2026**, all values are printed without redaction, including Authorization headers, passwords, tokens, query parameters, device IDs, and customer fields. Transmitted requests and decoded responses are unchanged. Empty bodies print a marker; non-JSON text is printed directly, and binary data is represented as Base64.

Run the app using Xcode's Debug configuration and open the debug console to see `FULL REQUEST COMPONENTS`, `RESPONSE FOR`, and `REQUEST FAILED` entries. This supersedes Section 11's original no-response-logging behavior for the merchant client; the legacy logger is unchanged.

The check runner includes [MerchantAPILoggingChecks](Tests/MerchantAPILoggingChecks.swift), covering actual request/response/failure values, nested JSON, unchanged request payloads, and disabled logging when compiled without `DEBUG`.

Validation: all 11 check programs passed, the logging check also passed without `DEBUG`, and the Debug iOS simulator build succeeded.

## 14. Implementation update: LOH Firebase configuration

This section records the **20 October 2026** setup, superseded by the temporary removal in Section 15.

Copied `/Users/haneen/Desktop/loh-provider/Loh Provider/Core/GoogleService-Info.plist` exactly into `LohProvider/FCM/GoogleService-Info.plist`. This was the iOS Firebase configuration supplied by the older project.

- Firebase project: `loh-lo7`; registered bundle ID: `com.aait.LohProvider`. Both target build configurations now use this bundle ID, replacing `com.aait.LohProviderr` and matching the copied configuration.
- The SwiftUI app now registers the existing [AppDelegate](LohProvider/Core/AppDelegate.swift). It configures Firebase, assigns the messaging/notification delegates, requests alert permission, and registers with APNs independently of whether alerts are allowed.
- APNs tokens are mapped to Firebase Messaging. The FCM token is retrieved after APNs registration and refreshed through the messaging delegate, then saved in `UserDefaults.pushNotificationToken`. Login's existing `device_id` provider reads that value on each login. If registration has not finished, login still sends an empty string; no token is invented.
- Added Push Notifications and Remote notifications background capabilities, with `LohProvider/FCM/LohProvider.entitlements` used by Debug and Release. The entitlement matched the source project's development setting.
- Debug logs report registration success/failure without printing the token itself. Existing notification payload handling is retained; merchant-specific tap navigation and uploading refreshed tokens for an already signed-in session are separate work.

The SwiftUI delegate and APNs mapping follow the [Firebase Apple-platform messaging setup](https://firebase.google.com/docs/cloud-messaging/ios/get-started). The existing Firebase SDK version is retained, including the registration-token API expected by the current login contract.

The current target's signing team (`ZUMG9R88LL`) is unchanged; the older project specifies `BVZ9794FDX`. A signed-device build needs the Apple team/profile authorized for `com.aait.LohProvider` and matching APNs credentials in Firebase. The local project cannot establish whether those console credentials are configured. Actual token generation and push delivery require a signed-device check; an unsigned simulator build only validates compilation and bundled configuration.

Validation passed: project/plist syntax, exact source-configuration copy, bundle-ID/entitlement settings for Debug and Release, and the Debug simulator build. The built `.app` was inspected to confirm the copied Firebase configuration, matching bundle identifier, and remote-notification background mode.

## 15. Current update: temporary static device ID

On **21 October 2026**, at the user's request, removed `GoogleService-Info.plist` and the push entitlements file from this project. Removed Firebase/APNs registration, the SwiftUI notification delegate connection, and the Push Notifications/Remote notifications background capabilities. Firebase package dependencies remain available for later reactivation; the app no longer configures Firebase or requests notification permission at launch. The bundle ID remains `com.aait.LohProvider`.

Login now defaults to **`device_id=loh-provider-ios-static`**, defined by `MerchantAuthService.temporaryDeviceID`. The live dependency setup uses that default without reading a cached FCM token. The injectable device-ID provider remains available for future integration. This fixed value is a temporary placeholder requested for API development, not a usable push token. The source configuration in `/Users/haneen/Desktop/loh-provider` is untouched.

Validation: API/session checks cover the default static ID and still pass. Project/plist syntax checks and the Debug simulator build passed. Inspection of the built app confirmed that `GoogleService-Info.plist` and the remote-notification background mode are absent.

## 16. Implementation update: complete Vendor/Auth services

On **21 October 2026**, completed service coverage for all eight requests in the collection's **Vendor → Auth** folder, using **`https://upgrade.loh.com.sa/api/`**. This is the provider application's Auth group; the separate Client/Auth group is outside this implementation.

| Service operation | Request | Status |
| --- | --- | --- |
| Login | `POST vendor/login` | Existing form-data service; sends phone, password, static device ID, and `device_type=ios`. |
| Profile | `GET vendor/profile` | Existing authenticated service and session restoration. |
| Sign out | `DELETE vendor/sign-out` | Existing authenticated service and local credential cleanup. |
| Delete account | `DELETE vendor/delete-account` | Added to [MerchantAuthService](LohProvider/Services/MerchantAuthService.swift) and [MerchantSession](LohProvider/Session/MerchantSession.swift). |
| List notifications | `GET vendor/notifications` | Added pagination through `page` and optional `paginate` (page size). |
| Notification count | `GET vendor/count-notifications` | Decodes `data.count`. |
| Delete one notification | `DELETE vendor/delete-notification/{id}` | Accepts a notification ID and handles success without response data. |
| Delete all notifications | `DELETE vendor/delete-notifications` | Handles success without response data. |

The four notification operations live in [MerchantNotificationService](LohProvider/Services/MerchantNotificationService.swift), exposed through `MerchantDependencies.notifications`. They share the merchant API client, current language header, Bearer authentication, expired-session callback, and Debug request/response logging. Deletion requests have no body and are not automatically retried.

Notification decoding supports both saved list envelopes: `data.{pagination,data}` and `data.notifications.{pagination,data}`. Models retain title, body, UUID, notification type, clickability, coupon ID when present, and the server's localized relative `created_at` text. Pagination accepts the saved numeric/string page-size variants, including empty pages beyond the last page. Requests stay on the configured base URL instead of following the collection's localhost pagination links. No Vendor notification `filter` parameter is assumed.

`MerchantSession.deleteAccount()` retains credentials on ordinary API failure and clears them after confirmed server success. It prevents duplicate deletion and overlapping login/restore/logout operations, respects invalidated sessions, and reports Keychain cleanup failures without continuing to display the deleted profile. The method is ready for a future account-deletion confirmation action; this implementation adds no deletion button or automatic account mutation.

Notification screens, badges, and tap navigation remain UI integration work. These REST services do not reactivate Firebase or APNs. The static device ID and full Debug logging from Sections 13 and 15 remain in effect. Successful authenticated server behavior still needs verification with the user's account; no live account or notification deletions were performed.

Validation: `python3 Scripts/run-checks.py` passed all **12 check programs**, including [Vendor/Auth checks](Tests/MerchantVendorAuthChecks.swift) for routes, headers, both response envelopes, pagination, count, deletion, malformed responses, failures, and cancellation. Expanded [session checks](Tests/MerchantAPIAndSessionChecks.swift) cover account-deletion success, failure, cancellation, concurrent operations, stale responses, unauthorized responses, and credential-storage failure. The logging check also passed with `DEBUG` disabled. The Debug iOS simulator build succeeded, and `git diff --check` passed.

## 17. Arabic offers design and app branding

Updated on **21 October 2026** against [Merchant · offers-ar, node 111:6486](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=111-6486), using its screenshot and design context.

- [MerchantOffersView](LohProvider/App/MerchantOffers/Offers/View/MerchantOffersView.swift) now uses the Arabic frame's compact header/search spacing, four-column summary, outlined verification card, sorting control, and edge-to-edge 120-point offer rows. The controls remain above the scrolling offer list; accessibility text sizes allow the whole screen to scroll.
- Corrected Arabic control icons, merchant artwork, and tab icons using the exact exported Figma SVGs. The tab order stays consistent across navigation. Added the Cairo ExtraBold weight for the Arabic offer headings, with its [source and license](LohProvider/Shared/DesignSystem/Fonts/README.md).
- Search, documented API sorting, pagination, retry, pull-to-refresh, and offer-detail navigation remain connected to the existing services. The live summary shows the server's matching count; the three unavailable account totals display `—`. Design totals appear only in the explicit Debug preview. The verification card remains visible; live buttons explain that verification is currently unavailable, while the preview retains its existing code/scanner flow. Live date labels continue to identify the server's creation date as publication rather than inventing a last-update date.
- The app icon uses the clock mark from [the new LOH logo](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=111-6331), rendered from its exported vector into an opaque 1024×1024 PNG. The display name is **آخر ساعة** in Arabic and **Last One Hour** in English. Existing permission descriptions are preserved.

Validation: all 12 existing check programs passed, and the final Debug iOS simulator build succeeded. Isolated simulator previews exercised the Arabic screen at widths of 390 and 320 points and at an accessibility text size, without live authentication or API calls. The app-icon dimensions/opacity, localization keys, plist syntax, and whitespace checks passed. The built app was inspected to confirm its icon, bundled ExtraBold font, localized display names, and retained camera permission descriptions. Sample offer names, dates, and values remain preview data and are not injected into the live service.

## 18. Profile refresh, native back navigation, and language service

Updated on **21 October 2026** using the supplied `change-lang` Postman screenshot and collection.

- [MerchantProfileView](LohProvider/App/MerchantAccount/Account/View/MerchantAccountView.swift) calls authenticated `GET vendor/profile` when opened and on pull-to-refresh. Successful results update the shared session profile. Refresh retains the signed-in navigation stack and cached details during loading or ordinary network failure; failures offer Retry. Cancelled, superseded, and signed-out responses cannot overwrite the profile, and expired authentication follows the existing sign-out handling.
- The profile and language screens use the NavigationStack's native back button and back gesture, with localized navigation titles.
- Applying a language calls authenticated **`PATCH https://upgrade.loh.com.sa/api/change-lang?lang=ar|en`** with no body. This is the exact shared route shown in the screenshot, under **Client → Auth** in the collection, without a `vendor/` prefix. It extends Section 16's original Vendor-only scope at the user's request.
- The language screen waits for server success before persisting the preference, changing the app's locale/direction and subsequent API language headers, or showing its success sheet. Requests use the existing full Debug logging. Loading prevents duplicate submissions; errors preserve the selection for retry. Cancellation and responses for a signed-out account cannot apply a local language change. Back before Apply discards the unsubmitted selection.

Automated checks cover the exact language URL/method/query/authentication, success without response data, errors, cancellation, duplicate submissions, local persistence after server success, profile refresh without navigation reset, and stale responses. Successful authenticated calls and native back gestures still require a signed-in device walkthrough.

Validation: all **12 check programs** passed, including the Release logging check. The Debug iOS simulator build succeeded, both localization files passed plist validation, and `git diff --check` passed.

## 19. Shared native navigation and home display refinements

Updated on **21 October 2026** at the user's request.

- Home statistics display numeric zero instead of a dash. The Arabic four-stat summary has one rounded border around the entire group, replacing the individual cell boxes. The three counters absent from the documented API response now default to `0`, as requested; this supersedes Section 17's dash presentation. The documented matching-offer total still comes from the API, and partial-page sums are not presented as account totals.
- [MerchantNavigationBar](LohProvider/Shared/DesignSystem/NavigationBar/View/MerchantNavigationBar.swift) provides native stack back controls with **18-point bold** titles for all merchant destinations. Removed custom back buttons from offer/order, report, account, support, and settlement navigation. Tab roots no longer have buttons that imitate Back by switching to Offers. Modal close actions remain dismissal actions.
- The older navigation helper also uses 18-point bold titles and visible native back controls. Registration no longer hides its navigation bar or overrides Back to jump to the root. Home, Orders, and More destination registrations now sit inside their NavigationStacks.
- The profile and language notices use the exact yellow 20×20 Figma assets from [profile icon 111:8738](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=111-8738) and [language icon 111:8896](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/ui?node-id=111-8896), stored locally as `LOHProfileWarning` and `LOHLanguageWarning`.

Validation: all 12 check programs and the Debug simulator build passed. An isolated simulator harness verified all 10 merchant destinations in Arabic and English: native back controls were visible, the interactive-pop recognizer was enabled, and native pops updated the bound navigation path. Reviewed screenshots confirm zero-value stats, the shared border, bold titles, and yellow warning icons in both languages. The harness used synthetic account data and made no live API calls.

## 20. Vendor support-ticket endpoint services

Added on **21 October 2026** from **Vendor → Logic → support-tickets** in the supplied Postman collection, using `https://upgrade.loh.com.sa/api/`.

| Service operation | Request | Body |
| --- | --- | --- |
| Create ticket | `POST vendor/support-request` | Multipart `user_name`, `phone`, `title`, `complaint`. |
| List tickets | `GET vendor/support-tickets` | None. |
| Ticket details | `GET vendor/support-tickets/{id}` | None. |
| Start chat | `POST vendor/support-tickets/{id}/start-chat` | Empty multipart form, matching the collection. |
| Send message | `POST vendor/send-message/{conversationID}` | Multipart `message`. |

[MerchantSupportService](LohProvider/Services/MerchantSupportService.swift) is exposed as `MerchantDependencies.support` and shares Bearer authentication, the current language header, expired-session handling, cancellation, backend/HTTP validation, and full Debug request/response logging. No mutation is automatically retried. Creation validates the documented 50-character name limit and 9–10 digit phone, normalizes Arabic numerals, and requires title/complaint. Path identifiers and nonempty message text are validated before sending.

The user's Postman screenshot confirms creation succeeds with `key` and `msg` only. `MerchantSupportResponse` preserves this success message without requiring or inventing a ticket ID. The collection has no saved success bodies for listing, details, or starting chat, so those methods retain structured JSON, including unknown keys and numeric precision, rather than assume ticket fields, status values, pagination, or the chat-room relationship. Reads require non-null response data; mutation responses allow absent data.

Send Message decodes the saved response into `MerchantSupportSentMessage` and its nested `original_message`, retaining message/room/sender identifiers, sender/seen flags, body, type, and creation timestamp. The caller must supply a confirmed conversation identifier; the implementation does not substitute the ticket ID or infer it from the inconsistent sample URL/room ID.

The existing support screens still use the prototype store. Connecting list/detail/chat views requires confirming those three response shapes and the start-chat conversation identifier. No support ticket or message was sent to the live server during implementation. [MerchantSupportAPIChecks](Tests/MerchantSupportAPIChecks.swift) exercises all five requests, optional creation data, structured JSON preservation, the saved message shape, validation, authentication errors, failures, and cancellation with synthetic responses.

Validation: all **13 check programs** passed, including the Release logging check, and the Debug iOS simulator build succeeded. The support check also passed with the exact message-only success shape from the user's screenshot. `git diff --check` passed.

## 21. Support list integration and phone editing

Updated on **21 October 2026** at the user's request.

- [MerchantSupportView](LohProvider/App/MerchantSupport/Support/View/MerchantSupportView.swift) now calls authenticated `GET vendor/support-tickets` when opened, when its language changes, on Retry, and on pull-to-refresh. The live support store is injected from the app's shared dependencies and scoped to the signed-in session. Loading, empty, and error states are localized; refresh errors retain existing tickets. Cancelled, superseded, or old-account responses cannot replace the current list.
- Sample tickets are limited to explicit Debug previews. The list adapter accepts an array or arrays inside `tickets`, `support_tickets`, and `data` resource wrappers. It requires ticket IDs and titles, reads optional `complaint`, `user_name`, `phone`, and `created_at`, and recognizes explicit `is_open` booleans or `open`/`closed` status strings. Unknown status meanings remain unset, unparsed date strings are preserved, and unsupported structures show an error. These list shapes remain implementation assumptions until a real success response is supplied; pagination parameters are not documented or invented.
- The create form now waits for `POST vendor/support-request` success before navigating to the receipt. It displays server/network errors and prevents duplicate submissions. Because the confirmed response contains only a message, the local submission receipt is kept separately from server tickets; returning to the list fetches the server's current data. No ticket ID or conversation is inferred from creation.
- [MerchantCreateTicketView](LohProvider/App/MerchantSupport/CreateTicket/View/MerchantCreateTicketView.swift) gives phone input an explicit dark text color, left-to-right editing direction, leading alignment, and a minimum editing height. Its number keyboard, focus management, Arabic digit support, and Done dismissal remain available. Phone digits render while focused rather than requiring keyboard dismissal.

Ticket-detail and chat service methods remain available; their UI integration still awaits confirmed response shapes. The detail screen currently shows the selected list record and does not fabricate conversation messages.

Validation: all **13 check programs** and the Release logging check passed. Expanded support checks cover response wrappers, malformed and duplicate IDs, optional metadata, loading/retry/empty states, cancellation, stale requests, account changes, and creation success/failure. The final Debug simulator build passed. An isolated simulator harness confirmed the view invokes the list service and renders populated, empty, and failed responses in both languages. Screenshots and focus/value checks confirmed visible phone input during editing, deletion and Arabic digit insertion, and after dismissal. Network checks used synthetic responses; no live ticket was submitted.

## 22. Native support phone input and both local number formats

Updated on **21 October 2026** following the user's report that phone text still disappeared and nine-digit numbers were rejected.

[MerchantSupportPhoneField](LohProvider/App/MerchantSupport/CreateTicket/Components/SupportPhoneField/View/MerchantSupportPhoneField.swift) replaces the form's SwiftUI phone control with a native `UITextField`. It owns the editing color, font, left-to-right paragraph direction, and a 44-point editing area. Editing changes update the draft immediately, while normal SwiftUI updates preserve the current text buffer and selection. The native control uses separate focus state from the other SwiftUI fields, has a localized Done accessory, and scrolls into view when the keyboard appears. This supersedes Section 21's phone styling approach.

The form and multipart service now share `MerchantSupportPhone` validation: **10 digits starting with `05`**, or **9 digits starting with `5`**. Arabic numerals and whitespace are normalized before submission, and the supplied leading zero is preserved. The placeholder and validation message describe both formats in Arabic and English. Other prefixes, incorrect lengths, letters, and international prefixes are rejected.

Validation: both support model and endpoint check programs passed, including valid/invalid prefix-length combinations, Arabic digits, whitespace, and the exact nine-digit multipart phone value. The final Debug simulator build passed. Simulator checks recorded a visible software keyboard, a focused field above it, and retained values during typing, deletion, Arabic-digit replacement, Done dismissal, and reopening in both languages. Screenshots confirm that digits are visible before dismissal.

## 23. Native merchant tab bar

Updated on **21 October 2026** at the user's request.

[MerchantTabsView](LohProvider/App/MerchantNavigation/Tabs/View/MerchantTabsView.swift) now displays the system `TabView` tab bar. Removed the custom `MerchantTabBar` strip, its bottom inset, and merchant tab-bar hiding modifiers. iOS controls the tab appearance, selection, accessibility, and safe-area behavior, including its native floating style on iOS 26. Each tab retains its own NavigationStack; programmatic selection no longer clears the selected stack.

The tab order is **Offers, Reports, Settlements, Account**, with Offers selected initially. The system follows the language's reading direction: left to right in English and right to left in Arabic. This supersedes the earlier custom strip's forced physical left-to-right order.

Validation: navigation and settlement checks passed, including tab order, independent histories, programmatic selection, and logout reset. The Debug simulator build succeeded. An isolated simulator check confirmed a visible native `UITabBarController`, the four localized items in the requested logical order, Offers as the initial selection, and successful selection of every tab in both languages. Rendered screenshots were reviewed.

## 24. Hide the tab bar on pushed screens

Updated on **21 October 2026** at the user's request.

[MerchantTabsView](LohProvider/App/MerchantNavigation/Tabs/View/MerchantTabsView.swift) now sets native tab-bar visibility from each tab's navigation path. The bar is visible only at the tab root, stays hidden throughout nested navigation, and returns when native Back empties the path. This applies centrally to all merchant destinations and preserves the native tab order and independent navigation histories.

Validation: the Debug simulator build passed. An isolated simulator harness verified all 10 destinations in English and Arabic, checking hidden bars on push, native Back, and restored bars at the root. Nested support navigation also kept the bar hidden at depths two and one before restoring it at the root: **22 navigation cases passed**. Screenshots confirmed hidden bars on detail screens and the restored native bar at the root.

## 25. Ticket labels, logout styling, and settlement endpoint services

Updated on **25 October 2026** at the user's request.

- Ticket field labels use semantic leading alignment, with the title followed by the required asterisk in the language's reading direction. Removed their forced left-to-right layout.
- The account logout button shows its title before its icon. The confirmation sheet's Cancel text now uses the same brand color as its border. `LOHButton` accepts an optional foreground color while retaining its existing default.
- Added [MerchantSettlementService](LohProvider/Services/MerchantSettlementService.swift), exposed through `MerchantDependencies.settlements`, for both requests under **Vendor → Logic → Settelments** in the supplied collection:
  - `GET vendor/my-receipts` through `receipts(token:)`.
  - `GET vendor/settlement-details/{id}` through `details(id:token:)`.

Both requests use the configured `https://upgrade.loh.com.sa/api/` base, Bearer authentication, current language header, shared session-expiry handling, Debug logging, and cancellation/error handling. They send no body or undocumented query parameters. Detail identifiers are validated before making a request.

Both saved responses contain a financial summary rather than a receipt list. `MerchantSettlementFinancials` decodes all seven documented fields, preserving monetary values and `app_percentage` as `Decimal`, including string or numeric JSON representations. It preserves the server's percentage type and currency without imposing the prototype's fixed 25% commission or calculating a transferred amount.

The existing settlement list/detail screens still use fixtures. Connecting them requires a confirmed receipt-list response containing settlement identifiers and the dates, statuses, counts, and transfer/account fields needed by those screens. No settlement identifier, pagination, or payment status is inferred from the summary. Successful authenticated calls remain to be verified with a merchant account; this implementation makes no live API calls.

Validation: [MerchantSettlementAPIChecks](Tests/MerchantSettlementAPIChecks.swift) covers both documented routes and saved summaries, authentication/language headers, decimal precision, invalid identifiers/responses, session expiry, failures, and cancellation. All 14 check programs passed, including the Release logging check. The Debug simulator build passed using a fresh temporary build directory after the previous directory reported a missing cached Objective-C module. An isolated simulator preview rendered the ticket form, account screen, and logout sheet in Arabic and English; all six screenshots were reviewed for the requested alignment, ordering, and color changes. `git diff --check` passed.

## 26. Offers header and statistics from the home response

Updated on **25 October 2026** using the user's supplied `vendor/home-page` response, which adds `data.vendor` and `data.stats` to the older collection's coupon/pagination shape.

- [MerchantOfferService](LohProvider/Services/MerchantOfferService.swift) decodes the vendor's `id`, `name`, `greeting`, and `image`, plus statistics for `total_offers`, `active_offers`, `sales_count`, `sales_total`, and `currency`. Sales totals use the existing exact Decimal-to-halala conversion. Counts accept integer/string representations and reject negative or invalid values.
- [MerchantOffersView](LohProvider/App/MerchantOffers/Offers/View/MerchantOffersView.swift) uses the home vendor's greeting, name, and remote image for its header in Arabic and English. Missing or failed images use the existing store icon. The header no longer reads the session profile.
- Both language layouts show all four server statistics, including the supplied sales currency and fractional sales amounts. Pagination controls only the coupon list; neither matching-offer counts nor loaded rows substitute for account totals. This supersedes the earlier pagination/zero-counter presentation in Sections 17 and 19.
- [MerchantOfferStore](LohProvider/App/MerchantOffers/Shared/ViewModel/MerchantOfferStore.swift) publishes vendor/statistics alongside each accepted home response. New loads clear the previous snapshot; stale, cancelled, and signed-out responses cannot restore it. Later pages preserve the snapshot when metadata is omitted and accept refreshed metadata when supplied. Older responses without either object remain supported with a placeholder header and zero statistics.
- Preview vendor/statistics fixtures now live in the explicit Debug store instead of hardcoded view counters. The supplied empty-home response still displays the vendor and zero statistics correctly.

Validation: all **14 check programs** passed, including the Release logging check. Expanded offer API checks cover the supplied empty shape, populated statistics independent of pagination, decimal amounts, image fallbacks, nullable/absent metadata, malformed values, pagination retention, and stale/cancelled/session-invalidated responses. The Debug simulator build passed. Isolated simulator previews reviewed zero and nonzero statistics in Arabic and English, verified the supplied vendor image loads, and confirmed the header uses the home vendor even when a different session profile is injected. The English sales value stays on one line. Home API responses were synthetic; the image URL was the one supplied by the user. `git diff --check` passed.

## 27. Settlement screen calls my-receipts

Updated on **25 October 2026** at the user's request.

[MerchantSettlementsView](LohProvider/App/MerchantSettlements/Settlements/View/MerchantSettlementsView.swift) now calls authenticated **`GET vendor/my-receipts`** when opened, when its language changes, on pull-to-refresh, and on Retry. [MerchantSettlementStore](LohProvider/App/MerchantSettlements/Shared/ViewModel/MerchantSettlementStore.swift) is injected from the existing `MerchantDependencies.settlements` service through the app root and tabs, with a fresh store for each signed-in session. It uses the same language header, Bearer token, Debug logging, and session-expiry handling as the other merchant services.

The documented financial summary replaces sample rows in the live screen. It displays the server's amount due, LOH commission amount, marketer commission amount, and currency. Decimal formatting preserves fractional values and large amounts without a Double conversion. No transferred status, receipt date, or settlement identifier is invented. Historical receipt rows and their existing detail navigation remain available only through the explicit Debug preview store; connecting a live receipt list still requires its actual response shape.

Loading and failures have localized feedback. Retry and refresh use the same service, ordinary refresh failures retain the last successful summary, and a zero balance remains a valid displayed result. Superseded or cancelled requests cannot overwrite newer results; account changes and invalid authentication clear the previous account's summary.

Validation: all **14 check programs**, including the Release logging check, passed. Expanded settlement checks cover loading, refresh failures, retry, zero amounts, stale responses, cancellation, account changes, authentication expiry, and exact localized Decimal formatting. The final Debug simulator build passed. An isolated simulator harness verified that opening the screen sends exactly one `GET vendor/my-receipts` request with the Bearer token and language header for success, zero balance, loading, and failure in both languages (**8 cases**); screenshots were reviewed, including the full-width loading background. Checks used synthetic responses and made no authenticated live API calls. Both localization files and `git diff --check` passed.

## 28. Persistent profile cache, shared provider images, and live receipts response

Updated on **25 October 2026** using the user's latest requirements and `vendor/my-receipts` response. This supersedes the receipts-summary assumptions in Sections 25 and 27 and the offers image source described in Section 26.

- [MerchantProfileCache](LohProvider/Session/MerchantProfileCache.swift) persists all profile fields, including the image URL, as an atomic JSON snapshot in the app's cache directory. The snapshot is scoped to the API environment and a SHA-256 fingerprint of the authenticated token; the token itself stays in Keychain. Tests and previews use an isolated memory cache by default.
- [MerchantSession](LohProvider/Session/MerchantSession.swift) displays a matching cached profile immediately during restoration, revalidates it through `vendor/profile`, and retains it when the network is unavailable. Successful login, restoration, and profile refresh update the cache. Logout, account deletion, and expired authentication clear it. Missing/mismatched credentials, corrupt snapshots, and stale asynchronous responses cannot expose another account's profile or restore a logged-out cache. Cache I/O failures do not fail authentication.
- [MerchantProviderImage](LohProvider/Shared/DesignSystem/ProviderImage/View/MerchantProviderImage.swift) uses the existing Kingfisher dependency for shared memory/disk image caching and displays a storefront placeholder while missing, loading, or failed. It accepts HTTP(S) image URLs and crops them to the existing rounded/circular frames. Profile and Account use the session's provider image; Offers, Reports, and Settlements use the same profile image in navigation. Offers retains the home vendor's greeting/name and `stats`, with its vendor image as a fallback when the profile has no image.
- [MerchantSettlementService](LohProvider/Services/MerchantSettlementService.swift) now returns `MerchantReceiptPage` from `GET vendor/my-receipts`, decoding `receipts` and all supplied pagination fields, including both `prev_page_url` and the legacy `perv_page_url` spelling. The live empty response succeeds and shows a localized empty state. Loading, Retry, pull-to-refresh, account isolation, and cancellation behavior remain intact.
- The supplied receipt array is empty, so individual receipt fields, amount units, statuses, and detail IDs remain unconfirmed. Receipt objects are preserved without interpreting their fields; a nonempty response displays the server's total receipt count until a populated example permits row/detail mapping. No pagination URLs are followed and no additional query parameters are inferred. `settlement-details/{id}` continues to decode the collection's financial summary independently. Fixture rows remain limited to the explicit Debug preview.

Validation: all **14 check programs**, including the Release logging check, passed. Added disk-cache/relaunch/offline/account-isolation/logout/deletion/corruption checks and updated settlement tests for the supplied empty envelope, pagination validation, preservation of unknown receipt objects, and the separate detail contract. The Debug simulator app build passed. Localization syntax and `git diff --check` passed. No authenticated live API calls were made.

An isolated simulator harness rendered all five requested screens with a disk-cached copy of the supplied public provider image, no image, and an unreachable image URL in Arabic and English (**30 scenarios**). Reviewed image and placeholder screenshots across all five screens; each of the six settlements cases sent exactly one authenticated, correctly localized `my-receipts` request and displayed the supplied empty response without a decoding error. The avatar in the native settlements toolbar was reduced to 32 points with an inset border to fit the toolbar without clipping. The harness used synthetic API responses and did not modify a merchant account.

## 29. Account image viewer, consistent headers, and report API integration

Updated on **25 October 2026** using the report responses supplied by the user and the three report requests in the Postman collection.

- Account and Profile now display a soft off-white (`LOHTheme.subtle`, `#F3F4F6`) circular border around the provider image, updated from the initial brand color at the user's request. Tapping opens [MerchantProviderImageViewer](LohProvider/Shared/DesignSystem/ProviderImageViewer/View/MerchantProviderImageViewer.swift), a full-screen, cached, aspect-fit image with Close, pinch/double-tap zoom, and a missing/failed-image placeholder.
- Settlements places the provider image/name in the semantic leading navigation item, opposite its previous position. Offers and Reports now use the same [MerchantStoreNavigationHeader](LohProvider/Shared/DesignSystem/StoreNavigationHeader/View/MerchantStoreNavigationHeader.swift), preserving the offers header's Arabic/English layout, image dimensions, greeting, name, and underline.
- [MerchantReportService](LohProvider/Services/MerchantReportService.swift) implements authenticated `GET vendor/report` and `GET vendor/detailed-report`, with the documented `last_7_days`, `last_30_days`, `last_90_days`, `current_year`, and `custom` filters. Custom ranges send POSIX/Gregorian `yyyy-MM-dd` values in the Riyadh time zone. The live date picker is anchored to the current day; the old May 2026 data and date limits are confined to explicit Debug previews.
- [MerchantReportModels](LohProvider/App/MerchantReports/Shared/Model/MerchantReportModels.swift) decodes the supplied summary `stats`, comparisons/trends, grouped chart points and labels, and top-offer pagination. Detail data preserves the server period label, currency, note, statistics, rows, and totals. Financial values retain Decimal precision; only chart coordinates convert to Double. Displayed totals, averages, and changes come from the server rather than being calculated from loaded rows or fixed prototype percentages.
- [MerchantReportStore](LohProvider/App/MerchantReports/Shared/ViewModel/MerchantReportStore.swift) is injected through dependencies/root/tabs. Summary and detail screens load their own endpoints on appearance, language/filter changes, Retry, and pull-to-refresh. Separate request generations prevent stale or cancelled loads from replacing current data; account changes and expired authentication clear prior payloads. Refresh failures preserve data for the same selection, while a changed period clears old results.
- Downloads first call `GET vendor/download-report/{MM-yyyy}/{MM-yyyy}` and decode the supplied `data.download_link`, then fetch the PDF over HTTPS without merchant authorization or cookies. Save and Share use the downloaded file; live export no longer generates a sample report locally. The export sheet shows the month range used by this endpoint. PDF signature/content checks reject HTML, JSON, or unusable PDF downloads, and cancellation/errors have normal UI feedback.
- The user's `top_offers.offers` array is empty. This renders a localized empty state; unknown populated offer objects are preserved and their server total count can be shown, but offer-row fields are not guessed. The supplied fixtures are stored under [Tests/Fixtures](Tests/Fixtures).

Validation: all **15 check programs**, including the Release logging check, passed, and the Debug simulator app build succeeded. New report checks cover the supplied envelopes, zero and nonzero totals, exact decimals, grouped labels, preset/custom query encoding, dates and month-path downloads, JSON download links, credential-free PDF fetching, invalid responses, session expiry, refresh/retry, cancellation, stale selections, and account isolation. Localization syntax and `git diff --check` passed. API checks use synthetic responses, not a live merchant account.

An isolated simulator harness covered **22 scenarios** across Arabic and English: offers/reports header layout, zero/nonzero/loading/error reports, detail rows, the flipped settlements identity, bordered Account/Profile images, date selection, and export options. It verified the image viewer presents from both account screens and confirmed summary/detail requests plus JSON-link/PDF fetching through synthetic transports. Chart labels were adjusted to preserve complete month names and give the first/last points enough horizontal space. Full-screen presentation was triggered through the same view state as the image button; pinch gestures and the system Save/Share destinations were not automated.

## 30. Coupon customers, purchase details, sale amounts, and delivery

Updated on **25 October 2026** using the saved Postman examples. The user does not yet have additional live responses for these routes.

[MerchantOfferService](LohProvider/Services/MerchantOfferService.swift) now implements all five authenticated routes with the existing language, error, and session-expiry handling:

| Route | Screen/action |
| --- | --- |
| `GET vendor/coupon-details/{couponId}` | Opening or refreshing offer details loads the customer preview. |
| `GET vendor/coupon-users/{couponId}` | View All loads the full customer list for that coupon. |
| `GET vendor/order-details/{orderID}` | Opening/refreshing a selected purchase and checking its entered/scanned code send its server order ID, then validate the returned purchase code/customer (Section 46). |
| `GET vendor/coupon-sales/{id}` | The selected purchase displays the returned quantity, price, LOH amount, and currency after identity validation. |
| `POST vendor/deliver-coupon/{print_code}?_method=put` | Confirm Delivery sends the purchase code, with no invented body, and accepts the collection's message-only success response. |

The three purchase-list routes return arrays in the saved collection. Customer IDs are not order IDs: each row remains identified by coupon ID plus the complete purchase code, including leading zeros. `used_status` remains server text; it is not treated as a purchase or expiration date. Sale amounts use exact Decimal-to-halalas decoding and are displayed directly; the app does not assume that `price` must be multiplied by `qty`.

**Provisional sales lookup:** the collection uses `693` for `coupon-sales/{id}` but exposes no separate sale ID in its customer/detail examples. As stated during implementation, the screen initially supplies the selected coupon ID. It only displays the result if both `purchase_code` and `user_details.id` match the selected purchase. A mismatch produces a retryable error instead of another purchase's financial data. The backend meaning/source of this path ID still needs confirmation with a live populated response.

Live code entry and scanning now work from a selected customer purchase. Numeric codes can have the lengths present in the collection; Arabic/Persian digits normalize to ASCII while preserving leading zeros. A matching code triggers a fresh, read-only order-details check. Verification alone never delivers the coupon. The merchant must then press Confirm Delivery; duplicate taps are suppressed, and only an acknowledged success updates delivery state and displays the server message. Known delivered statuses also prevent another submission. An uncertain or failed submission requires fresh verification before another attempt, and successful delivery is retained across stale list/detail reads for the current session. Cancellation, stale verification, and account changes cannot authorize or apply a response to another session.

The collection has no documented global read-only lookup by purchase code. The home verification message therefore directs merchants to open an offer and select a purchase first; the delivery mutation is never used to look up an arbitrary code. Existing six-digit local verification remains confined to explicit Debug previews.

Validation: all **16 check programs**, including the Release logging check, passed. [MerchantCouponFulfillmentChecks](Tests/MerchantCouponFulfillmentChecks.swift) covers the saved route/response contracts, authentication/language headers, exact money, leading zeros, invalid path values, selected-customer matching, fresh verification, server-confirmed delivery, duplicate suppression, timeout recovery, cancellation, and account isolation. The Debug simulator build passed. An isolated simulator harness rendered **14 scenarios** across Arabic and English: offer customers, pending/verified/delivered purchases, sale errors, delivery errors, and code entry. It verified the screens call the expected routes with synthetic responses; no live merchant deliveries were made. Screenshot review moved delivery errors beside the action controls so they remain visible without scrolling. Physical camera scanning and live server behavior remain unverified. Localization syntax and `git diff --check` passed.

## 31. Live coupon-details envelope and coupon metadata

Updated on **25 October 2026** from the user's `vendor/coupon-details/197` response, saved in [MerchantCouponDetails.json](Tests/Fixtures/MerchantCouponDetails.json). This supersedes the collection's array response described in section 30 for this route only.

- `couponDetails` now returns a typed `MerchantCouponDetails` containing `coupon`, `orders`, and `pagination`. It validates the returned coupon ID and first-page counts, accepts the supplied zero-orders/one-page response, preserves exact price values, and retains the server's publication/update labels and status text. Missing or invalid image URLs resolve to the image placeholder.
- The offer-details header uses the returned name, image, price, status, publication date, and update text. Coupon images use the existing Kingfisher memory/disk cache and a tag placeholder for missing/failed images. Selected-purchase screens also receive the refreshed coupon name, price, and image through the store's offer lookup. Home sales aggregates remain independent of the coupon price and order pagination.
- The `orders` array populates the customer preview; the empty array shows the normal empty state. Pagination determines whether View All is available, and View All still loads `coupon-users`. Refreshing either mode also refreshes the coupon metadata. The supplied response has no populated orders; populated row decoding continues to use the purchase fields documented by the older collection until a live row establishes otherwise.
- Coupon details are retained for the current session across ordinary refresh errors, cleared on account changes, and protected against stale/cancelled requests alongside the customer preview.

Validation: all **16 check programs**, including Release logging, passed, and the Debug simulator build succeeded. Expanded fulfillment checks cover the exact supplied envelope, coupon metadata, empty orders, pagination, image fallbacks, exact price, invalid IDs/counts, existing purchase-row mapping, home aggregate preservation, refresh errors, cancellation, stale responses, and account isolation. Localization syntax and `git diff --check` passed.

An isolated simulator harness verified **8 Arabic/English scenarios** covering the supplied empty response, the actual coupon image loaded from cache, missing/failed image placeholders, and populated rows using the collection's documented purchase fields. Screenshot review confirmed all coupon labels and the empty state render correctly. View All was triggered through its view state and verified to load four synthetic purchases from `coupon-users`. Requests used synthetic API responses; only the public image supplied by the user was downloaded.

## 32. Shared offers layout and project-wide feature folders

Updated on **25 October 2026** to separate every screen and reusable view into its own feature folder.

A flow such as `MerchantReports` is a grouping folder, not one combined screen. Its screens and shared components now have independent folders:

```text
LohProvider/App/MerchantReports/
├── Reports/
│   ├── View/MerchantReportsView.swift
│   └── Components/
│       ├── ReportSummaryContent/View/MerchantReportSummaryContent.swift
│       └── ReportOfferArtwork/View/MerchantReportOfferArtwork.swift
├── ReportDetails/
│   └── View/MerchantReportDetailView.swift
├── ReportPeriod/
│   └── View/MerchantReportPeriodView.swift
├── ReportExport/
│   ├── View/MerchantReportExportView.swift
│   ├── Model/ (PDF document and native share representation)
│   ├── ViewModel/ (export state and PDF renderer)
│   └── Components/ (each component has its own View folder)
└── Shared/
    ├── Model/
    │   ├── MerchantReportModels.swift
    │   └── MerchantReportPeriodModels.swift
    ├── ViewModel/MerchantReportStore.swift
    ├── ReportMetric/View/MerchantReportMetric.swift
    ├── ReportIcon/View/MerchantReportIcon.swift
    └── …
```

- Each screen, sheet, reusable view, modifier, shape, button style, or UIKit view bridge has its own feature/component folder. Its `View` folder contains exactly one Swift file named after its UI type. Small private view-building methods, previews, and a representable's delegate coordinator may stay with their owning type.
- `Model` and `ViewModel` are optional: create them only when that feature has actual model or state/behavior source files. Empty role folders and all `.gitkeep` placeholders have been removed, along with their Xcode target exclusions.
- `Components` contains views owned by one screen, each with its own folder and `View` subfolder. `Shared` contains components and models/state used by multiple screens within a flow. Existing observable stores are shared deliberately; the folder refactor does not duplicate them into screen-specific stores or change their lifetime.
- Offers, offer details, order details, code entry, and scanning are independent features under `MerchantOffers`. Account, profile, and language are separate under `MerchantAccount`; support, create ticket, ticket details, and confirmation are separate under `MerchantSupport`; settlements and settlement details are separate under `MerchantSettlements`.
- The same separation applies to retained legacy screens, navigation, root views, design-system components, custom controls, and helpers. Legacy screen-specific header/row components no longer sit beside another screen in one `View` folder. The design root now belongs to merchant navigation rather than login.
- Platform bootstrap, networking, services, session infrastructure, localization, fonts, and assets keep their responsibility-based directories. Map-style resources now live under `Shared/Helpers/Location/Resources`, eliminating the remaining obsolete `Loction` folder.

[MerchantOffersView](LohProvider/App/MerchantOffers/Offers/View/MerchantOffersView.swift) retains the single shared Arabic/English composition introduced in this refactor. The `arabicOffers`/`existingOffers` branches are gone. Search, sort, retry, pagination, and verification availability use the same code path; locale supplies strings, dates, and numbers, while semantic alignment follows RTL/LTR. Accessibility text sizes use a scrolling screen and a two-column statistics grid.

[check-structure.py](Scripts/check-structure.py) uses Xcode's Swift parser through [inspect-swift-structure.swift](Scripts/inspect-swift-structure.swift) to validate syntax, one UI type per file, exactly one UI file per feature's `View` folder, matching filenames, and the absence of empty role folders/placeholders. It runs before the behavioral checks in [run-checks.py](Scripts/run-checks.py). Test source lists and all source links in this document follow the new paths.

The corrected folder split moves **151 files** and removes **96 placeholders**. Hash comparison confirms all **349 app Swift sources** are byte-for-byte identical to the sources before this folder correction, with no files lost or duplicated. UI behavior and API implementation are unchanged by these moves.

Validation: the structure check passes for **194 UI types across 209 feature/component folders**. All **16 behavioral check programs**, including Release logging, pass with the updated source paths. The full Debug iOS simulator build succeeds, including retained legacy screens. Xcode project syntax, all 57 source links in this document, and `git diff --check` also pass.

## 33. Report date controls

Updated on **25 October 2026** from the user's selected-period screenshot.

- Corrected the swapped Arabic calendar/dropdown vector assets. The shared report filter now displays calendar, date range, then dropdown in reading order in both languages.
- The period picker title uses medium weight. Preset calendar outlines now use template rendering so the selected calendar and its label both become brand yellow; inactive presets remain gray.
- From precedes To in the interface's reading direction, with a matching directional arrow. The active date field's calendar also uses the brand color.
- The selected-period summary uses a yellow outlined 24-point calendar inside a 48-point pale circular background, matching the supplied icon treatment.

The full Debug simulator build, SVG validation, source structure check, and `git diff --check` pass. An isolated simulator preview rendered all four selected presets in Arabic and English; screenshot review confirmed the filter icons, medium title, From/To ordering, and yellow circular calendar treatment. Report request, date-range validation, and apply behavior are unchanged.

## 34. Report statistics and interactive sales chart

Updated on **25 October 2026** from the supplied screenshot and the report region in [Figma frame 111:7421](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/?node-id=111-7421).

- The overview uses horizontal icon/value cards, a white unboxed sales chart, and the centered green total and growth capsule. Existing Cairo typography and report icons are retained; order-icon and positive-growth backgrounds use new color tokens. Compact text frames scale with Dynamic Type.
- [MerchantReportOverview](LohProvider/App/MerchantReports/Reports/Components/ReportSummaryContent/Model/MerchantReportOverview.swift) presents both live API values and preview snapshots through one composition. Amounts preserve decimal precision and server currency; zero values remain zero. Growth direction and comparison text come from the API.
- [MerchantSalesChartView](LohProvider/App/MerchantReports/Reports/Components/SalesChart/View/MerchantSalesChartView.swift) uses Swift Charts area, line, point, and selection-rule marks. Tap or horizontal drag selects the nearest period; its popup displays the label, date, and exact sales amount. Tapping the selected period or closing the popup clears it. Vertical drags are ignored by selection logic so the enclosing scroll view can handle them.
- Chart scale and selection behavior live in the chart's Model and ViewModel folders. Empty, zero, negative, single-point, and longer series are handled. Dates remain chronological in both languages, end labels remain visible, and the popup stays within chart bounds. Changed datasets clear stale selection. VoiceOver adjustable actions select periods, with a named clear action.
- New cards and the selection popup each have their own component folder and one view file, following section 32's structure.

Validation: all **17 check programs** passed, including new scale/selection/precision checks and the support checks below. An isolated simulator harness rendered **14 Arabic/English scenarios** plus **6 selected-point screenshots**, covering the design example, zero, single point, empty, dense data, declining sales, and tickets. It exercised actual chart proxy conversion at first, middle, and last points and verified selection/toggle behavior. Screenshot review caught and corrected hidden end labels and RTL popup positioning. The full Debug simulator build passed. Direct mouse gesture automation could not finish because Simulator control returned noWindowsAvailable and a ScreenCaptureKit capture error; physical gestures remain unverified. No production API mutations were performed.

## 35. Updated support-ticket response

Updated on **25 October 2026** from the user's direct-array support-tickets response, saved in [MerchantSupportTickets.json](Tests/Fixtures/MerchantSupportTickets.json).

- Ticket name maps to the title and description maps to the body. Optional user_name remains a separate sender field.
- The model retains status and status_text; list/detail cards display the server's status text. Boolean is_open determines badge state, with open/closed status-string fallback when the boolean is absent. Legacy title/complaint fields remain supported.
- created_at accepts the supplied yyyy-MM-dd HH:mm:ss timestamps and existing ISO timestamps. Unqualified timestamps are interpreted and displayed in Asia/Riyadh, preserving the backend's Saudi wall-clock time. Unrecognized dates retain their original text.
- Checks load all four supplied rows through the support store and verify titles, descriptions, status labels, IDs, and date/time values. They also cover field precedence, conflicting boolean/status values, legacy responses, and malformed dates. Arabic/English simulator previews confirm the ticket content and badges render correctly.

## 36. Populated report top offers

Updated on **25 October 2026** from the user's populated top_offers response, saved in [MerchantReportTopOffers.json](Tests/Fixtures/MerchantReportTopOffers.json). This supersedes the earlier count-only display used while offer fields were unknown.

- The report action has a dedicated localization key: Arabic **التقرير التفصيلي**, English **Detailed Report**.
- The report response now decodes typed top offers with ID, name, image URL, currency, sales count, exact decimal sales total, status, and server status text. The generic placeholder payload type has been removed. Existing pagination and empty-state behavior are retained.
- [MerchantReportTopOfferRow](LohProvider/App/MerchantReports/Reports/Components/TopOfferRow/View/MerchantReportTopOfferRow.swift) displays the API image, name, status badge, sales total/currency, and sales count. Kingfisher supplies image caching and a tag placeholder for absent, invalid, or failed images. Accessibility text sizes place the sales section below the offer identity.
- Report API checks cover the supplied offer through the request and store paths, populated/empty results, pagination, exact decimal amounts, numeric amounts, inactive status, image fallbacks, and invalid amounts/counts. Top-offer values do not overwrite report-wide statistics. Report model, API, and chart checks pass, along with the full Debug simulator build, structure and localization checks.

Four simulator previews verified Arabic/English at regular and accessibility text sizes, including the supplied image loaded from cache, the missing-image placeholder, active/inactive badges, amounts/counts, and the new button title.

## 37. Detailed report design

Updated on **25 October 2026** from the user's two screenshots and [Figma's detailed report frame](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/?node-id=111-7739).

- [MerchantReportDetailView](LohProvider/App/MerchantReports/ReportDetails/View/MerchantReportDetailView.swift) now shares one presentation between live and preview data. Its components have individual View folders; the screen's presentation adapter lives in Model. The existing report store, loading/retry, refresh, period selection, and export flow remain connected.
- The white screen uses the detailed-report title, native back navigation, cached provider image/name, and the small brand underline. The merchant identity omits the automatic toolbar background on iOS 26 while retaining native navigation behavior.
- Three connected summary columns show orders, sales, and average order value with the Figma icon backgrounds. The sales table has equal columns, pale headers, subtle cell borders, a highlighted period-end row, and an integrated totals footer. Server summary and totals remain independent; amounts retain decimal precision, currency and labels remain server-supplied, and zero/empty states remain visible.
- End-row highlighting follows daily, monthly, or yearly date grouping. Unknown groupings do not guess a highlight. At narrow widths or accessibility text sizes the table scrolls horizontally; large text stacks the summary metrics vertically. The screen has one vertical scroll area so the note and download/share actions remain reachable.
- Download, calendar, and dropdown icons were imported as exact Figma SVGs. The detail screen consistently uses the matching share/check icons in both languages, avoiding the pre-existing English share asset that depicts a download. Existing typography and theme colors are reused, with dedicated table-header and highlighted-row color tokens.

Validation: report model/API/chart checks and the full Debug simulator build pass. Expanded checks verify date grouping/highlighting, original server labels, independent summary/footer totals, empty rows, and precise amounts. Ten isolated simulator scenarios cover Arabic/English, populated daily data, the supplied zero-valued monthly response, empty rows, 320-point widths, and accessibility text sizes, including top/bottom screenshot review. No production API mutations were performed.

## 38. Report export sheets and native sharing

Updated on **25 October 2026** from the user's three screenshots and Figma overlays [options](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/?node-id=117-9510), [saving](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/?node-id=118-9324), and [ready](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/?node-id=118-9354).

- The initial export sheet has the centered title/subtitle, calendar/date row, yellow Save button, bordered Share button, and plain Cancel action. Save first displays the PDF preparation illustration, animated indeterminate progress bar, information card, and bordered Cancel button. Successful preparation transitions to the green-check ready sheet with a PDF file summary and Save/Share actions. Sheet height follows the current state; accessibility text sizes use the large detent and a stacked file summary.
- Share uses native SwiftUI `ShareLink` and an asynchronous PDF `FileRepresentation`. It opens the system share screen directly and obtains the file on demand, without a separate custom share screen or a save/ready interstitial. `MerchantReportShareView` and its empty folders were removed.
- `MerchantReportExportViewModel` owns preparation, validation, cancellation, errors, and the prepared file. Save and Share reuse one in-flight download and the validated local PDF. Invalid/empty PDF documents and disk errors cannot produce a ready state; cancellation cannot publish a late success. The existing service still downloads the JSON `download_link` result and PDF, with the existing authentication and credential-isolation checks.
- Save from the ready sheet opens the native Files picker. The sheet says the PDF is ready until the picker confirms a successful save, then shows the saved message. It does not claim a file was automatically saved in Downloads. The displayed live PDF period remains month-based to match the server download contract.
- Each export component has its own View file/folder. Imported Figma icons, existing theme/typography, and a pale PDF badge color reproduce the reference while keeping the Share label on one line at regular sizes. The former unused report action button was removed.

Validation: the full Debug simulator build, export state checks, report API checks, source-structure checks, localization validation/key parity, and whitespace checks pass. Simulator review verified Arabic options/preparation/ready, English ready, and Arabic accessibility text. Tapping Share opened the native share screen; tapping Save reached the ready sheet, and tapping Save there opened Files. Checks cover shared download reuse, file contents, invalid PDF, network/disk errors, cancellation/retry, direct sharing without save-stage changes, and save confirmation. All preview data was local; no report was sent to another person.

## 39. Offer cards and populated recent orders

Updated on **26 October 2026** from the user's populated `vendor/coupon-details/197` response and [offer-detail Figma frame](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/?node-id=111-6892).

- The sort menu now aligns to the semantic leading edge: right in Arabic and left in English. Offer rows use inset rounded cards, a clear image/title/date area, and a separate pale statistics strip with subtle separators. Optional home-response images are decoded and displayed through the existing Kingfisher cache and placeholder; returning from details also reuses refreshed coupon metadata.
- Offer details now match the supplied summary card: image, title, active-status badge, last-update text/calendar, price, and publication date. Latest Orders shows the customer, per-order coupon name, status badge with a colored dot, and the server's formatted creation timestamp. View All retains the existing `coupon-users` route and Show Less behavior. The empty state does not draw an empty orders card. New components each have their own View folder; narrow screens and accessibility text use stacked layouts.
- [MerchantCouponDetails.json](Tests/Fixtures/MerchantCouponDetails.json) now contains the three supplied orders and pagination (`3` items on page `1`, `7` total, `3` pages). The original empty response is retained as [MerchantCouponDetailsEmpty.json](Tests/Fixtures/MerchantCouponDetailsEmpty.json).
- Recent-order decoding now maps `id`, `print_code`, `customer_name`, `coupon_name`, `created_at`, `created_at_text`, `status`, and `status_text`. Server order IDs remain separate from customer IDs. The stable coupon-plus-code identity continues to join recent orders with the collection's customer/order-detail response shapes, preserving leading zeros. Missing customer identity can be resolved by an exact coupon/code match; a known customer identity is still checked on subsequent refresh/verification. Matching refreshes retain recent-order metadata, while a changed delivery state cannot retain a stale pending label.
- Header/calendar/price/customer assets reuse exact existing SVGs; the recent-order and View All chevrons were imported from Figma. Existing localization, theme, image caching, report flows, and delivery-confirmation rules remain in use.

Validation: the final Debug simulator build, offer model/API checks, coupon fulfillment checks, source structure, localization/key parity, and whitespace checks pass. Checks cover the populated response, retained empty/legacy responses, exact status/date values, order/customer identity separation, leading-zero codes, invalid identities, refresh/verification matching, metadata retention, delivery-status changes, optional image decoding and placeholders. Arabic simulator screenshots verified the populated detail layout, status/calendar/customer/chevron geometry, the leading sort control, and rounded offer cards. Desktop UI automation encountered capture/accessibility errors; physical View All taps and English/accessibility visual checks were not completed. All requests used local fixtures; no production deliveries were performed.

## 40. Whole-screen offers scrolling and cancellation logging

Updated on **26 October 2026**.

- `MerchantOffersView` now has one vertical scroll view containing the merchant header, search, statistics, verification controls, sort menu, and offer cards at every text size. Pull-to-refresh and interactive keyboard dismissal belong to that same scroll view. The header retains vendor data and the cached profile image fallback.
- The API client now recognizes task/URL cancellation before emitting failure diagnostics. Cancelled requests still propagate `CancellationError` for the existing store cancellation handling, but no longer print `REQUEST FAILED`. Real transport failures continue to be logged and mapped normally. The same rule applies to report PDF downloads.
- Debug and Release logging checks cover both cancellation representations for API and document requests, and confirm real timeouts still produce failure diagnostics. Offer API checks, source-structure checks, whitespace checks, and the full Debug simulator build pass.

## 41. Offers pull-to-refresh data retention

Updated on **26 October 2026** after refreshing could leave the offers screen empty.

- Same-filter reloads retain the loaded offers, vendor, statistics, count, and pagination until a successful first-page response replaces them. Failed or cancelled refreshes keep the snapshot; successful empty responses still show the empty state. Changed filters clear the previous results, and an account change clears cached account data even if its pending request fails.
- Pull-to-refresh awaits a store-owned task so cancellation of SwiftUI's refresh action does not discard the request. Leaving the screen or starting a query, sort, or language reload explicitly cancels that task. Existing generation checks prevent stale responses from overwriting newer results.
- The loaded list stays visible during refresh, with a brand-colored loading indicator above the offer cards for the full request duration. Pagination is disabled until refresh finishes, retains its position on failure, and restarts from page one on success. The whole screen remains in one scroll view.

Validation: offer API/model and coupon fulfillment checks pass, including delayed refreshes, gesture-task cancellation, explicit screen-exit cancellation, request failures, retry pagination, replacement/empty responses, filter supersession, and logout during refresh. The Debug simulator build, source-structure and whitespace checks pass. These checks use local stubs, without production API calls.

## 42. Report refresh request lifetime

Updated on **26 October 2026** for the same pull-to-refresh cancellation issue in reports.

- Overview and detailed reports now await separate store-owned refresh tasks. SwiftUI refresh-action cancellation cannot discard the response; leaving the corresponding screen, starting a new reload, or applying a different date range explicitly cancels its pending refresh.
- Both screens retain their report during refresh and show a brand-colored loading indicator until the request finishes. Existing error/retry handling, successful empty/zero responses, date-range protection, and account isolation remain intact.
- Report API checks cover both screens with delayed responses, cancellation of the caller, loading/data retention, network and cancellation failures, screen exit, superseding reloads, period changes, and logout. Report model/chart checks, the Debug simulator build, and source-structure/whitespace checks pass. Checks use local fixtures and stubs without production API calls.

## 43. Offer-detail order list and refresh

Updated on **28 October 2026**.

- `MerchantOfferDetailView` displays every order returned by `coupon-details`, removing the local three-row limit and Show All/Show Less toggle. The screen consistently uses `coupon-details` on initial load, retry, and refresh, without switching to `coupon-users`. Refreshed orders follow the server's ordering while retaining resolved customer and delivery metadata.
- Pull-to-refresh belongs to the detail scroll view and awaits a store-owned task per offer. Gesture-task cancellation cannot discard its response; screen exit, a newer load, or an account change cancels the pending refresh. The current coupon and orders remain visible with a loading indicator throughout the request.
- The user's `{}` log was under the outgoing GET request body, not a server response. The request correctly has no HTTP body. Actual empty/malformed responses remain errors and preserve the current list; a valid `orders: []` response clears it.

Validation: coupon fulfillment and offer API/model checks pass, including lists larger than three rows, server ordering, one request to the correct endpoint, gesture and explicit cancellation, newer-load protection, malformed/empty bodies, timeout, valid empty lists, and logout. The Debug simulator build, source-structure and whitespace checks pass. Tests use local responses without production API calls.

## 44. Report period controls and table interaction

Updated on **28 October 2026**.

- Overview and detailed reports use one period-button appearance: the same calendar/dropdown icons, medium title weight, leading alignment, height, border, and layout direction. The detailed report can still supply its server-provided period label.
- An end date earlier than the start date immediately shows the existing localized range warning in the fixed footer above Apply. The warning wraps and stays visible as the form scrolls; invalid ranges cannot be applied.
- The detailed report table fits the available screen width without an internal horizontal scroll view or a forced minimum width. Cells and totals wrap within their columns, and the report's outer vertical scroll view remains the sole scrolling container.
- Tapping a data row toggles a pale selection highlight and accent marker with a short animation and selection haptic. Selection is exposed to accessibility with localized hints, respects Reduce Motion, and clears when its date disappears from the report.

Validation: the Debug simulator build, source-structure and whitespace checks, localization syntax, and Arabic/English key parity pass. Local simulator previews verify matching period buttons, the invalid-range warning above Apply in Arabic and English (including an accessibility-size environment), and all four table columns on a 320-point layout. The totals label stacks its icon when needed. Automated tap verification could not complete because macOS returned `noWindowsAvailable` and a ScreenCaptureKit capture error; screenshots remained available for layout review.

## 45. Automatic native PDF save picker

Updated on **28 October 2026**.

- Save PDF now proceeds from preparation directly to the native Files save-location picker. The ready screen no longer requires a second Save tap before choosing a destination.
- The preparation layout and sheet height remain stable while the picker opens. The ready/saved state appears after returning from Files, and successful saving is still reported only after the system confirms the export.
- The export view model owns picker presentation. Duplicate saves, failed/invalid PDF preparation, and cancelled tasks cannot open another or a late picker. Cancelling Files retains the prepared PDF for retry; Share continues to use the system share screen independently.

Validation: export-state and report API checks pass, including automatic picker presentation, duplicate suppression, cancellation/retry, cached files, invalid PDF and disk errors, sharing isolation, and saved-state confirmation. The Debug simulator build, source-structure and whitespace checks pass. A local simulator preview confirmed that PDF preparation opens the native Files picker automatically. All checks use local PDFs and response fixtures.

## 46. Order-detail route uses the order ID

Updated on **28 October 2026** from the user's endpoint clarification.

- Order detail loading/refresh and code/barcode verification now call `vendor/order-details/{orderID}` with `serverOrderID`, decoded from each `coupon-details.orders[].id`. For the supplied order `910` belonging to coupon `197`, the request is `GET vendor/order-details/910`.
- The older collection's coupon-ID label no longer controls the request. Coupon ID is not sent in the path, query, or body; Section 47 now reads it from the response's nested coupon. Customer ID and purchase code remain distinct. A missing order ID produces a visible error without sending a substitute identifier.
- Existing purchase/customer matching, metadata preservation, confirmed-delivery handling, cancellation, and account isolation remain in place.

Validation: offer API/model and coupon fulfillment checks pass for the corrected URL in both detail refresh and verification, missing/invalid order IDs, preserved coupon/purchase identity, customer mismatch, delivery, cancellation, and account changes. The Debug simulator build, source-structure and whitespace checks pass. Requests use local test responses rather than the live API.

## 47. Live single-order details response

Updated on **28 October 2026** from the user's `vendor/order-details/916` response, which supersedes the older customer-array example in the collection.

- `MerchantOfferService.orderDetails` decodes a single object. The response's order ID must match the requested ID; its nested coupon/customer IDs and purchase code must match the selected purchase before refresh or verification can update it. Order `916`, coupon `197`, and customer `4743` remain distinct identities.
- [MerchantOrderDetails](LohProvider/App/MerchantOffers/OrderDetails/Model/MerchantOrderDetails.swift) retains the coupon number/image, exact price and currency, both date/time objects, and customer verification metadata. Nullable verification method/time and phone are supported; codes retain leading zeros. `status` and localized `status_text` populate the purchase model.
- [MerchantOrderView](LohProvider/App/MerchantOffers/OrderDetails/View/MerchantOrderView.swift) uses the returned coupon name/image, price, purchase/expiry text, coupon number, purchase code, localized order status, customer contact, and verification information. It no longer sends the provisional coupon-ID `coupon-sales` request when opening or refreshing an order. That endpoint remains implemented separately, but its quantity/commission are not invented for this response.
- Customer-list refreshes preserve richer order details. Invalid or mismatched responses leave the last loaded order visible. Server verification metadata does not itself authorize delivery; the existing explicit verification/confirmation flow remains in place.

Validation: offer API/model and coupon fulfillment checks pass using the supplied response structure with synthetic customer name/phone. Coverage includes every field, null and populated verification metadata, image placeholders, leading-zero codes, identity mismatches, malformed responses, data retention, delivery, cancellation, and account isolation. The Debug simulator build, source-structure, localization syntax, and whitespace checks pass. No production requests were sent.

## 48. Ready and used order designs

Updated on **28 October 2026** from the user's screenshots and Figma's [ready order](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/?node-id=111-7111) and [successful delivery](https://www.figma.com/design/FYN2HgYcuBioezCOg51Ubv/?node-id=111-7260) frames.

- `MerchantOrderView` now uses the cached merchant header, green result card, offer summary with three date/price columns, customer information, and fixed bottom actions. The `ready` state shows the found-order message, verification method, Confirm Delivery, and Cancel. The `used` state shows delivery success, a thank-you message, and Continue. The summary displays API names, images, status text, exact amounts, and formatted dates/times; absent verification information is not replaced with a fabricated barcode verification.
- Each extracted component has its own View file/folder under OrderDetails. `MerchantOrderPresentation` lives in Model and derives the screen state without adding a redundant view model. Existing typography, theme, image placeholders, and Figma assets are reused; a green verification QR asset was imported, and the customer verification row uses the vertical barcode symbol from the screenshot.
- A successfully loaded, matching order-details response with `status: ready` permits explicit confirmation without requiring another code entry. `status: used` counts as delivered, including when first opening the screen. Confirmation retains the existing delivery endpoint, purchase-code identity, in-flight/duplicate protection, account isolation, and failure handling. An uncertain delivery cannot be repeated until a fresh order-details read or verification succeeds. Acknowledged delivery immediately replaces the confirmation actions with Continue.
- Reviewed `/Users/haneen/Downloads/NewLoh.postman_collection-2.json`. Its order-details request still uses a purchase-code-looking example and its saved response is the older customer array. The user's explicit order-ID clarification and live singleton response remain authoritative: requests send `vendor/order-details/{orderID}`. The collection's delivery route remains `POST vendor/deliver-coupon/{purchaseCode}?_method=put`.

Validation: the full Debug simulator build, offer model/API checks, coupon fulfillment checks, source structure, localization syntax/key parity, and whitespace checks pass. Expanded checks cover ready/used presentation, explicit ready confirmation, missing verification metadata, duplicate suppression, uncertain-delivery refresh, and blocking delivery of a used order. Local Arabic and English simulator previews verified the layouts; tapping Confirm Delivery with a stubbed response transitioned to the success screen and Continue. All preview requests were local; no production deliveries were performed.

## 49. Merchant notifications UI and services

Updated on **29 October 2026**, using the notification contracts in `/Users/haneen/Downloads/NewLoh.postman_collection-2.json`.

- `MerchantOffersView` now has a notification bell in its merchant navigation header. The badge uses `vendor/count-notifications` and refreshes on screen entry, language changes, foreground entry, and offers refresh. The server count remains authoritative; opening the screen does not invent a mark-as-read request or clear the badge locally. Other consumers of the shared merchant header retain their existing layout.
- [MerchantNotificationsView](LohProvider/App/MerchantNotifications/Notifications/View/MerchantNotificationsView.swift) uses the existing authenticated vendor service for the list, count, deletion by notification ID, and clearing all notifications. The screen includes loading, empty/error/retry states, pagination, pull-to-refresh, localized relative dates, and confirmation before deletion. Titles and body text come from the API. Arabic and English UI strings, semantic layout direction, merchant typography, and theme colors are shared with the rest of the app.
- `MerchantNotificationStore` is created with the signed-in session and injected into the merchant tab stacks. Refresh requests survive cancellation of the gesture task, retain existing content on failure, and discard stale responses. Pagination deduplicates IDs. Confirmed single deletion reloads page one to avoid skipping items when page boundaries shift; both deletion operations resynchronize the badge. Concurrent mutation requests are suppressed, failed deletions retain the current list, and account changes clear state and reject late responses.
- Clickable notifications with a positive coupon ID open offer details in the merchant navigation stack. Coupon details can now supply the summary even when that offer is outside the loaded home-page filters or pagination; loading/retry remain visible for such links. Nonclickable administrative notifications remain informational. The legacy trip-notification screen and Firebase/APNs configuration are not used by this integration.
- Notifications, the bell, and the notification row each have their own feature/View folder. The list has its own Model and ViewModel folders. The live service is wired from `MerchantDependencies.notifications`; the previous service-only implementation described in Section 16 is now connected to the merchant UI.

Validation: the Debug simulator app build and six targeted check programs pass (notifications, Vendor/Auth contracts, navigation, coupon fulfillment, offer API, and offer models). Checks cover count/list contracts, pagination, refresh cancellation and retention, malformed responses, duplicate deletion suppression, count resynchronization, stale results, account changes, and opening offers outside the home-page results. Source structure, Arabic/English localization syntax and key parity, and whitespace checks pass. An isolated UI preview compiles, and an Arabic screenshot confirms the bell placement in the header. End-to-end tap verification was blocked by simulator control errors (`noWindowsAvailable` and service timeouts). Checks use local synthetic responses; no production notifications were deleted.

## 50. Notifications match the LOH application

Updated on **29 October 2026**, following the implementation in `/Users/haneen/Desktop/LOH/LOH/App/NotificationView/View/NotificationsView.swift` and its model/service files.

- The merchant inbox now follows the LOH screen's fixed All/Offers/Updates filter row, count beside the navigation title, red toolbar trash icon, compact white cards, and centered bell empty state. Cards use the same padding, spacing, corner radii, text sizes, and red per-item delete action, with the merchant app's existing font family. Informational notifications are plain content; actionable notifications make their content tappable without an extra View Offer label. The bell SVG and warm canvas color were copied from the local LOH asset catalog.
- Deletion shows the same centered progress overlay with list/filter actions disabled. The native confirmation dialog remains; mutation errors now use an alert, while count failures have a visible retry action and retain the last confirmed badge count. Paging uses a compact text action and loading spinner.
- The client application sends a `filter` query, but the supplied Vendor notification contract only documents page and page size. Merchant filters therefore classify the returned notification type/coupon association locally. Offers includes `coupon_notify` and notifications with a positive coupon ID; Updates includes the remaining types. Filtering and load-more continue through later pages until matching items appear or pagination ends, avoiding false empty states when matches occur beyond page one. Filter changes cancel older requests, and paging failures retain retry behavior. The vendor URLs, authentication, count, deletion, and coupon navigation remain connected.
- Filter, navigation-title, and empty-state components each have their own View folder; the filter type belongs in Model. No client application source files were modified.

Validation: the full Debug simulator build, notification state checks, Vendor/Auth contract checks, navigation checks, source structure, localization syntax/key parity, and whitespace checks pass. Added checks cover both filtered categories across multiple pages, skipped nonmatching pages, stale filter responses, filter-page failures/retries, and count error recovery. Arabic and English simulator previews verified the layout; actual taps switched the Offers/Updates filters, opened the deletion confirmation, and navigated from a clickable notification to an offer absent from the home-page cache. The notification load-more action has its own localized title. All requests in checks and previews use synthetic local data.

Follow-up on **29 October 2026**: removed the notification filter tabs at the user’s request. The screen displays all returned notifications with standard pagination. Removed the unused filter component/model, filtering state, strings, and filter-specific checks; the LOH card styling, badge, refresh, deletion, and offer navigation remain in place.


## 51. Merchant ticket conversation

Updated on **29 October 2026** using the supplied `vendor/support-tickets/51` response and `/Users/haneen/Downloads/NewLoh.postman_collection-2.json`.

- `MerchantTicketDetailView` now loads `GET vendor/support-tickets/{ticketID}` and displays the ticket reference, description, conversation history, and a keyboard-aware multiline reply composer. Messages use the outer `messages.data` page rather than duplicating the ticket's legacy description message (`id: 0`). The outer `can_reply` takes precedence over `ticket.can_user_reply`; a closed ticket always remains read-only. Missing or conflicting room IDs cannot enable sending.
- Replies use `POST vendor/send-message/{roomID}` with the multipart `message` field and the authenticated merchant token. Ticket 51 therefore sends to room 3. The acknowledged message uses the response's recipient-record ID to match history IDs. Successful sends clear only the submitted draft, preserve any newly typed text, and reload server permissions/history. Failed sends retain their draft and expose an error; the POST is never automatically retried. Empty and duplicate submissions are suppressed.
- Refresh requests are owned by the detail view model, retaining content and a loading indicator even if SwiftUI cancels the refresh gesture. Message pagination uses the same ticket route with a validated page query, deduplicates history, and retains retry behavior on failure. Screen exit/background cancellation and session checks reject stale results. Returning to the foreground reloads the conversation. Each screen/component has its own View folder; conversation models and state live in the detail feature's Model/ViewModel folders.
- The requested reference project (`/Users/haneen/Desktop/last-one-hour-last-version`) contains a REST complaint conversation in `suggestionVC.swift`, with `complaint_reply` / `complaint_closed` notification-triggered refresh, and no Socket.IO implementation. The merchant view observes those same local notification names and verifies the server state on refresh. The user subsequently asked to keep the existing configurations. Existing socket and Firebase settings remain unchanged; this feature uses HTTPS, whose effective port is **443**, and does not establish a new socket connection. The local notification hooks require an event producer; existing disabled push registration is not enabled by this change. Updates currently arrive through explicit refresh, foreground refresh, and post-send reconciliation.
- The latest collection already returns the room with ticket details; the UI does not call the older `start-chat` endpoint or the generic Chats collection with its undefined `baseUrl` variable.

Validation: the full Debug simulator build and support API, support-store, and ticket-chat checks pass. Checks use the supplied detail fixture and local transports to cover reply permissions, room selection, HTTPS port 443, sending, deduplication, pagination, failure/draft preservation, gesture cancellation, screen exit, and account isolation. Arabic simulator inspection confirms the conversation and composer layout. No production messages were sent.

## 52. Order-detail card borders

Updated on **29 October 2026**.

- Replaced the individual rectangular price/purchase-date borders with one pale, rounded metrics panel containing three equal-width columns and inset dividers. Metric text can wrap without fixed-height clipping. Order and customer cards use consistent padding and a very light shadow.
- Removed the customer name row's box border; customer information now uses one inset horizontal separator with comfortable row spacing. The changes are confined to the four order-card components.

Validation: the Debug simulator build, source-structure and whitespace checks pass. Isolated Arabic and English order previews verify the rounded metrics panel, column alignment, customer divider, and border treatment using local sample data.
