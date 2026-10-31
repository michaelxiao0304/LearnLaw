#!/bin/bash
# Run from any directory. Supply an already available simulator UUID.
set -euo pipefail
IOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${LAWSENSE_SIMULATOR_ID:?Set LAWSENSE_SIMULATOR_ID to the test simulator UUID}"
cd "$IOS_ROOT"
CONTENT_PYTHON="${LAWSENSE_CONTENT_PYTHON:-$IOS_ROOT/../.venv-content/bin/python}"
if [ ! -x "$CONTENT_PYTHON" ]; then
  echo "Set up .venv-content using tools/content/README.md before verification." >&2
  exit 1
fi
export PYTHONDONTWRITEBYTECODE=1
"$CONTENT_PYTHON" -m unittest discover -s ../tools/content/tests -v
"$CONTENT_PYTHON" ../tools/content/make_test_fixture.py --check
python3 Scripts/generate_project.py
swift test --enable-code-coverage
plutil -lint LawSense/PrivacyInfo.xcprivacy
xcodebuild test -project LawSense.xcodeproj -scheme LawSenseDevelopment \
  -destination "platform=iOS Simulator,id=$LAWSENSE_SIMULATOR_ID" \
  -derivedDataPath DerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES
xcodebuild build -project LawSense.xcodeproj -scheme LawSense -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO
python3 Scripts/verify_privacy.py DerivedData/Build/Products/Debug-iphonesimulator/LawSense.app
python3 Scripts/verify_privacy.py DerivedData/Build/Products/Debug-iphonesimulator/LawSenseDevelopment.app
