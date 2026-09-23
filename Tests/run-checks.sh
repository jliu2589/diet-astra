#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/astra-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc Diet-Astra/Core/Records.swift Diet-Astra/Core/ProgressMath.swift Tests/ProgressChecks.swift -o "$check_dir/progress"
"$check_dir/progress"
xcrun swiftc Diet-Astra/Core/Records.swift Diet-Astra/Prototype/DemoDiary.swift Diet-Astra/Prototype/TrendSummary.swift Tests/DemoDiaryChecks.swift -o "$check_dir/diary"
"$check_dir/diary"
xcrun swiftc Diet-Astra/WeightEntry.swift Diet-Astra/WeightStore.swift Tests/WeightStoreChecks.swift -o "$check_dir/storage"
"$check_dir/storage"
node Tests/NutritionChecks.mjs
