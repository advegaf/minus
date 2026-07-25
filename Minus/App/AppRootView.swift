import SwiftData
import SwiftUI

/// The onboarding gate: UserConfig.onboardedAt nil → OnboardingFlow replaces
/// everything; otherwise the Home stack.
struct AppRootView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var router = AppRouter()
    @Query private var configs: [UserConfig]

    private var isOnboarded: Bool {
        configs.first { $0.id == UserConfig.wellKnownID }?.onboardedAt != nil
    }

    var body: some View {
        ZStack {
            MN.obsidian.ignoresSafeArea()
            if isOnboarded {
                NavigationStack(path: Bindable(router).path) {
                    HomeView()
                        // Attached at the ROOT: the pop recognizer belongs to
                        // the navigation controller, so one instance restores
                        // edge-swipe back on every pushed screen. On Home the
                        // stack has one controller, so the gesture stays off
                        // and the card pager keeps the left edge.
                        .background(InteractivePopEnabler())
                        .navigationDestination(for: Route.self) { route in
                            destination(for: route)
                        }
                }
                .environment(router)
                .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(MMotion.signature, value: isOnboarded)
        .onChange(of: deps.pendingDeepLink) { _, _ in
            consumeFocusLink()
        }
        .onAppear {
            consumeFocusLink()
            #if DEBUG
            router.jumpFromEnvironment()
            #endif
        }
    }

    /// minus://focus lands here (this view owns the router). Mid-onboarding
    /// the link is cleared and dropped — the gate wins.
    private func consumeFocusLink() {
        guard case .focus = deps.pendingDeepLink else { return }
        guard isOnboarded else {
            deps.pendingDeepLink = nil
            return
        }
        deps.pendingDeepLink = nil
        router.path = [.focus]
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .focus:
            FocusView()
        case .awareness:
            AwarenessView()
        case .settings:
            SettingsView()
        case .schedules:
            ScheduleListView()
        case .scheduleEditor(let id):
            ScheduleEditorView(scheduleID: id)
        case .settingsIntention:
            IntentionEditView()
        case .settingsEssentials:
            CardsListView()
        case .settingsCard(let id):
            CardDetailView(cardID: id)
        case .settingsCustom(let cardID):
            CustomEntryView(cardID: cardID)
        case .settingsBlocked:
            BlockListEditView()
        case .settingsStrictness:
            StrictnessView()
        case .settingsPermission:
            PermissionSettingsView()
        case .settingsAbout:
            AboutView()
        case .settingsGuide:
            DumbPhoneGuideView()
        }
    }
}
