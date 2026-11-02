import ManagedSettings
import ManagedSettingsUI
import UIKit

final class IgnitionShieldConfiguration: ShieldConfigurationDataSource {
    private var viewConfig: ShieldConfiguration {
        // Shield configuration can be requested even if the activity monitor's
        // end callback has not run. Never knowingly show an expired lock.
        if let activeLease = SharedConfiguration.lease, activeLease.expiresAt <= Date() {
            ManagedSettingsStore(named: ManagedSettingsStore.Name(IgnitionConfig.shieldStore)).clearAllSettings()
            SharedConfiguration.lease = nil
        }
        let lease = SharedConfiguration.lease
        let primaryTitle: String
        #if IGNITION_ENABLE_DIRECT_SHIELD_RETURN
        if #available(iOS 26.5, *) { primaryTitle = "Back to Ignition" }
        else { primaryTitle = "Close distracting app" }
        #else
        primaryTitle = "Close distracting app"
        #endif
        let minutes = lease.map { max(0,Int($0.expiresAt.timeIntervalSinceNow / 60)) } ?? 0
        return ShieldConfiguration(
            backgroundBlurStyle:.systemThinMaterialDark,
            backgroundColor:UIColor(red:0.12,green:0.22,blue:0.43,alpha:1),
            icon:UIImage(systemName:"bolt.shield.fill"),
            title:ShieldConfiguration.Label(text:"Focus on your work",color:.white),
            subtitle:ShieldConfiguration.Label(text:"\(minutes) min left. Your focus session is running.",color:.white),
            primaryButtonLabel:ShieldConfiguration.Label(text:primaryTitle,color:.white),
            primaryButtonBackgroundColor:UIColor(red:0.22,green:0.43,blue:0.89,alpha:1),
            secondaryButtonLabel:ShieldConfiguration.Label(text:"Close",color:.white)
        )
    }
    override func configuration(shielding application: Application) -> ShieldConfiguration { viewConfig }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { viewConfig }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { viewConfig }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { viewConfig }
}
