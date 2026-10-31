#!/usr/bin/env python3
"""Check the built resource, not just the source manifest."""
import plistlib
import sys
from pathlib import Path

bundle = Path(sys.argv[1])
with (bundle / 'PrivacyInfo.xcprivacy').open('rb') as stream:
    manifest = plistlib.load(stream)
assert manifest['NSPrivacyTracking'] is False
assert manifest['NSPrivacyTrackingDomains'] == []
assert manifest['NSPrivacyCollectedDataTypes'] == []
assert manifest['NSPrivacyAccessedAPITypes'] == [{
    'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults',
    'NSPrivacyAccessedAPITypeReasons': ['CA92.1'],
}]
print('Privacy manifest verified:', bundle.name)
