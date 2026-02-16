import Ingestion
import SwiftUI

struct UsageSummaryView: View {
    let configuration: UsageSummaryConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Activity")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(configuration.totalActivityText)
                .font(.headline)

            if configuration.entries.isEmpty {
                Text("No app activity found for selected filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(configuration.entries.prefix(8).enumerated()), id: \.offset) { _, entry in
                    HStack {
                        Text(entry.appName)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(entry.minutesPerDay)) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
    }
}
