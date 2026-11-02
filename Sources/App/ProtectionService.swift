import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

enum ProtectionStatus: Equatable {
    case off, ready, active, unavailable(String)
    var title: String {
        switch self {
        case .off: return "Timer only · Protection off"
        case .ready: return "Protection ready"
        case .active: return "Protection applied"
        case .unavailable(let detail): return "Protection unavailable · \(detail)"
        }
    }
}

#if IGNITION_PREVIEW
/// Safe, unsigned simulator/preview implementation. Never applies OS shields.
@MainActor
final class ProtectionService: ObservableObject {
    @Published var selection: FamilyActivitySelection = FamilyActivitySelection()
    @Published private(set) var status: ProtectionStatus = .off
    func checkReady() { status = .off }
    func authorize() async -> Bool {
        status = .unavailable("Full signed build required")
        return false
    }
    @discardableResult
    func activate(sessionID: UUID, duration: TimeInterval, now: Date = Date()) -> ProtectionStatus {
        status = .off
        return status
    }
    func deactivate() { status = .off }
    func reconcile(session: FocusSession?) { status = .off }
}
#else

/// Owns only Ignition's named ManagedSettings store.
/// Apple's extension callbacks are asynchronous: this is not a hard real-time guarantee.
@MainActor
final class ProtectionService: ObservableObject {
    @Published var selection: FamilyActivitySelection = SharedConfiguration.selection {
        didSet { SharedConfiguration.selection = selection; checkReady() }
    }
    @Published private(set) var status: ProtectionStatus = .off
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(IgnitionConfig.shieldStore))
    private let center = DeviceActivityCenter()
    // Apple's DeviceActivityCenter rejects schedules shorter than 15 minutes.
    // We do NOT use a backdated schedule to fake short-session protection.
    private let minimumSafeMonitorDuration: TimeInterval = 16 * 60
    private var hasAppliedShield: Bool {
        store.shield.applications != nil ||
        store.shield.applicationCategories != nil ||
        store.shield.webDomains != nil
    }

    init() { checkReady() }
    private var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }
    func checkReady() {
        guard SharedConfiguration.groupAvailable else {
            status = .unavailable("App Group not configured")
            return
        }
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            status = .off
            return
        }
        status = selectedCount > 0 ? .ready : .off
        if selectedCount > 0, let lease = SharedConfiguration.lease,
           lease.expiresAt > Date(), hasAppliedShield {
            status = .active
        }
    }
    func authorize() async -> Bool {
        guard SharedConfiguration.groupAvailable else {
            status = .unavailable("App Group not configured")
            return false
        }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            checkReady()
            return AuthorizationCenter.shared.authorizationStatus == .approved
        } catch {
            status = .unavailable("Permission denied")
            return false
        }
    }
    func activate(sessionID: UUID, duration: TimeInterval, now: Date = Date()) -> ProtectionStatus {
        // Stop old protection/monitors before rescheduling, including Resume/Break.
        // Failure to register a release schedule MUST fail open (timer-only).
        deactivate()
        guard SharedConfiguration.groupAvailable else {
            status = .unavailable("App Group not configured")
            return status
        }
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            status = .off; return status
        }
        guard selectedCount > 0 else { status = .off; return status }
        // Critical safety rule: do not apply a shield without a supported
        // auto-release backstop. A two-minute session stays timer-only.
        guard duration >= minimumSafeMonitorDuration else {
            status = .unavailable("Under 16 min · timer only (safe release)")
            return status
        }
        let safeDuration = min(6 * 3600, duration)
        let end = now.addingTimeInterval(safeDuration)
        let monitoringStart = now
        let name = DeviceActivityName("ignition-\(UUID().uuidString)")
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = [.year,.month,.day,.hour,.minute,.second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: monitoringStart),
            intervalEnd: calendar.dateComponents(components, from: end),
            repeats: false
        )
        do {
            try center.startMonitoring(name, during: schedule)
            SharedConfiguration.lease = ProtectionLease(sessionID: sessionID, monitorName: name.rawValue, expiresAt: end)
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
            status = .active
        } catch {
            store.clearAllSettings()
            SharedConfiguration.lease = nil
            center.stopMonitoring([name])
            status = .unavailable("Safe release could not be scheduled")
        }
        return status
    }
    func deactivate() {
        // Clear BEFORE stopping monitoring; no old monitor can outlive a lease.
        store.clearAllSettings()
        let names = center.activities.filter { $0.rawValue.hasPrefix("ignition-") }
        if !names.isEmpty { center.stopMonitoring(names) }
        SharedConfiguration.lease = nil
        checkReady()
    }
    func reconcile(session: FocusSession?) {
        guard let lease = SharedConfiguration.lease else {
            // Protect against orphaned settings, but DO NOT advertise Ready
            // while a timer-only session is running.
            store.clearAllSettings()
            let stale = center.activities.filter { $0.rawValue.hasPrefix("ignition-") }
            if !stale.isEmpty { center.stopMonitoring(stale) }
            if let session, session.phase != .ended {
                if case .unavailable = status { /* Preserve useful warning. */ }
                else { status = .off }
            } else { checkReady() }
            return
        }
        guard AuthorizationCenter.shared.authorizationStatus == .approved,
              SharedConfiguration.groupAvailable,
              selectedCount > 0,
              lease.expiresAt > Date(),
              let session,
              session.id == lease.sessionID,
              session.phase == .active || session.phase == .onBreak else {
            deactivate()
            return
        }
        status = hasAppliedShield ? .active : .unavailable("Shield was removed by iOS")
    }
}

#endif // IGNITION_PREVIEW
