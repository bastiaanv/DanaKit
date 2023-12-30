//
//  UIAlertController.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 30/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

import SwiftUI

extension View {
    public func alert(isPresented: Binding<Bool>, _ alert: AlertConfigTwoInputs) -> some View {
        AlertHelper(isPresented: isPresented, alert: alert, content: self)
    }
}

extension UIAlertController {
    convenience init(alert: AlertConfigTwoInputs) {
        self.init(title: alert.title, message: alert.message, preferredStyle: .alert)
        addTextField { $0.placeholder = alert.placeholder1 }
        addTextField { $0.placeholder = alert.placeholder2 }
        addAction(UIAlertAction(title: alert.cancel, style: .cancel) { _ in
            alert.action(nil, nil)
        })
        let textField1 = self.textFields?[0]
        let textField2 = self.textFields?[1]
        addAction(UIAlertAction(title: alert.accept, style: .default) { _ in
            alert.action(textField1?.text, textField2?.text)
        })
    }
}

struct AlertHelper<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let alert: AlertConfigTwoInputs
    let content: Content
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<AlertHelper>) -> UIHostingController<Content> {
        UIHostingController(rootView: content)
    }
    
    final class Coordinator {
        var alertController: UIAlertController?
        init(_ controller: UIAlertController? = nil) {
            self.alertController = controller
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: UIViewControllerRepresentableContext<AlertHelper>) {
        uiViewController.rootView = content
        if isPresented && uiViewController.presentedViewController == nil {
            var alert = self.alert
            alert.action = {
                self.isPresented = false
                self.alert.action($0, $1)
            }
            context.coordinator.alertController = UIAlertController(alert: alert)
            uiViewController.present(context.coordinator.alertController!, animated: true)
        }
        if !isPresented && uiViewController.presentedViewController == context.coordinator.alertController {
            uiViewController.dismiss(animated: true)
        }
    }
}

public struct AlertConfigTwoInputs {
    public var title: String
    public var message: String?
    public var placeholder1: String = ""
    public var placeholder2: String = ""
    public var accept: String = "OK"
    public var cancel: String = "Cancel"
    public var action: (String?, String?) -> ()
}
