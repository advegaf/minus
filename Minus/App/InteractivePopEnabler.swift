import SwiftUI
import UIKit

/// Restores the edge-swipe back gesture that `.toolbar(.hidden, for:
/// .navigationBar)` suppresses. Every pushed screen in minus hides the bar
/// (the BackGlyph is the designed chrome), and UIKit disables the interactive
/// pop recognizer whenever it cannot find a back button to mirror.
///
/// The recognizer belongs to the UINavigationController, not to any one
/// screen, so this is attached ONCE at the stack's root and covers every push.
struct InteractivePopEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        ProxyController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        /// Only pop when there is something to pop back to, and never mid
        /// transition: starting a swipe during a push desyncs the stack from
        /// AppRouter.path.
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let nav = navigationController else { return false }
            return nav.viewControllers.count > 1 && nav.transitionCoordinator == nil
        }
    }

    /// A zero-size, non-interactive controller whose only job is to reach the
    /// navigation controller once it exists in the hierarchy.
    private final class ProxyController: UIViewController {
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("unavailable") }

        override func loadView() {
            let view = UIView(frame: .zero)
            view.isUserInteractionEnabled = false
            self.view = view
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // navigationController is nil until the hierarchy settles; this is
            // idempotent, so running it on every appearance is fine.
            guard let nav = navigationController,
                  let gesture = nav.interactivePopGestureRecognizer else { return }
            coordinator.navigationController = nav
            gesture.delegate = coordinator
            gesture.isEnabled = true
        }
    }
}
