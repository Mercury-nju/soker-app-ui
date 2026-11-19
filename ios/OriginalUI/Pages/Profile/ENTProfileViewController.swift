import SnapKit
import UIKit

@MainActor
final class ENTProfileViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ENTAppColors.pageBackground
        navigationItem.title = "我的"
        if navigationController?.presentingViewController != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeAccount)
            )
        }

        let mark = UIImageView(image: UIImage(named: "SokerWebsiteMark")?.withRenderingMode(.alwaysTemplate))
        mark.tintColor = ENTAppColors.primaryText
        mark.contentMode = .scaleAspectFit

        let name = UILabel()
        name.text = "Soker"
        name.font = .semibold(ofSize: 24)
        name.textColor = ENTAppColors.primaryText
        name.textAlignment = .center

        let accountButton = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "抖音账号"
        configuration.image = UIImage(systemName: "person.crop.circle")
        configuration.imagePadding = 10
        configuration.baseForegroundColor = ENTAppColors.primaryText
        configuration.baseBackgroundColor = ENTAppColors.cardBackground
        configuration.cornerStyle = .large
        accountButton.configuration = configuration
        accountButton.accessibilityIdentifier = "profile_douyin_account_button"
        accountButton.addTarget(self, action: #selector(openDouyinAccount), for: .touchUpInside)

        view.addSubview(mark)
        view.addSubview(name)
        view.addSubview(accountButton)
        mark.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(32)
            make.centerX.equalToSuperview()
            make.size.equalTo(CGSize(width: 62, height: 38))
        }
        name.snp.makeConstraints { make in
            make.top.equalTo(mark.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
        }
        accountButton.snp.makeConstraints { make in
            make.top.equalTo(name.snp.bottom).offset(30)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.height.greaterThanOrEqualTo(54)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    @objc private func closeAccount() {
        dismiss(animated: true)
    }

    @objc private func openDouyinAccount() {
        Self.presentDouyinAccount(from: self)
    }

    static func presentDouyinAccount(from presenter: UIViewController) {
        let page = ENTDouyinLoginViewController(
            onCompleted: { [weak presenter] in
                guard let presenter else { return }
                presenter.dismiss(animated: true) {
                    let success = ENTDouyinAuthorizationSuccessViewController { [weak presenter] in
                        presenter?.dismiss(animated: true)
                    }
                    presenter.present(success, animated: true)
                }
            },
            onCancelled: { [weak presenter] in presenter?.dismiss(animated: true) }
        )
        page.modalPresentationStyle = .fullScreen
        presenter.present(page, animated: true)
    }
}
