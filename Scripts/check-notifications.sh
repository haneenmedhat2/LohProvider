#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
notifications_checks_dir=$(mktemp -d /tmp/loh-notifications-checks.XXXXXX)
trap 'rm -rf "$notifications_checks_dir"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$notifications_checks_dir/modules" \
    LohProvider/Networking/BaseResponse/APIEnvelope.swift \
    LohProvider/Networking/Endpoints/NotificationEndpoints.swift \
    LohProvider/App/Notifications/Shared/Model/NotificationModels.swift \
    LohProvider/App/Notifications/Notifications/Model/NotificationDeletion.swift \
    LohProvider/App/Notifications/Notifications/ViewModel/NotificationsViewModel.swift \
    Tests/MerchantNotificationChecks.swift -o "$notifications_checks_dir/checks"
"$notifications_checks_dir/checks"
