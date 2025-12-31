#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not in PATH. Install Flutter first, then re-run."
  exit 1
fi

# Create platform folders if missing (keeps lib/ and pubspec.yaml)
if [ ! -d "macos" ] || [ ! -d "ios" ] || [ ! -d "android" ]; then
  echo "Creating Flutter platform folders (macOS)..."
  tmpdir="$(mktemp -d)"
  # Create a temporary template project, then copy platform folders in
  flutter create --platforms=macos,ios,android "$tmpdir/mama_tmp" >/dev/null
  # Copy macOS (and minimal ios/android to satisfy tooling) into current dir if missing
  if [ ! -d "macos" ]; then cp -R "$tmpdir/mama_tmp/macos" ./; fi
  if [ ! -d "ios" ]; then cp -R "$tmpdir/mama_tmp/ios" ./; fi
  if [ ! -d "android" ]; then cp -R "$tmpdir/mama_tmp/android" ./; fi
  if [ ! -d "linux" ]; then :; fi
  if [ ! -d "web" ]; then :; fi
  if [ ! -d "windows" ]; then :; fi
  rm -rf "$tmpdir"
fi

echo "Fetching dependencies..."
flutter pub get

echo "All set ✅"
echo "Run: flutter run -d macos"
