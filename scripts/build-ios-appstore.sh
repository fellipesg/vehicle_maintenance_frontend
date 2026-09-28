#!/usr/bin/env bash
set -euo pipefail

# Archive + IPA for App Store Connect. Requires Xcode signed into the Apple ID
# that owns team A2RY932NK7 and an App Store app for br.com.revisalog.app.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_BASE_URL="${API_BASE_URL:-https://revisalog.com.br/api/v1}"

flutter pub get
flutter build ipa --release \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  --export-options-plist=ios/ExportOptions.plist

echo
echo "IPA: $ROOT/build/ios/ipa/"
ls -lh build/ios/ipa/*.ipa 2>/dev/null || true
echo
echo "Next: open Transporter or Xcode Organizer and upload the IPA."
