import DeviceActivity
import Foundation
import ManagedSettings

/// OS-scheduled unshield backstop. Actual callbacks are controlled by iOS,
/// often at the first device use after the interval ends.
final class IgnitionDeviceMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(IgnitionConfig.shieldStore))

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for:activity)
        guard let lease = SharedConfiguration.lease,
              lease.monitorName == activity.rawValue else { return }
        // A currently active lease supersedes an old monitor callback.
        guard lease.expiresAt <= Date().addingTimeInterval(2) else { return }
        store.clearAllSettings()
        SharedConfiguration.lease = nil
    }
}
