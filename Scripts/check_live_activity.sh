#!/usr/bin/env bash
# Run Codable migration and parity checks without Apple's proprietary SDK.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
python3 - "$tmp" <<'PY'
from pathlib import Path
import sys
out=Path(sys.argv[1])
file=Path('Sources/Shared/LiveAttributes.swift').read_text().replace('import ActivityKit\n','')
(out/'LiveAttr.swift').write_text('import Foundation\nprotocol ActivityAttributes { associatedtype ContentState: Codable, Hashable }\n'+file)
a=Path('Sources/Widgets/IgnitionWidgets.swift').read_text()
b=Path('Sources/Widgets/PreviewLiveWidget.swift').read_text()
marker='// Shared visual language in the two independently signed widget extensions.'
assert marker in a and marker in b, 'Missing common presentation'
assert a[a.index(marker):] == b[b.index(marker):], 'Live Activity widget UIs have diverged'
for identifier in ('LiveTimeProgress','LiveTaskRow','LiveExpandedBottom','LiveActivityLockCard'):
 assert identifier in a and identifier in b, identifier
assert 'live.sync(session: self.session, tasks: self.liveTasks(for: self.session))' in Path('Sources/App/AppModel.swift').read_text()
print('PASS: full & preview use identical Live Activity UI; completion sends updated tasks')
PY
swiftc "$tmp/LiveAttr.swift" Tests/LiveActivityContentCompatibilityTests.swift -o "$tmp/liveattr-test"
"$tmp/liveattr-test"
