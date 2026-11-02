import ManagedSettings
import FamilyControls
import Foundation

final class IgnitionShieldAction: ShieldActionDelegate {
    private func respond(_ action: ShieldAction, completion: @escaping (ShieldActionResponse) -> Void) {
        // Last-chance safe release: if monitoring was delayed, allow the next
        // attempted app access to clear an already-expired Ignition lease.
        // This is best-effort, not a guarantee of instantaneous release.
        if let lease = SharedConfiguration.lease, lease.expiresAt <= Date() {
            ManagedSettingsStore(named: ManagedSettingsStore.Name(IgnitionConfig.shieldStore)).clearAllSettings()
            SharedConfiguration.lease = nil
            completion(.close) // A fresh launch of the app is then unshielded.
            return
        }
        switch action {
        case .primaryButtonPressed:
            // The title promises a handoff only on iOS versions that support it.
            // Opt-in only after building against an SDK that exposes the new
            // response and confirming it on a real device. Default always compiles.
            #if IGNITION_ENABLE_DIRECT_SHIELD_RETURN
            if #available(iOS 26.5, *) { completion(.openParentalControlsApp) }
            else { completion(.close) }
            #else
            completion(.close)
            #endif
        default:
            completion(.close)
        }
    }
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action,completion:completionHandler)
    }
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action,completion:completionHandler)
    }
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action,completion:completionHandler)
    }
}
