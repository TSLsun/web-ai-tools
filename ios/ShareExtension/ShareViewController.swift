import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    private var host: UIHostingController<ShareRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let rootView = ShareRootView(extensionContext: extensionContext)
        let hostVC = UIHostingController(rootView: rootView)
        host = hostVC
        addChild(hostVC)
        view.addSubview(hostVC.view)
        hostVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostVC.didMove(toParent: self)
    }
}
