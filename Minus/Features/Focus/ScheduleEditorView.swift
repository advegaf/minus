import SwiftData
import SwiftUI

/// Create or edit one recurring window. Validation is live and quiet (fog
/// captions, never red); SAVE registers through the coordinator so a saved
/// schedule is always a registered schedule.
struct ScheduleEditorView: View {
    var scheduleID: UUID?

    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss
    @Query private var schedules: [FocusSchedule]

    @State private var name = ""
    @State private var weekdays: Set<Int> = []
    @State private var startMinute = 9 * 60
    @State private var endMinute = 10 * 60
    @State private var loaded = false
    @State private var saveError: String?
    @State private var confirmingDelete = false

    /// Monday-first display order; values are Calendar.weekday (1 = Sunday).
    private static let dayOrder: [(value: Int, label: String)] = [
        (2, "m"), (3, "t"), (4, "w"), (5, "t"), (6, "f"), (7, "s"), (1, "s"),
    ]

    private var existing: FocusSchedule? {
        guard let scheduleID else { return nil }
        return schedules.first { $0.id == scheduleID }
    }

    private var validationText: String? {
        if weekdays.isEmpty { return "pick at least one day" }
        if endMinute <= startMinute { return "end must come after start" }
        if endMinute - startMinute < ScheduleMath.minimumWindowMinutes { return "at least 15 minutes" }
        let others = schedules.filter { $0.id != scheduleID && $0.isEnabled }
        for other in others where ScheduleMath.overlaps(
            (weekdays: Array(weekdays), start: startMinute, end: endMinute),
            (weekdays: other.weekdays, start: other.startMinuteOfDay, end: other.endMinuteOfDay)
        ) {
            return "overlaps \(other.name.isEmpty ? "another schedule" : other.name.lowercased())"
        }
        return nil
    }

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(existing == nil ? "NEW SCHEDULE" : "EDIT SCHEDULE")
                        .mnType(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(MN.fogBlue)
                        .padding(.top, MN.Space.s)
                        .padding(.leading, MN.Space.xl)

                    FieldShell(placeholder: "name (optional)", text: $name, accessibilityID: "field-schedule-name")
                        .padding(.top, MN.Space.l)

                    Text("DAYS")
                        .mnType(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(MN.fogBlue)
                        .padding(.top, MN.Space.l)
                    dayPicker
                        .padding(.top, MN.Space.s)

                    timeRow(label: "STARTS", minute: $startMinute, id: "picker-start")
                        .padding(.top, MN.Space.l)
                    timeRow(label: "ENDS", minute: $endMinute, id: "picker-end")
                        .padding(.top, MN.Space.m)

                    if let validationText {
                        Text(validationText)
                            .mnType(.caption)
                            .foregroundStyle(MN.fogBlue)
                            .padding(.top, MN.Space.m)
                            .accessibilityIdentifier("editor-validation")
                    }
                    if let saveError {
                        Text(saveError)
                            .mnType(.caption)
                            .foregroundStyle(MN.fogBlue)
                            .padding(.top, MN.Space.xs)
                            .accessibilityIdentifier("editor-save-error")
                    }

                    OutlinedCTA(title: "Save", prominent: true) { save() }
                        .disabled(validationText != nil)
                        .opacity(validationText == nil ? 1 : 0.35)
                        .accessibilityIdentifier("cta-save-schedule")
                        .padding(.top, MN.Space.l)

                    if existing != nil {
                        GhostCaptionButton(title: "Delete schedule", accessibilityID: "cta-delete-schedule") {
                            confirmingDelete = true
                        }
                        .padding(.top, MN.Space.xs)
                    }
                }
                .padding(.horizontal, MN.Space.m)
                .padding(.bottom, MN.Space.l)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { BackGlyph() }
        .confirmationDialog("Delete this schedule?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteExisting() }
        }
        .onAppear(perform: load)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("schedule-editor")
    }

    private var dayPicker: some View {
        HStack(spacing: MN.Space.xs) {
            ForEach(Array(Self.dayOrder.enumerated()), id: \.offset) { _, day in
                let selected = weekdays.contains(day.value)
                Button {
                    if selected { weekdays.remove(day.value) } else { weekdays.insert(day.value) }
                } label: {
                    Text(day.label)
                        .mnType(.bodyLg)
                        .foregroundStyle(selected ? MN.boneWhite : MN.fogBlue)
                        .frame(width: MN.minHit, height: MN.minHit)
                        .overlay(
                            RoundedRectangle(cornerRadius: MN.Radius.nav)
                                .strokeBorder(selected ? MN.boneWhite : MN.ashBorder, lineWidth: MN.hairline)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.mnPress)
                .animation(MMotion.micro, value: selected)
                .accessibilityIdentifier("day-\(day.value)")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }

    private func timeRow(label: String, minute: Binding<Int>, id: String) -> some View {
        HStack {
            Text(label)
                .mnType(.caption)
                .textCase(.uppercase)
                .foregroundStyle(MN.fogBlue)
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: { Self.date(fromMinute: minute.wrappedValue) },
                    set: { minute.wrappedValue = Self.minuteOfDay(from: $0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .tint(MN.boneWhite)
            .colorScheme(.dark)
            .accessibilityIdentifier(id)
        }
        .frame(minHeight: MN.minHit)
    }

    // MARK: Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let existing else { return }
        name = existing.name
        weekdays = Set(existing.weekdays)
        startMinute = existing.startMinuteOfDay
        endMinute = existing.endMinuteOfDay
    }

    private func save() {
        saveError = nil
        let blockList = (try? deps.context.fetch(FetchDescriptor<BlockList>(predicate: #Predicate { $0.isDefault })))?.first

        let schedule: FocusSchedule
        if let existing {
            // Re-registration is a clean swap: tear down the old expansion first.
            deps.coordinator.unregister(schedule: existing)
            existing.name = name
            existing.weekdays = Array(weekdays).sorted()
            existing.startMinuteOfDay = startMinute
            existing.endMinuteOfDay = endMinute
            schedule = existing
        } else {
            schedule = FocusSchedule(
                name: name,
                weekdays: Array(weekdays).sorted(),
                startMinuteOfDay: startMinute,
                endMinuteOfDay: endMinute
            )
            deps.context.insert(schedule)
        }

        if let blockList, blockList.selectionData != nil {
            do {
                try deps.coordinator.register(schedule: schedule, blockList: blockList)
                schedule.isEnabled = true
            } catch {
                schedule.isEnabled = false
                saveError = "saved, but not enabled — schedule limit reached"
            }
        } else {
            schedule.isEnabled = false
            saveError = "saved off — choose blocked apps to enable"
        }

        try? deps.context.save()
        if saveError == nil { dismiss() }
    }

    private func deleteExisting() {
        guard let existing else { return }
        deps.coordinator.unregister(schedule: existing)
        deps.context.delete(existing)
        try? deps.context.save()
        dismiss()
    }

    // MARK: Time plumbing

    static func date(fromMinute minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()
        ) ?? Date()
    }

    static func minuteOfDay(from date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
    }
}
