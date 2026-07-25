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
// module, but they CAN compile the design system's own sources: v1.8 shares
// Tokens.swift + Typography.swift and registers General Sans through this
// target's UIAppFonts, so Apple's numbers are drawn in the app's typeface
// instead of falling back to the system face.
struct DailyOverviewView: View {
    let summary: DailySummary

    nonisolated init(summary: DailySummary) {
        self.summary = summary
    }

    private var durationText: String {
        let minutes = Int(summary.totalDuration) / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MN.obsidian

            HStack(alignment: .top, spacing: MN.Space.l) {
                stat("SCREEN TIME", durationText)
                stat("PICKUPS", "\(summary.pickups)")
            }
            .padding(.vertical, MN.Space.xs)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: MN.Space.xxs) {
            Text(label)
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
            Text(value)
                .mnType(.headingLg)
                .foregroundStyle(MN.boneWhite)
        }
    }
}
