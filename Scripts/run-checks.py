#!/usr/bin/env python3
"""Compile and run local model/network/session checks without calling the API."""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
APP = "LohProvider/"
NAVIGATION = [APP + "Coordinator/BaseCoordinator/ViewModel/BaseCoordinator.swift",
              APP + "Coordinator/MerchantCoordinator/ViewModel/MerchantNavigationCoordinator.swift",
              APP + "Coordinator/MerchantCoordinator/Model/MerchantNavigationModels.swift"]
LANGUAGE = [APP + "Shared/Localization/Language.swift"]
AUTH = [APP + "Networking/Merchant/MerchantAPIRequest.swift",
        APP + "Networking/Merchant/MerchantAPILogger.swift",
        APP + "App/Maintenance/ViewModel/MerchantMaintenanceViewModel.swift",
        APP + "Networking/Merchant/MerchantAPIClient.swift",
        APP + "Services/MerchantAuthService.swift",
        APP + "Session/MerchantTokenStore.swift",
        APP + "Session/MerchantProfileCache.swift",
        APP + "Session/MerchantSession.swift",
        APP + "App/MerchantLogin/ViewModel/MerchantLoginViewModel.swift",
        APP + "App/MerchantLogin/Model/MerchantCountry.swift"]
SETTLEMENT = [APP + "App/MerchantSettlements/Shared/Model/MerchantSettlement.swift"]
SUPPORT_CHAT = [APP + "App/MerchantSupport/Shared/Model/MerchantSupportModels.swift",
                APP + "App/MerchantSupport/TicketDetails/Model/MerchantTicketConversation.swift",
                APP + "App/MerchantSupport/TicketDetails/ViewModel/MerchantTicketDetailViewModel.swift"]
OFFERS = [APP + "Networking/Merchant/MerchantAPIRequest.swift",
          APP + "Networking/Merchant/MerchantAPILogger.swift",
          APP + "App/Maintenance/ViewModel/MerchantMaintenanceViewModel.swift",
          APP + "Networking/Merchant/MerchantAPIClient.swift",
          APP + "Services/MerchantOfferService.swift",
          APP + "App/MerchantOffers/OrderDetails/Model/MerchantOrderDetails.swift",
          APP + "App/MerchantOffers/OrderDetails/Model/MerchantOrderPresentation.swift",
          APP + "App/MerchantOffers/Shared/Model/MerchantOfferModels.swift",
          APP + "App/MerchantOffers/Shared/ViewModel/MerchantOfferStore.swift"]
REPORTS = [APP + "Networking/Merchant/MerchantAPIRequest.swift",
           APP + "Networking/Merchant/MerchantAPILogger.swift",
           APP + "App/Maintenance/ViewModel/MerchantMaintenanceViewModel.swift",
           APP + "Networking/Merchant/MerchantAPIClient.swift",
           APP + "Services/MerchantReportService.swift",
           APP + "App/MerchantReports/Shared/Model/MerchantReportModels.swift",
           APP + "App/MerchantReports/Shared/Model/MerchantReportPeriodModels.swift",
           APP + "App/MerchantReports/ReportDetails/Model/MerchantReportDetailPresentation.swift",
           APP + "App/MerchantReports/Shared/ViewModel/MerchantReportStore.swift"] + SETTLEMENT
CHECKS = {
    "AppLanguageChecks": LANGUAGE,
    "MerchantLanguageSelectionChecks": LANGUAGE + AUTH + [APP + "App/MerchantAccount/Language/ViewModel/MerchantLanguageSelection.swift"],
    "MerchantLoginValidationChecks": AUTH,
    "MerchantNavigationChecks": NAVIGATION,
    "MerchantNotificationChecks": [APP + "Networking/Merchant/MerchantAPIRequest.swift",
                                   APP + "Networking/Merchant/MerchantAPILogger.swift",
                                   APP + "App/Maintenance/ViewModel/MerchantMaintenanceViewModel.swift",
                                   APP + "Networking/Merchant/MerchantAPIClient.swift",
                                   APP + "Services/MerchantNotificationService.swift",
                                   APP + "App/MerchantNotifications/Notifications/Model/MerchantNotificationDeletion.swift",
                                   APP + "App/MerchantNotifications/Notifications/ViewModel/MerchantNotificationStore.swift"],
    "MerchantSettlementChecks": SETTLEMENT + NAVIGATION,
    "MerchantSettlementAPIChecks": [APP + "Networking/Merchant/MerchantAPIRequest.swift",
                                     APP + "Networking/Merchant/MerchantAPILogger.swift",
                                     APP + "App/Maintenance/ViewModel/MerchantMaintenanceViewModel.swift",
                                     APP + "Networking/Merchant/MerchantAPIClient.swift",
                                     APP + "Services/MerchantSettlementService.swift",
                                     APP + "App/MerchantSettlements/Shared/ViewModel/MerchantSettlementStore.swift"] + SETTLEMENT,
    "MerchantSupportChecks": AUTH + [APP + "Services/MerchantSupportService.swift",
                                     APP + "App/MerchantSupport/Shared/ViewModel/MerchantSupportStore.swift"] + SUPPORT_CHAT + NAVIGATION,
    "MerchantTicketChatChecks": AUTH + [APP + "Services/MerchantSupportService.swift"] + SUPPORT_CHAT,
    "MerchantOfferChecks": OFFERS,
    "MerchantOfferAPIChecks": OFFERS,
    "MerchantCouponFulfillmentChecks": OFFERS,
    "MerchantReportChecks": REPORTS,
    "MerchantReportAPIChecks": REPORTS,
    "MerchantReportExportChecks": REPORTS + [APP + "App/MerchantReports/ReportExport/ViewModel/MerchantReportExportViewModel.swift"],
    "MerchantReportChartChecks": REPORTS + [APP + "App/MerchantReports/Reports/Components/ReportSummaryContent/Model/MerchantReportOverview.swift",
                                            APP + "App/MerchantReports/Reports/Components/SalesChart/Model/MerchantSalesChartScale.swift",
                                            APP + "App/MerchantReports/Reports/Components/SalesChart/ViewModel/MerchantSalesChartViewModel.swift"],
    "MerchantAPIAndSessionChecks": AUTH,
    "MerchantMaintenanceChecks": AUTH,
    "MerchantVendorAuthChecks": AUTH + [APP + "Services/MerchantNotificationService.swift"],
    "MerchantSupportAPIChecks": AUTH + [APP + "Services/MerchantSupportService.swift"],
    "MerchantAPILoggingChecks": [APP + "Networking/Merchant/MerchantAPIRequest.swift",
                                 APP + "App/Maintenance/ViewModel/MerchantMaintenanceViewModel.swift",
                                 APP + "Networking/Merchant/MerchantAPIClient.swift",
                                 APP + "Networking/Merchant/MerchantAPILogger.swift"],
}


def main():
    subprocess.run([sys.executable, str(ROOT / "Scripts/check-structure.py")], cwd=ROOT, check=True)
    with tempfile.TemporaryDirectory(prefix="loh-checks-") as directory:
        build = Path(directory)
        for name, sources in CHECKS.items():
            print(f"Checking {name}", flush=True)
            subprocess.run(["xcrun", "swiftc", "-swift-version", "5", "-DDEBUG", "-module-cache-path", str(build / "modules"),
                            *sources, f"Tests/{name}.swift", "-o", str(build / name)], cwd=ROOT, check=True)
            subprocess.run([str(build / name)], cwd=ROOT, check=True)
        name = "MerchantAPILoggingChecks"
        print("Checking API logging with DEBUG disabled", flush=True)
        subprocess.run(["xcrun", "swiftc", "-swift-version", "5", "-module-cache-path", str(build / "modules"),
                        *CHECKS[name], f"Tests/{name}.swift", "-o", str(build / "release-logging")], cwd=ROOT, check=True)
        subprocess.run([str(build / "release-logging")], cwd=ROOT, check=True)
    print(f"Passed all {len(CHECKS)} check programs.")


if __name__ == "__main__":
    main()
