# Release audit — Plan refinements

## Code audit

Baseline is the latest working Now refinement (Oct 31). One app file was changed: `PlanView.swift`. No shared domain/session services, Widgets, Live Attributes, Focus screen, Journey assets, or signing configuration were altered.

## Source invariants

- Task IDs and block memberships stored by the existing `WorkRepository` remain unchanged.
- A task in multiple blocks is not duplicated. End of focus does not mark tasks complete.
- Appointments are read from a separate `timedEvents` collection; imported read-only events do not appear as task checklist rows.
- Plan continues to refresh calendar data while open and supports manual refresh.
- Both native task drag/drop and the accessible tap-to-schedule sheet are reachable.
- Focus block move, resize and Edit menu fallback remain intact.
- Short calendar blocks hide extra text/resize handles when there is insufficient height; edit/context menu provides an alternative.
- Read-only imported events do not receive native drag affordance.
- No new permissions, third-party SDKs or accounts are required by the new Plan UI.

## Known restrictions

- No Xcode/iOS SDK available in this runtime to typecheck UIKit/SwiftUI, render the screen, measure frame rate, or validate OAuth.
- Screen Time shielding requires the full entitlement-based target and a physical device.
- Calendar sync can be near-real-time during foreground use but **not guaranteed every 60 seconds in the background**.
- Existing landscape art is unchanged and some source image blur remains.
