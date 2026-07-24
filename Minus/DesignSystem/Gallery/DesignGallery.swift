import SwiftUI

#if DEBUG

/// A DEBUG-only proof sheet for the entire design system: every color, type
/// token, spacing step, component, and the prism, laid on the obsidian void.
/// Launched via `MINUS_SCREEN=gallery`. Set `MINUS_GALLERY_SCROLL` to a section
/// id (colors/type/spacing/components/prism) to open scrolled to it.
struct DesignGallery: View {
    @State private var fieldEmpty = ""
    @State private var fieldFilled = "Morning ritual"

    private let swatches: [(name: String, hex: String, color: Color)] = [
        ("Obsidian", "#101010", MN.obsidian),
        ("Graphite Veil", "#495764", MN.graphiteVeil),
        ("Bone White", "#FFFDF9", MN.boneWhite),
        ("Fog Blue", "#6F879C", MN.fogBlue),
        ("Ash Border", "#403F3F", MN.ashBorder),
    ]

    private let typeRows: [(label: String, token: MNType, sample: String)] = [
        ("Display SM · 64", .displaySm, "41"),
        ("Heading LG · 40", .headingLg, "Focus mode"),
        ("Heading · 28 · bold", .heading, "Awareness"),
        ("Body XL · 28 · regular", .bodyXl, "phone \u{00B7} widget large"),
        ("Body · 17", .body, "The quiet architecture of attention."),
        ("Caption · 13", .caption, "Session · 24 min"),
    ]

    private let spaceRows: [(label: String, value: CGFloat)] = [
        ("xxs · 4", MN.Space.xxs),
        ("xs · 8", MN.Space.xs),
        ("s · 16", MN.Space.s),
        ("m · 20", MN.Space.m),
        ("l · 40", MN.Space.l),
        ("xl · 56", MN.Space.xl),
        ("xxl · 64", MN.Space.xxl),
        ("section · 72", MN.Space.section),
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: MN.Space.section) {
                    colorsSection.id("colors")
                    typeSection.id("type")
                    spacingSection.id("spacing")
                    componentsSection.id("components")
                    widgetsSection.id("widgets")
                    prismSection.id("prism")
                }
                .padding(.horizontal, MN.Space.m)
                .padding(.vertical, MN.Space.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(MN.obsidian.ignoresSafeArea())
            .accessibilityIdentifier("design-gallery")
            .onAppear {
                if let anchor = ProcessInfo.processInfo.environment["MINUS_GALLERY_SCROLL"] {
                    proxy.scrollTo(anchor, anchor: .top)
                }
            }
        }
    }

    // MARK: Colors

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: MN.Space.s) {
            eyebrow("Colors")
            ForEach(swatches, id: \.name) { swatch in
                HStack(spacing: MN.Space.s) {
                    RoundedRectangle(cornerRadius: MN.Radius.nav, style: .continuous)
                        .fill(swatch.color)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: MN.Radius.nav, style: .continuous)
                                .stroke(MN.ashBorder, lineWidth: MN.hairline)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(swatch.name)
                            .mnType(.body)
                            .foregroundStyle(MN.boneWhite)
                        Text(swatch.hex)
                            .mnType(.caption)
                            .foregroundStyle(MN.fogBlue)
                    }
                }
            }
        }
    }

    // MARK: Type scale

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: MN.Space.l) {
            eyebrow("Type Scale")

            // Display at 1.0 leading via the stacked device.
            VStack(alignment: .leading, spacing: MN.Space.xxs) {
                Text("Display · 96 · 1.0 leading")
                    .mnType(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(MN.fogBlue)
                DisplayStack(lines: ["09", "41"], token: .display)
                    .foregroundStyle(MN.boneWhite)
            }

            ForEach(typeRows, id: \.label) { row in
                VStack(alignment: .leading, spacing: MN.Space.xxs) {
                    Text(row.label)
                        .mnType(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(MN.fogBlue)
                    Text(row.sample)
                        .mnType(row.token)
                        .foregroundStyle(MN.boneWhite)
                }
            }
        }
    }

    // MARK: Spacing

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: MN.Space.s) {
            eyebrow("Spacing")
            ForEach(spaceRows, id: \.label) { row in
                HStack(spacing: MN.Space.s) {
                    Text(row.label)
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                        .frame(width: 96, alignment: .leading)
                    Rectangle()
                        .fill(MN.boneWhite)
                        .frame(width: row.value, height: 6)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: Components

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: MN.Space.l) {
            eyebrow("Components")

            VStack(alignment: .leading, spacing: MN.Space.m) {
                OutlinedCTA(title: "Begin Focus") {}
                OutlinedCTA(title: "Start Session", prominent: true) {}
            }

            HairlineCard {
                VStack(alignment: .leading, spacing: MN.Space.xs) {
                    Text("Hairline card")
                        .mnType(.body)
                        .foregroundStyle(MN.boneWhite)
                    Text("Obsidian surface — depth from contrast, never shadow.")
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                }
            }

            HairlineCard(surface: .graphiteVeil) {
                VStack(alignment: .leading, spacing: MN.Space.xs) {
                    Text("Graphite veil")
                        .mnType(.body)
                        .foregroundStyle(MN.boneWhite)
                    Text("The one lighter surface.")
                        .mnType(.caption)
                        .foregroundStyle(MN.fogBlue)
                }
            }

            NavTextRow(items: [
                ("Focus", {}),
                ("Awareness", {}),
                ("Settings", {}),
            ])

            HStack(spacing: MN.Space.xs) {
                PillTag("24 min")
                PillTag("Streak 14")
                PillTag("Awareness")
            }

            VStack(alignment: .leading, spacing: MN.Space.l) {
                FieldShell(placeholder: "Ritual name", text: $fieldEmpty, accessibilityID: "field-empty")
                FieldShell(placeholder: "Ritual name", text: $fieldFilled, accessibilityID: "field-filled")
            }
        }
    }

    // MARK: Widgets (the screenshot surface — WidgetKit can't be UI-automated)

    private var widgetsSection: some View {
        VStack(alignment: .leading, spacing: MN.Space.s) {
            eyebrow("Widgets")

            // v1.6 matrix: two sizes (D-D) × text size × placement (D-B).
            widgetFrame(width: 364, height: 382, id: "widget-preview-launcher-large") {
                LauncherWidgetView(snapshot: .fixture, layout: .column)
            }
            widgetFrame(width: 364, height: 382, id: "widget-preview-launcher-large-small") {
                LauncherWidgetView(snapshot: .fixture, layout: .column, textSize: .small)
            }
            widgetFrame(width: 364, height: 382, id: "widget-preview-launcher-large-xl") {
                LauncherWidgetView(snapshot: .fixture, layout: .column, textSize: .large)
            }
            // iOS 27 full home-screen page (systemExtraLargePortrait).
            widgetFrame(width: 364, height: 680, id: "widget-preview-launcher-page") {
                LauncherWidgetView(snapshot: .fixture, layout: .page)
            }
            widgetFrame(width: 364, height: 680, id: "widget-preview-launcher-page-center") {
                LauncherWidgetView(snapshot: .fixture, layout: .page, alignment: .center)
            }
            widgetFrame(width: 364, height: 680, id: "widget-preview-launcher-page-xl") {
                LauncherWidgetView(snapshot: .fixture, layout: .page, textSize: .large)
            }
            // Density-audit worst cases: 7 rows at .large — the type steps
            // down a notch and spacing tightens; nothing may clip.
            widgetFrame(width: 364, height: 382, id: "widget-preview-launcher-large-xl-dense") {
                LauncherWidgetView(snapshot: .fixtureSeven, layout: .column, textSize: .large)
            }
            widgetFrame(width: 364, height: 680, id: "widget-preview-launcher-page-xl-dense") {
                LauncherWidgetView(snapshot: .fixtureSeven, layout: .page, textSize: .large)
            }

            HStack(alignment: .top, spacing: MN.Space.s) {
                widgetFrame(width: 170, height: 170, id: "widget-preview-focus-active") {
                    FocusWidgetView(snapshot: focusFixture(activeMinutes: 25), now: fixtureNow)
                }
                widgetFrame(width: 170, height: 170, id: "widget-preview-focus-next") {
                    FocusWidgetView(snapshot: focusFixture(next: "next \u{00B7} deep work \u{00B7} mon 9:00"), now: fixtureNow)
                }
            }
            HStack(alignment: .top, spacing: MN.Space.s) {
                widgetFrame(width: 170, height: 170, id: "widget-preview-focus-idle") {
                    FocusWidgetView(snapshot: .fixture, now: fixtureNow)
                }
                widgetFrame(width: 170, height: 170, id: "widget-preview-focus-empty") {
                    FocusWidgetView(snapshot: nil, now: fixtureNow)
                }
            }
        }
    }

    private var fixtureNow: Date { Date(timeIntervalSince1970: 1_772_000_000) }

    private func focusFixture(activeMinutes: Int? = nil, next: String? = nil) -> LauncherSnapshot {
        var snapshot = LauncherSnapshot.fixture
        snapshot.focus = LauncherSnapshot.FocusState(
            activeUntil: activeMinutes.map { fixtureNow.addingTimeInterval(TimeInterval($0 * 60)) },
            nextSchedule: next
        )
        return snapshot
    }

    private func widgetFrame(width: CGFloat, height: CGFloat, id: String, @ViewBuilder content: () -> some View) -> some View {
        content()
            // Previews are inert: cells are live intent Buttons that would
            // otherwise open apps when tapped inside the gallery.
            .allowsHitTesting(false)
            .padding(MN.Space.s)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(MN.obsidian)
            .clipShape(RoundedRectangle(cornerRadius: MN.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: MN.Radius.card)
                    .strokeBorder(MN.ashBorder, lineWidth: MN.hairline)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(id)
            // Scroll-targetable: MINUS_GALLERY_SCROLL accepts frame ids too.
            .id(id)
    }

    // MARK: Prism

    private var prismSection: some View {
        VStack(alignment: .leading, spacing: MN.Space.m) {
            eyebrow("Prism")
            HStack {
                Spacer(minLength: 0)
                PrismArtifact(size: 240)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Eyebrow

    private func eyebrow(_ title: String) -> some View {
        Text(title)
            .mnType(.caption)
            .textCase(.uppercase)
            .foregroundStyle(MN.fogBlue)
    }
}

#Preview {
    DesignGallery()
        .preferredColorScheme(.dark)
}

#endif
