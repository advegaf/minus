import SwiftData
import SwiftUI
import UIKit

/// The launcher: the few apps that survived. Left-aligned bodyLg rows, hairline
/// ash rules between them only. A row the device can't open is dimmed, marked
/// "not installed", and made non-interactive — present but plainly inert.
struct EssentialAppList: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(filter: #Predicate<EssentialApp> { $0.isEnabled },
           sort: \EssentialApp.sortOrder, order: .forward)
    private var apps: [EssentialApp]

    /// Flips exactly once, on first appearance, to drive the staggered reveal.
    /// It never resets, so data-driven re-renders don't re-stagger.
    @State private var appeared = false

    var body: some View {
        Group {
            if apps.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(apps.enumerated()), id: \.element.slug) { index, app in
                        if index > 0 {
                            Rectangle()
                                .fill(MN.ashBorder)
                                .frame(height: MN.hairline)
                        }
                        AppRow(app: app, openURL: openURL)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: (appeared || reduceMotion) ? 0 : 6)
                            .animation(rowAnimation(index: index), value: appeared)
                    }
                }
            }
        }
        .onAppear { appeared = true }
    }

    /// Staggered rise on first paint; reduce-motion degrades to a single
    /// no-offset crossfade with no per-item delay.
    private func rowAnimation(index: Int) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.2)
        }
        return MMotion.micro.delay(Double(index) * MMotion.staggerStep)
    }

    private var emptyState: some View {
        Button {
            router.push(.settings)
        } label: {
            Text("nothing here yet — choose essentials in settings")
                .mnType(.body)
                .foregroundStyle(MN.fogBlue)
                .frame(maxWidth: 300, minHeight: MN.minHit, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.mnPress)
        .accessibilityIdentifier("essentials-empty")
    }
}

/// One launcher row. Installed → a bone-white button that opens the app.
/// Uninstalled → a disabled, fog-dimmed row with a "not installed" suffix.
private struct AppRow: View {
    let app: EssentialApp
    let openURL: OpenURLAction

    var body: some View {
        // canOpenURL is main-actor isolated; body is the main-actor context.
        let url = URL(string: app.urlScheme)
        let isInstalled = url.map { UIApplication.shared.canOpenURL($0) } ?? false

        return Button {
            if let url { openURL(url) }
        } label: {
            HStack(spacing: MN.Space.xs) {
                Text(app.displayName.lowercased())
                    .mnType(.bodyLg)
                    .foregroundStyle(isInstalled ? MN.boneWhite : MN.fogBlue)
                if !isInstalled {
                    Text("not installed")
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: MN.minHit, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.mnPress)
        .disabled(!isInstalled)
        .opacity(isInstalled ? 1 : 0.4)
        .accessibilityIdentifier("row-app-\(app.slug)")
    }
}

#if DEBUG
#Preview {
    ZStack {
        MN.obsidian.ignoresSafeArea()
        EssentialAppList()
            .padding(MN.Space.m)
    }
    .preferredColorScheme(.dark)
}
#endif
