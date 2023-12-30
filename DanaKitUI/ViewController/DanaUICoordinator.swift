//
//  DanaUICoordinator.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 18/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import LoopKit
import LoopKitUI

enum DanaUIScreen {
    case debugView
    case firstRunScreen
    case deviceScanning
    
    func next() -> DanaUIScreen? {
        switch self {
        case .debugView:
            return .firstRunScreen
        case .firstRunScreen:
            return .deviceScanning
        case .deviceScanning:
            return nil
        }
    }
}

protocol DanaUINavigator: AnyObject {
    func navigateTo(_ screen: DanaUIScreen)
}

class DanaUICoordinator: UINavigationController, PumpManagerOnboarding, CompletionNotifying, UINavigationControllerDelegate {
    var pumpManagerOnboardingDelegate: PumpManagerOnboardingDelegate?
    
    var completionDelegate: CompletionDelegate?
    
    var screenStack = [DanaUIScreen]()
    var currentScreen: DanaUIScreen {
        return screenStack.last!
    }
    
    private let colorPalette: LoopUIColorPalette

    private var pumpManager: DanaKitPumpManager?
    
    private var allowedInsulinTypes: [InsulinType]
    
    private var allowDebugFeatures: Bool
    
    init(pumpManager: DanaKitPumpManager? = nil, colorPalette: LoopUIColorPalette, pumpManagerSettings: PumpManagerSetupSettings? = nil, allowDebugFeatures: Bool, allowedInsulinTypes: [InsulinType] = [])
    {
        if pumpManager == nil {
            self.pumpManager = DanaKitPumpManager(state: DanaKitPumpManagerState(rawValue: [:]))
        } else {
            self.pumpManager = pumpManager
        }
        
        self.colorPalette = colorPalette

        self.allowDebugFeatures = allowDebugFeatures
        
        self.allowedInsulinTypes = allowedInsulinTypes
        
        super.init(navigationBarClass: UINavigationBar.self, toolbarClass: UIToolbar.self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if screenStack.isEmpty {
            screenStack = [.firstRunScreen]
            let viewController = viewControllerForScreen(currentScreen)
            viewController.isModalInPresentation = false
            setViewControllers([viewController], animated: false)
        }
    }
    
    private func hostingController<Content: View>(rootView: Content) -> DismissibleHostingController {
        return DismissibleHostingController(rootView: rootView, colorPalette: colorPalette)
    }
    
    private func viewControllerForScreen(_ screen: DanaUIScreen) -> UIViewController {
        switch(screen) {
        case .debugView:
            let view = DanaKitDebugView(viewModel: DanaKitDebugViewModel(self.pumpManager))
            return hostingController(rootView: view)
        case .firstRunScreen:
            let view = DanaKitSetupView(nextAction: { self.stepFinished() }, debugAction: { self.navigateTo(.debugView) }) //self.allowDebugFeatures ? { self.navigateTo(.debugView) } : {})
            return hostingController(rootView: view)
        case .deviceScanning:
            let view = DanaKitScanView(viewModel: DanaKitScanViewModel(self.pumpManager, nextStep: {}))
            return hostingController(rootView: view)
        }
    }
    
    func stepFinished() {
        if let nextStep = currentScreen.next() {
            navigateTo(nextStep)
        } else {
            completionDelegate?.completionNotifyingDidComplete(self)
        }
    }
}

extension DanaUICoordinator: DanaUINavigator {
    func navigateTo(_ screen: DanaUIScreen) {
        screenStack.append(screen)
        let viewController = viewControllerForScreen(screen)
        viewController.isModalInPresentation = false
        self.pushViewController(viewController, animated: true)
        viewController.view.layoutSubviews()
    }
}
