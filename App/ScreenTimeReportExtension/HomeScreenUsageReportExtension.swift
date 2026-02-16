import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct HomeScreenUsageReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        UsageSummaryReport { configuration in
            UsageSummaryView(configuration: configuration)
        }
    }
}
