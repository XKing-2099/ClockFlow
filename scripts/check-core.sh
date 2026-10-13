#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_compiler="${HANDSCAPE_SWIFTC:-$(xcrun --find swiftc)}"
task_sdk="${HANDSCAPE_MACOS_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
mkdir -p "$task_root/.build/checks"

"$task_compiler" -swift-version 5 -sdk "$task_sdk" \
    "$task_root/Handscape/Core/ClockDigits.swift" \
    "$task_root/Handscape/Core/ClockBoardLayout.swift" \
    "$task_root/Handscape/Core/Choreography.swift" \
    "$task_root/Handscape/Models/ClockSettings.swift" \
    "$task_root/Tests/CoreChecks.swift" \
    -o "$task_root/.build/checks/core-checks"

"$task_root/.build/checks/core-checks"

