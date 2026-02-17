import DeviceActivity
import ExtensionKit
import Foundation
import Ingestion
import SwiftUI

extension DeviceActivityReport.Context {
    static let hsoUsageSummary = Self("HSO Usage Summary")
}

struct UsageSummaryConfiguration {
    var totalActivityText: String
    var entries: [ScreenTimeUsageEntry]
}

@preconcurrency
struct UsageSummaryReport: @MainActor DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .hsoUsageSummary
    let content: (UsageSummaryConfiguration) -> UsageSummaryView

    nonisolated func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> UsageSummaryConfiguration {
        var minuteByCanonicalName: [String: Double] = [:]
        var displayNameByCanonicalName: [String: String] = [:]

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                for await categoryActivity in segment.categories {
                    for await applicationActivity in categoryActivity.applications {
                        let displayName = (applicationActivity.application.localizedDisplayName ?? applicationActivity.application.bundleIdentifier ?? "Unknown")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !displayName.isEmpty else {
                            continue
                        }

                        let canonical = displayName
                            .lowercased()
                            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !canonical.isEmpty else {
                            continue
                        }

                        let minutes = applicationActivity.totalActivityDuration / 60
                        minuteByCanonicalName[canonical, default: 0] += minutes
                        if displayNameByCanonicalName[canonical] == nil {
                            displayNameByCanonicalName[canonical] = displayName
                        }
                    }
                }
            }
        }

        let entries = minuteByCanonicalName
            .map { canonical, minutes in
                ScreenTimeUsageEntry(
                    appName: displayNameByCanonicalName[canonical] ?? canonical,
                    minutesPerDay: minutes,
                    confidence: 1.0
                )
            }
            .sorted { lhs, rhs in
                if abs(lhs.minutesPerDay - rhs.minutesPerDay) > 0.0001 {
                    return lhs.minutesPerDay > rhs.minutesPerDay
                }
                return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
            }

        Self.persist(entries: entries)

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll

        let totalSeconds = entries.reduce(0) { partial, entry in
            partial + (entry.minutesPerDay * 60)
        }
        let totalActivityText = formatter.string(from: totalSeconds) ?? "No activity data"

        return UsageSummaryConfiguration(totalActivityText: totalActivityText, entries: entries)
    }

    private nonisolated static func persist(entries: [ScreenTimeUsageEntry]) {
        guard let defaults = UserDefaults(suiteName: SharedScreenTimeBridge.appGroupID) else {
            return
        }

        guard let encoded = try? JSONEncoder().encode(entries) else {
            return
        }

        defaults.set(encoded, forKey: SharedScreenTimeBridge.entriesDefaultsKey)
        defaults.set(Date(), forKey: SharedScreenTimeBridge.updatedAtDefaultsKey)
    }
}

private enum SharedScreenTimeBridge {
    static let appGroupID = "group.com.davidroh.hso"
    static let entriesDefaultsKey = "native_screen_time_usage_entries"
    static let updatedAtDefaultsKey = "native_screen_time_usage_updated_at"
}
