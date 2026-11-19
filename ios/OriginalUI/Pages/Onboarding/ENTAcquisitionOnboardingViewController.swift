import SnapKit
import UIKit

/// Reuses the existing login design with local prototype interactions.
@MainActor
final class ENTAcquisitionOnboardingViewController: UIViewController {
    private let onFinish: (Bool) -> Void
    private var activePage: UIViewController?

    override var childForStatusBarStyle: UIViewController? { activePage }

    init(onFinish: @escaping (Bool) -> Void) {
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ENTAppColors.pageBackground
        showPhoneLogin()
    }

    private func showPhoneLogin() {
        let login = LoginViewController(
            allowsCancellation: false,
            prototypeCompletion: { [weak self] in self?.showDouyinLogin() },
            onLoginSucceeded: { _ in }
        )
        show(login)
    }

    private func showDouyinLogin() {
        view.endEditing(true)
        let connection = ENTDouyinConnectionModel()
        connection.beginLogin()
        show(ENTDouyinLoginViewController(
            onCompleted: { [weak self] in
                guard let self else { return }
                connection.completePlatformLogin()
                connection.checkConnection()
                guard case .confirming = connection.phase, connection.confirm() else { return }
                self.onFinish(true)
            },
            onCancelled: { [weak self] in self?.onFinish(false) }
        ))
    }

    private func show(_ page: UIViewController) {
        activePage?.willMove(toParent: nil)
        activePage?.view.removeFromSuperview()
        activePage?.removeFromParent()
        addChild(page)
        view += [page.view]
        page.view.snp.makeConstraints { $0.edges.equalToSuperview() }
        page.didMove(toParent: self)
        activePage = page
        setNeedsStatusBarAppearanceUpdate()
    }
}
