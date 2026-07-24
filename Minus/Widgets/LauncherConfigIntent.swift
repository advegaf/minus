import AppIntents
import Foundation

/// Per-instance text size (D-B). Cases are rendering-agnostic — the point
/// matrix lives with the layout in MinusWidgetViews.Spec.
enum LauncherTextSize: String, AppEnum {
    case small
    case medium
    case large

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Text size"
    static let caseDisplayRepresentations: [LauncherTextSize: DisplayRepresentation] = [
        .small: "small",
        .medium: "medium",
        .large: "large",
    ]
}

/// Per-instance placement (D-B): where the name stack sits horizontally.
enum LauncherCellAlignment: String, AppEnum {
    case leading
    case center

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Placement"
    static let caseDisplayRepresentations: [LauncherCellAlignment: DisplayRepresentation] = [
        .leading: "left",
        .center: "centered",
    ]
}

/// Long-press → Edit Widget. Defaults reproduce v1.5's rendering exactly, so
/// a widget placed before 1.6 looks identical after the upgrade (the same-kind
/// StaticConfiguration→AppIntentConfiguration swap's safety net).
struct LauncherConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "launcher"
    static let description = IntentDescription("choose the card, text size, and placement.")

    @Parameter(title: "Card")
    var card: CardEntity?

    @Parameter(title: "Text size", default: .medium)
    var textSize: LauncherTextSize

    @Parameter(title: "Placement", default: .leading)
    var alignment: LauncherCellAlignment

    init() {}
}
