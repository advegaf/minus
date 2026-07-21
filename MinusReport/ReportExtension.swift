import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    static let dailyOverview = Self("Daily Overview")
}

@main
struct MinusReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DailyOverviewScene()
    }
}

struct DailySummary: Sendable {
    var totalDuration: TimeInterval = 0
    var pickups: Int = 0
}

// Isolation split in the SDK: AppExtensionScene (the parent protocol) is
// @MainActor, which would isolate this whole struct by inference — but
// DeviceActivityReportScene's own requirements (context/content/
// makeConfiguration) and DeviceActivityReportExtension.body are nonisolated.
// Holding no stored state and marking every witness nonisolated satisfies
// both sides without @preconcurrency.
struct DailyOverviewScene: DeviceActivityReportScene {
    nonisolated init() {}

    nonisolated var context: DeviceActivityReport.Context { .dailyOverview }

    nonisolated var content: (DailySummary) -> DailyOverviewView {
        // Explicit `return` suppresses the @ViewBuilder transform the protocol
        // requirement would otherwise apply to this getter (SE-0289).
        return { DailyOverviewView(summary: $0) }
    }

    nonisolated func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> DailySummary {
        var summary = DailySummary()
        for await segment in data.flatMap({ $0.activitySegments }) {
            summary.totalDuration += segment.totalActivityDuration
            for await category in segment.categories {
                for await application in category.applications {
                    summary.pickups += application.numberOfPickups
                }
            }
        }
        return summary
    }
}

// Report extensions render in a sandboxed process and cannot import the app
// module — this view keeps its own copies of the canvas/text tokens and the
// General Sans names (fonts registered via the extension's own UIAppFonts is
// unnecessary: the system fallback here stays visually quiet at caption size).
struct DailyOverviewView: View {
    let summary: DailySummary

    nonisolated init(summary: DailySummary) {
        self.summary = summary
    }

    private var boneWhite: Color { Color(red: 255 / 255, green: 253 / 255, blue: 249 / 255) }
    private var fogBlue: Color { Color(red: 111 / 255, green: 135 / 255, blue: 156 / 255) }

    private var durationText: String {
        let minutes = Int(summary.totalDuration) / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 16 / 255, green: 16 / 255, blue: 16 / 255)

            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SCREEN TIME")
                        .font(.system(size: 13))
                        .kerning(0.26)
                        .foregroundStyle(fogBlue)
                    Text(durationText)
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(boneWhite)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("PICKUPS")
                        .font(.system(size: 13))
                        .kerning(0.26)
                        .foregroundStyle(fogBlue)
                    Text("\(summary.pickups)")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(boneWhite)
                }
            }
            .padding(.vertical, 8)
        }
    }
}
