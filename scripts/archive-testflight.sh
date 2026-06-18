#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/YouTubeAudioSearch.xcodeproj"
ARCHIVE="$ROOT_DIR/build/YouTubeAudioSearch.xcarchive"
EXPORT_DIR="$ROOT_DIR/build/YouTubeAudioSearchExport"
EXPORT_OPTIONS="$ROOT_DIR/ExportOptions.plist"
KEY_PATH="${APP_STORE_CONNECT_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_Y3JLHLYZD5.p8}"
KEY_ID="${APP_STORE_CONNECT_KEY_ID:-Y3JLHLYZD5}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-e570c4cf-e394-458c-8cbd-1c2cba6a400f}"

rm -rf "$ARCHIVE" "$EXPORT_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "YouTubeAudioSearch" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  archive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

