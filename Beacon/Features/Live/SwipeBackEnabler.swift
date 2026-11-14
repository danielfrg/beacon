import SwiftUI

/// Hiding the navigation bar also disables UIKit's edge-swipe-back gesture; this turns it back on.
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Holder { Holder() }
    func updateUIViewController(_ controller: Holder, context: Context) {}

    final class Holder: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
