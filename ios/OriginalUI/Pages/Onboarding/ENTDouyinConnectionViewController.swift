import Combine
import SnapKit
import UIKit

@MainActor
final class ENTDouyinConnectionViewController: UIViewController {
    // MARK: - Private Properties

    private let onFinish: (() -> Void)?
    private let model = ENTDouyinConnectionModel()
    private var cancellables = Set<AnyCancellable>()
    private var hasFinished = false

    // MARK: - Lifecycle

    init(onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
        isModalInPresentation = true
        navigationItem.hidesBackButton = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        model.$phase
            .sink { [weak self] phase in self?.render(phase) }
            .store(in: &cancellables)
    }

    // MARK: - UI Components

    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsVerticalScrollIndicator = false
        return view
    }()

    private lazy var contentView = UIView()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "抖音账号授权登录"
        label.textColor = ENTAppColors.primaryText
        label.font = .semibold(ofSize: 30)
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "登录你的抖音账号，继续使用 Soker。"
        label.textColor = ENTAppColors.secondaryText
        label.font = .regular(ofSize: 16)
        label.numberOfLines = 0
        return label
    }()

    private lazy var connectionCard: UIView = {
        let view = UIView()
        view.backgroundColor = ENTAppColors.cardBackground
        view.layer.cornerRadius = 26
        view.layer.cornerCurve = .continuous
        return view
    }()

    private lazy var cardStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        return stack
    }()

    private lazy var brandRow: UIView = UIView()

    private lazy var brandImageView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "ENTDouyinBrand"))
        view.backgroundColor = .hex000000
        view.contentMode = .scaleAspectFit
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.isAccessibilityElement = false
        return view
    }()

    private lazy var brandLabel: UILabel = {
        let label = UILabel()
        label.text = "抖音账号"
        label.font = .semibold(ofSize: 18)
        label.textColor = ENTAppColors.primaryText
        return label
    }()

    private lazy var statusPill: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 13
        view.backgroundColor = ENTAppColors.controlBackground
        return view
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .medium(ofSize: 12)
        label.textColor = ENTAppColors.secondaryText
        label.accessibilityIdentifier = "ent_douyin_connection_status"
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private lazy var dividerView: UIView = {
        let view = UIView()
        view.backgroundColor = ENTAppColors.separator
        return view
    }()

    private lazy var stateTextStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()

    private lazy var stateTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .semibold(ofSize: 20)
        label.textColor = ENTAppColors.primaryText
        label.numberOfLines = 0
        return label
    }()

    private lazy var stateBodyLabel: UILabel = {
        let label = UILabel()
        label.font = .regular(ofSize: 14)
        label.textColor = ENTAppColors.secondaryText
        label.numberOfLines = 0
        return label
    }()

    private lazy var stepsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 18
        return stack
    }()

    private lazy var accountRow: UIView = UIView()

    private lazy var avatarView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.tintColor = ENTAppColors.primary
        view.backgroundColor = ENTAppColors.controlBackground
        view.layer.cornerRadius = 26
        view.clipsToBounds = true
        view.isAccessibilityElement = false
        return view
    }()

    private lazy var nicknameLabel: UILabel = {
        let label = UILabel()
        label.font = .semibold(ofSize: 19)
        label.textColor = ENTAppColors.primaryText
        label.numberOfLines = 0
        return label
    }()

    private lazy var handleLabel: UILabel = {
        let label = UILabel()
        label.font = .regular(ofSize: 13)
        label.textColor = ENTAppColors.secondaryText
        label.numberOfLines = 0
        return label
    }()

    private lazy var accountScopeLabel: UILabel = {
        let label = UILabel()
        label.text = "抖音账号已授权。"
        label.font = .regular(ofSize: 13)
        label.textColor = ENTAppColors.secondaryText
        label.numberOfLines = 0
        return label
    }()

    private lazy var reminderLabel: UILabel = {
        let label = UILabel()
        label.text = "请使用你本人或有权使用的抖音账号。"
        label.font = .regular(ofSize: 13)
        label.textColor = ENTAppColors.tertiaryText
        label.numberOfLines = 0
        return label
    }()

    private lazy var actionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()

    private lazy var primaryButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = ENTAppColors.primary
        configuration.baseForegroundColor = .hexFFFFFF
        configuration.cornerStyle = .capsule
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .semibold(ofSize: 17)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "ent_douyin_connection_primary"
        button.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        return button
    }()

    private lazy var secondaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(ENTAppColors.primary, for: .normal)
        button.titleLabel?.font = .medium(ofSize: 14)
        button.accessibilityIdentifier = "ent_douyin_connection_relogin"
        button.addTarget(self, action: #selector(reloginTapped), for: .touchUpInside)
        return button
    }()

    private lazy var helpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("授权登录遇到问题", for: .normal)
        button.setTitleColor(ENTAppColors.secondaryText, for: .normal)
        button.titleLabel?.font = .regular(ofSize: 13)
        button.addTarget(self, action: #selector(helpTapped), for: .touchUpInside)
        return button
    }()
}

// MARK: - Private Setup

private extension ENTDouyinConnectionViewController {
    func setupUI() {
        title = "抖音账号授权登录"
        view.backgroundColor = ENTAppColors.pageBackground
        view.accessibilityIdentifier = "ent_douyin_connection"
        view += [
            scrollView += [
                contentView += [titleLabel, subtitleLabel, connectionCard, reminderLabel]
            ],
            actionStack
        ]
        connectionCard += [cardStack]
        [brandRow, dividerView, stateTextStack, stepsStack, accountRow, accountScopeLabel].forEach(cardStack.addArrangedSubview)
        brandRow += [brandImageView, brandLabel, statusPill += [statusLabel]]
        [stateTitleLabel, stateBodyLabel].forEach(stateTextStack.addArrangedSubview)
        accountRow += [avatarView, nicknameLabel, handleLabel]
        [primaryButton, secondaryButton, helpButton].forEach(actionStack.addArrangedSubview)

        stepsStack.addArrangedSubview(makeInstructionRow(
            symbol: "rectangle.and.arrow.up.right",
            title: "保存二维码到相册",
            body: "打开授权页面，将二维码保存到手机相册。"
        ))
        stepsStack.addArrangedSubview(makeInstructionRow(
            symbol: "person.crop.circle.badge.checkmark",
            title: "打开抖音扫码",
            body: "在抖音扫一扫中，从相册选择刚保存的二维码。"
        ))
        stepsStack.addArrangedSubview(makeInstructionRow(
            symbol: "checkmark.shield",
            title: "扫码授权后进入首页",
            body: "在抖音确认授权后，返回 Soker。"
        ))

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionStack.snp.top).offset(-8)
        }
        contentView.snp.makeConstraints { make in
            make.top.bottom.equalTo(scrollView.contentLayoutGuide)
            make.leading.trailing.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalTo(titleLabel)
        }
        connectionCard.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(26)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        cardStack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(24)
            make.leading.trailing.equalToSuperview().inset(22)
        }
        brandRow.snp.makeConstraints { make in
            make.height.equalTo(42)
        }
        brandImageView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.height.equalTo(42)
        }
        brandLabel.snp.makeConstraints { make in
            make.leading.equalTo(brandImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(statusPill.snp.leading).offset(-8)
        }
        statusPill.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
        statusLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(6)
            make.leading.trailing.equalToSuperview().inset(10)
        }
        dividerView.snp.makeConstraints { make in
            make.height.equalTo(1)
        }
        avatarView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.width.height.equalTo(52)
            make.bottom.lessThanOrEqualToSuperview().priority(999)
        }
        nicknameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(avatarView.snp.trailing).offset(14)
            make.trailing.equalToSuperview()
        }
        handleLabel.snp.makeConstraints { make in
            make.top.equalTo(nicknameLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(nicknameLabel)
            make.bottom.equalToSuperview().priority(999)
        }
        reminderLabel.snp.makeConstraints { make in
            make.top.equalTo(connectionCard.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().inset(20)
        }
        actionStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(8)
        }
        primaryButton.snp.makeConstraints { make in
            make.height.equalTo(52)
        }
        secondaryButton.snp.makeConstraints { make in
            make.height.equalTo(40).priority(999)
        }
        helpButton.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
    }


    func makeInstructionRow(symbol: String, title: String, body: String) -> UIView {
        let row = UIView()
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.contentMode = .scaleAspectFit
        icon.tintColor = ENTAppColors.primary
        let heading = UILabel()
        heading.text = title
        heading.font = .medium(ofSize: 14)
        heading.textColor = ENTAppColors.primaryText
        heading.numberOfLines = 0
        let detail = UILabel()
        detail.text = body
        detail.font = .regular(ofSize: 12)
        detail.textColor = ENTAppColors.secondaryText
        detail.numberOfLines = 0
        row += [icon, heading, detail]
        icon.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.width.height.equalTo(22)
        }
        heading.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(icon.snp.trailing).offset(12)
            make.trailing.equalToSuperview()
        }
        detail.snp.makeConstraints { make in
            make.top.equalTo(heading.snp.bottom).offset(5)
            make.leading.trailing.equalTo(heading)
            make.bottom.equalToSuperview()
        }
        return row
    }
}

// MARK: - Private State

private extension ENTDouyinConnectionViewController {
    func render(_ phase: ENTDouyinConnectionModel.Phase) {
        primaryButton.isEnabled = true
        primaryButton.configuration?.showsActivityIndicator = false
        primaryButton.configuration?.image = nil
        secondaryButton.isHidden = true
        stepsStack.isHidden = false
        accountRow.isHidden = true
        accountScopeLabel.isHidden = true
        statusLabel.textColor = ENTAppColors.secondaryText
        statusPill.backgroundColor = ENTAppColors.controlBackground

        switch phase {
        case .idle:
            setState(status: "待授权", title: "使用抖音扫码授权", body: "保存二维码后，打开抖音从相册扫码。", action: "授权登录")
        case .waitingForLogin:
            setState(status: "等待登录", title: "请在抖音页面完成登录", body: "完成后返回 Soker，核验当前登录的抖音账号。", action: "检查登录状态")
            showReloginAction("重新打开登录窗口")
        case .checking:
            setState(status: "正在核验", title: "正在核验抖音账号", body: "核验当前登录状态与账号信息，请稍候。", action: "正在核验账号")
            primaryButton.configuration?.showsActivityIndicator = true
            primaryButton.isEnabled = false
        case .confirming(let account):
            setState(status: "已授权", title: "授权登录完成", body: "抖音账号已授权，可以开始使用。", action: "进入获客")
            statusLabel.textColor = ENTAppColors.primary
            statusPill.backgroundColor = ENTAppColors.primary.withAlphaComponent(0.1)
            stepsStack.isHidden = true
            accountRow.isHidden = false
            accountScopeLabel.isHidden = false
            nicknameLabel.text = account.nickname
            handleLabel.text = "抖音号：\(account.handle)"
            avatarView.image = UIImage(systemName: account.avatarSymbol) ?? UIImage(systemName: "person.crop.circle")
            showReloginAction("更换抖音账号")
        case .failed(let failure):
            renderFailure(failure)
        case .expired:
            setState(status: "登录已失效", title: "请重新授权登录", body: "当前登录状态已失效，请重新扫码授权。", action: "重新授权登录")
        }
    }

    func renderFailure(_ failure: ENTDouyinConnectionModel.Failure) {
        switch failure {
        case .cancelled:
            setState(status: "未授权", title: "抖音登录已取消", body: "尚未完成账号授权。你可以重新发起授权登录。", action: "重新授权登录")
        case .loginNotCompleted:
            setState(status: "尚未登录", title: "尚未完成抖音登录", body: "请在抖音页面完成登录，再返回核验账号。", action: "继续授权登录")
        case .network:
            setState(status: "核验失败", title: "暂时无法核验登录状态", body: "请检查网络后重试。已完成登录时，无需重复登录。", action: "重新核验")
            showReloginAction("重新授权登录")
        case .identityUnavailable:
            setState(status: "待核验", title: "暂时无法读取账号信息", body: "请重新核验账号。仍无法读取时，可重新授权登录。", action: "重新核验")
            showReloginAction("重新授权登录")
        }
    }

    func setState(status: String, title: String, body: String, action: String) {
        statusLabel.text = status
        stateTitleLabel.text = title
        stateBodyLabel.text = body
        primaryButton.configuration?.title = action
    }

    func showReloginAction(_ title: String) {
        secondaryButton.setTitle(title, for: .normal)
        secondaryButton.isHidden = false
    }
}

// MARK: - Private Actions

private extension ENTDouyinConnectionViewController {
    func openPlatformLogin() {
        guard !hasFinished, presentedViewController == nil else { return }
        model.beginLogin()
        let login = ENTDouyinLoginViewController(
            onCompleted: { [weak self] in
                guard let self, !self.hasFinished else { return }
                self.dismiss(animated: true) {
                    self.model.completePlatformLogin()
                    self.model.checkConnection()
                    self.showAuthorizationSuccess()
                }
            },
            onCancelled: { [weak self] in
                guard let self else { return }
                self.dismiss(animated: true) {
                    self.model.cancelLogin()
                }
            }
        )
        login.modalPresentationStyle = .fullScreen
        present(login, animated: true)
    }

    func showAuthorizationSuccess() {
        guard case let .confirming(account) = model.phase, model.confirm() else { return }
        let success = ENTDouyinAuthorizationSuccessViewController { [weak self] in
            guard let self else { return }
            self.dismiss(animated: false) {
                self.finishAuthorization()
            }
        }
        present(success, animated: true)
    }

    func finishAuthorization() {
        guard !hasFinished, model.confirm() else { return }
        hasFinished = true
        if let onFinish {
            onFinish()
        } else {
            dismiss(animated: true)
        }
    }

    @objc func primaryTapped() {
        guard !hasFinished else { return }
        switch model.phase {
        case .idle, .expired:
            openPlatformLogin()
        case .waitingForLogin:
            model.checkConnection()
        case .checking:
            break
        case .confirming:
            finishAuthorization()
        case .failed(let failure):
            switch failure {
            case .cancelled, .loginNotCompleted:
                openPlatformLogin()
            case .network, .identityUnavailable:
                model.retry()
            }
        }
    }

    @objc func reloginTapped() {
        openPlatformLogin()
    }

    @objc func helpTapped() {
        guard presentedViewController == nil else { return }
        let sheet = UIAlertController(
            title: "授权登录遇到问题",
            message: "请先保存二维码，再打开抖音扫一扫，从相册选择已保存的二维码。",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "重新核验账号", style: .default) { [weak self] _ in
            self?.model.checkConnection()
        })
        sheet.addAction(UIAlertAction(title: "重新打开登录窗口", style: .default) { [weak self, weak sheet] _ in
            sheet?.dismiss(animated: true) { [weak self] in
                self?.openPlatformLogin()
            }
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        sheet.popoverPresentationController?.sourceView = helpButton
        sheet.popoverPresentationController?.sourceRect = helpButton.bounds
        present(sheet, animated: true)
    }
}
