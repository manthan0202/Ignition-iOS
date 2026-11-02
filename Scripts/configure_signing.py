#!/usr/bin/env python3
"""Optional full-build identifier setup for an Apple Developer account.

Usage from the Ignition project folder:
  python3 Scripts/configure_signing.py com.yourcompany.ignition YOURTEAMID

Requires an Apple Developer team with Family Controls entitlement for the
full app and its Screen Time extensions. Preview mode needs neither.
"""
import re
import sys
from pathlib import Path

if len(sys.argv) not in (2, 3):
    raise SystemExit("Usage: python3 Scripts/configure_signing.py com.yourcompany.ignition [TEAMID]")
base = sys.argv[1]
if not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+){2,}', base):
    raise SystemExit("Use a reverse-domain bundle ID such as com.yourcompany.ignition")
team = sys.argv[2] if len(sys.argv) == 3 else None
if team and not re.fullmatch(r'[A-Za-z0-9]{10}', team):
    raise SystemExit('TEAMID must be the 10-character Apple Developer Team ID')
root=Path(__file__).resolve().parents[1]
files=[root/'Ignition.xcodeproj'/'project.pbxproj', root/'Sources'/'Shared'/'SharedConfiguration.swift',
       *root.glob('Sources/**/*.entitlements')]
# Match the prior bundle ID, so this script can be rerun on a new checkout.
for p in files:
    t=p.read_text()
    if 'com.example.ignition' not in t and base not in t:
        print(f'Skipped {p.name}: placeholder not found')
        continue
    t=t.replace('com.example.ignition',base)
    if team and p.name=='project.pbxproj':
        t=re.sub(r'(CODE_SIGN_STYLE\s*=\s*"Automatic";)',r'\1\n\t\t\t\tDEVELOPMENT_TEAM = "'+team+'";',t)
    p.write_text(t)
    print(f'Configured {p.relative_to(root)}')
print('Remember: Apple must approve/configure the App Group and Family Controls capabilities in your Developer account.')
