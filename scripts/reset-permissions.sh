#!/usr/bin/env bash
set -euo pipefail

BUNDLE_IDS=(
  "com.chasecargill.RightClickFocus"
  "local.codex.RightClickFocus"
)

for bundle_id in "${BUNDLE_IDS[@]}"; do
  echo "Resetting Accessibility for $bundle_id"
  tccutil reset Accessibility "$bundle_id" >/dev/null 2>&1 || true

  echo "Resetting Input Monitoring for $bundle_id"
  tccutil reset ListenEvent "$bundle_id" >/dev/null 2>&1 || true
done

echo "Done. Reopen RightClickFocus and grant Accessibility and Input Monitoring again."
