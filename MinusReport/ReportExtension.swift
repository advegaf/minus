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
        }
        return summary
    }
}

// Report extensions render in a sandboxed process and cannot import the app
// module — this view keeps its own copies of the canvas/text colors.
struct DailyOverviewView: View {
    let summary: DailySummary

    // DeviceActivityReportScene.content is a nonisolated requirement, but View
    // types are MainActor-isolated — a nonisolated init lets the scene's
    // content closure construct this view from any isolation domain.
    nonisolated init(summary: DailySummary) {
        self.summary = summary
    }

    var body: some View {
        ZStack {
            Color(red: 16 / 255, green: 16 / 255, blue: 16 / 255)
            Text(summary.totalDuration.formatted())
                .foregroundStyle(Color(red: 255 / 255, green: 253 / 255, blue: 249 / 255))
        }
    }
}
