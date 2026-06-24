//
//  View+UIKitNavigationTitle.swift
//  DanaKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit

extension View {
    /// Sets the navigation bar title (and large-title display mode) for a SwiftUI screen that is
    /// hosted inside a UIKit `UINavigationController` — as all of DanaKit's onboarding and settings
    /// screens are, via `DanaUICoordinator` — whether the screen was pushed by the coordinator or
    /// via a SwiftUI `NavigationLink`.
    ///
    /// Needed because on iOS 26 SwiftUI's `.navigationTitle` / `.navigationBarTitle` no longer
    /// bridges to a parent UIKit navigation controller, so those titles render blank. This helper
    /// keeps the SwiftUI modifiers (for earlier iOS) and additionally sets `navigationItem.title`
    /// directly on the hosting view controller.
    func uikitNavigationTitle(
        _ title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .automatic
    ) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .background(NavigationItemTitleSetter(title: title, largeTitleDisplayMode: displayMode.uiKitLargeTitleDisplayMode))
    }
}

private extension NavigationBarItem.TitleDisplayMode {
    var uiKitLargeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
        switch self {
        case .inline: return .never
        case .large: return .always
        case .automatic: return .automatic
        @unknown default: return .automatic
        }
    }
}

/// Sets `navigationItem.title` and `largeTitleDisplayMode` on the enclosing navigation
/// controller's top view controller. See `View.uikitNavigationTitle(_:displayMode:)`.
private struct NavigationItemTitleSetter: UIViewControllerRepresentable {
    let title: String
    let largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode

    func makeUIViewController(context: Context) -> TitleProxyViewController {
        TitleProxyViewController(title: title, largeTitleDisplayMode: largeTitleDisplayMode)
    }

    func updateUIViewController(_ uiViewController: TitleProxyViewController, context: Context) {
        uiViewController.proxyTitle = title
        uiViewController.largeTitleDisplayMode = largeTitleDisplayMode
    }

    final class TitleProxyViewController: UIViewController {
        var proxyTitle: String {
            didSet { applyTitle() }
        }

        var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode {
            didSet { applyTitle() }
        }

        init(title: String, largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode) {
            self.proxyTitle = title
            self.largeTitleDisplayMode = largeTitleDisplayMode
            super.init(nibName: nil, bundle: nil)
            view.isHidden = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            applyTitle()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyTitle()
        }

        private func applyTitle() {
            // The hosted SwiftUI screen is the navigation controller's top view controller;
            // set the title and display mode the navigation bar actually uses.
            guard let host = navigationController?.topViewController else { return }
            host.navigationItem.title = proxyTitle
            host.navigationItem.largeTitleDisplayMode = largeTitleDisplayMode
        }
    }
}
