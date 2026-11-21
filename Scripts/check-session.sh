#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
session_checks_dir=$(mktemp -d /tmp/loh-session-checks.XXXXXX)
trap 'rm -rf "$session_checks_dir"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$session_checks_dir/modules" \
    LohProvider/Shared/Foundation/Names.swift \
    LohProvider/App/Login/Model/AuthModels.swift \
    LohProvider/Coordinator/MerchantCoordinator/ViewModel/MerchantAppCoordinator.swift \
    LohProvider/App/More/Profile/ViewModel/ProfileViewModel.swift \
    LohProvider/App/More/Account/ViewModel/AccountViewModel.swift \
    Tests/CoordinatorSessionChecks.swift -o "$session_checks_dir/checks"
"$session_checks_dir/checks"
