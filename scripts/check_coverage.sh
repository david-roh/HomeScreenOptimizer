#!/usr/bin/env bash
set -euo pipefail

MIN_COVERAGE="${1:-80}"
REPORT_PATH=".build/debug/codecov/HomeScreenOptimizer.json"

if [[ ! -f "${REPORT_PATH}" ]]; then
  echo "Coverage report not found at ${REPORT_PATH}"
  echo "Run: swift test --enable-code-coverage"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for coverage checking."
  exit 1
fi

LINE_COVERAGE="$(jq -r '.data[0].totals.lines.percent' "${REPORT_PATH}")"
REGION_COVERAGE="$(jq -r '.data[0].totals.regions.percent' "${REPORT_PATH}")"

echo "Line coverage: ${LINE_COVERAGE}%"
echo "Region coverage: ${REGION_COVERAGE}%"
echo "Minimum required line coverage: ${MIN_COVERAGE}%"

awk -v current="${LINE_COVERAGE}" -v required="${MIN_COVERAGE}" 'BEGIN { exit((current + 0 >= required + 0) ? 0 : 1) }'

echo "Coverage gate passed."
