import SwiftUI

enum MerchantTab: String, CaseIterable, Identifiable {
    case offers, reports, settlements, account
    var id: String { rawValue }
    var titleKey: String { "tab_\(rawValue)" }
    var assetName: String {
        switch self {
        case .offers: return "LOHTabOffers"
        case .reports: return "LOHTabReports"
        case .settlements: return "LOHTabSettlements"
        case .account: return "LOHTabAccount"
        }
    }
}

/// Routes carry the identifiers supplied by each feature.
enum MerchantRoute: Hashable {
    case notifications
    case offerDetails(String)
    case orderDetails(String)
    case reportDetails
    case settlementDetails(String)
    case profile
    case language
    case support
    case createTicket
    case supportSent(String)
    case ticketDetails(String)

    var titleKey: String {
        switch self {
        case .notifications: return "nav_notifications"
        case .offerDetails: return "nav_offer_details"
        case .orderDetails: return "nav_order_details"
        case .reportDetails: return "nav_report_details"
        case .settlementDetails: return "nav_settlement_details"
        case .profile: return "nav_profile"
        case .language: return "nav_language"
        case .support: return "nav_support"
        case .createTicket: return "nav_create_ticket"
        case .supportSent: return "support_sent_title"
        case .ticketDetails: return "nav_ticket_details"
        }
    }
}

enum MerchantSheet: String, Identifiable {
    case orderCode, offersOrderCode, scanner, reportPeriod, reportExport
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .orderCode: return "nav_order_code"
        case .offersOrderCode: return "offers_enter_code"
        case .scanner: return "nav_scan_barcode"
        case .reportPeriod: return "nav_report_period"
        case .reportExport: return "nav_report_export"
        }
    }
}

enum MerchantDialog: String, Identifiable {
    case logout
    var id: String { rawValue }
}

