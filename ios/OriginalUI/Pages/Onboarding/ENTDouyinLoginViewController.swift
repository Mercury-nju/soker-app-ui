import CoreImage.CIFilterBuiltins
import Photos
import SnapKit
import UIKit

/// The QR image and scan event are local preview fixtures, never platform credentials.
@MainActor
final class ENTDouyinLoginViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private let onCompleted: () -> Void
    private let onCancelled: () -> Void
    private var hasResolved = false
    private var isSaving = false
    private var deadline = Date()
    private var countdown: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    #if DEBUG
    private var previewVerification: UIView?
    private var lastPreviewCode = 123456
    #endif

    init(onCompleted: @escaping () -> Void, onCancelled: @escaping () -> Void) {
        self.onCompleted = onCompleted
        self.onCancelled = onCancelled
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        countdown?.cancel()
        refreshTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        refreshQR()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presentationController?.delegate = self
        updateExpiry()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            resolve(completed: false)
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        resolve(completed: false)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private lazy var scrollView = UIScrollView()
    private lazy var titleLabel = makeLabel("抖音扫码登录", size: 26, weight: true)
    private lazy var closeButton = makeButton("稍后登录", filled: false, action: #selector(closeTapped))
    private lazy var expiryLabel = makeLabel("", size: 16, secondary: true)
    private lazy var qrLoadingIndicator = UIActivityIndicatorView(appStyle: .mediumInk)
    private lazy var qrImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.layer.magnificationFilter = .nearest
        view.isAccessibilityElement = true
        view.accessibilityLabel = "登录二维码"
        #if DEBUG
        let gesture = UITapGestureRecognizer(target: self, action: #selector(previewScan))
        gesture.numberOfTapsRequired = 3
        view.addGestureRecognizer(gesture)
        view.isUserInteractionEnabled = true
        #endif
        return view
    }()
    private lazy var helpButton = makeButton("扫码遇到问题", filled: false, action: #selector(helpTapped))
    private lazy var saveButton = makeButton("保存二维码到相册", icon: "square.and.arrow.down", action: #selector(saveTapped))
    private lazy var openButton = makeButton("跳转抖音", filled: false, icon: "arrow.up.right", action: #selector(openDouyin))
    private let accent = UIColor(hex: 0x151B21)
    private lazy var qrRow = UIView()
    private lazy var timerRow: UIStackView = {
        let clock = UIImageView(image: UIImage(systemName: "clock"))
        clock.tintColor = .systemGray
        clock.snp.makeConstraints { $0.size.equalTo(17) }
        let content = UIStackView(arrangedSubviews: [clock, expiryLabel])
        content.alignment = .center
        content.spacing = 7
        let row = UIStackView(arrangedSubviews: [content])
        row.axis = .vertical
        row.alignment = .center
        return row
    }()
    private lazy var firstCard = makeCard([
        stepHeader("01", "保存二维码到相册"),
        qrRow, timerRow, saveButton, helpButton
    ], firstStep: true)
    private lazy var secondCard = makeCard([
        stepHeader("02", "去抖音扫码"),
        instruction("1", "打开抖音扫一扫"),
        instruction("2", "从相册选择已保存的二维码"),
        instruction("3", "确认授权后返回 Soker"),
        openButton
    ], firstStep: false)
    private lazy var cards: UIStackView = {
        let divider = UIView()
        divider.backgroundColor = UIColor(hex: 0xD4D4D4)
        divider.snp.makeConstraints { $0.height.equalTo(1 / UIScreen.main.scale) }
        let stack = UIStackView(arrangedSubviews: [firstCard, divider, secondCard])
        stack.axis = .vertical
        stack.spacing = 25
        return stack
    }()
}

// MARK: - Layout

private extension ENTDouyinLoginViewController {
    func setupUI() {
        view.backgroundColor = .white
        view.tintColor = accent
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        if #available(iOS 26.0, *) {
            scrollView.topEdgeEffect.isHidden = true
        }
        let heroClip = UIView()
        heroClip.clipsToBounds = true
        let hero = AcquisitionLoginHeroView()
        let sheet = UIView()
        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = 27
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheet.clipsToBounds = true
        let mark = UIImageView(image: UIImage(named: "SokerWebsiteMark")?.withRenderingMode(.alwaysTemplate))
        mark.contentMode = .scaleAspectFit
        mark.tintColor = .white
        titleLabel.textColor = .white
        view += [heroClip, sheet, mark, titleLabel, closeButton]
        heroClip.addSubview(hero)
        sheet.addSubview(scrollView)
        scrollView.addSubview(cards)
        qrRow.addSubview(qrImageView)
        qrRow.addSubview(qrLoadingIndicator)
        sheet.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(197)
            make.leading.trailing.bottom.equalToSuperview()
        }
        heroClip.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(sheet.snp.top).offset(28)
        }
        hero.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(-81)
            make.height.equalTo(317)
        }
        mark.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(72)
            make.leading.equalToSuperview().offset(31)
            make.size.equalTo(CGSize(width: 43, height: 25))
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(mark.snp.bottom).offset(13)
            make.leading.equalTo(mark)
            make.trailing.lessThanOrEqualTo(closeButton.snp.leading).offset(-12)
        }
        closeButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.trailing.equalToSuperview().inset(18)
        }
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        cards.snp.makeConstraints { make in
            make.leading.trailing.equalTo(scrollView.contentLayoutGuide).inset(21)
            make.top.equalTo(scrollView.contentLayoutGuide).offset(30)
            make.bottom.equalTo(scrollView.contentLayoutGuide).inset(48)
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-42)
        }
        qrImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.height.equalTo(188)
        }
        qrLoadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(qrImageView)
        }
    }

    func stepHeader(_ number: String, _ title: String) -> UIStackView {
        let badge = makeLabel(number, size: 15, weight: true)
        badge.textColor = accent
        badge.textAlignment = .center
        badge.backgroundColor = UIColor(hex: 0xD4DDE5)
        badge.layer.cornerRadius = 12
        badge.clipsToBounds = true
        badge.snp.makeConstraints { make in
            make.width.equalTo(39)
            make.height.equalTo(24)
        }
        let row = UIStackView(arrangedSubviews: [badge, makeLabel(title, size: 21, weight: true)])
        row.alignment = .center
        row.spacing = 12
        return row
    }

    func instruction(_ number: String, _ title: String) -> UIStackView {
        let icon = makeLabel(number, size: 14)
        icon.textAlignment = .center
        icon.backgroundColor = UIColor(hex: 0xE8E8E8)
        icon.layer.cornerRadius = 11.5
        icon.clipsToBounds = true
        icon.snp.makeConstraints { $0.size.equalTo(23) }
        let row = UIStackView(arrangedSubviews: [icon, makeLabel(title, size: 15)])
        row.alignment = .center
        row.spacing = 11
        return row
    }

    func makeCard(_ rows: [UIView], firstStep: Bool) -> UIView {
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 10
        if firstStep {
            stack.setCustomSpacing(15, after: rows[0])
            stack.setCustomSpacing(6, after: rows[1])
            stack.setCustomSpacing(19, after: rows[2])
            stack.setCustomSpacing(3, after: rows[3])
        } else {
            stack.setCustomSpacing(16, after: rows[0])
            stack.setCustomSpacing(23, after: rows[3])
        }
        return stack
    }

    func makeLabel(_ title: String, size: CGFloat, weight: Bool = false, secondary: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = weight ? .semibold(ofSize: size) : .regular(ofSize: size)
        label.textColor = secondary ? ENTAppColors.secondaryText : ENTAppColors.primaryText
        label.numberOfLines = 0
        return label
    }

    func makeButton(_ title: String, filled: Bool = true, icon: String? = nil, action: Selector) -> UIButton {
        let isClose = action == #selector(closeTapped)
        let isHelp = action == #selector(helpTapped)
        var config: UIButton.Configuration = filled ? .filled() : .plain()
        config.title = title
        config.image = icon.flatMap {
            UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
        }
        config.imagePadding = 12
        config.baseForegroundColor = filled || isClose ? .white : accent
        config.baseBackgroundColor = filled ? accent : .clear
        config.cornerStyle = .fixed
        config.background.cornerRadius = filled ? 19 : 16
        if !filled && icon != nil {
            config.background.strokeColor = UIColor(hex: 0x526B83)
            config.background.strokeWidth = 0.8
        }
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { input in
            var output = input
            output.font = isHelp ? .regular(ofSize: 16) : .semibold(ofSize: icon == nil ? 16 : 18)
            if isHelp { output.underlineStyle = .single }
            return output
        }
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.snp.makeConstraints { make in make.height.greaterThanOrEqualTo(icon == nil ? 44 : 49) }
        return button
    }
}

// MARK: - Actions

private extension ENTDouyinLoginViewController {
    func animateQRRefresh() {
        countdown?.cancel()
        qrLoadingIndicator.startAnimating()
        let duration: TimeInterval = UIAccessibility.isReduceMotionEnabled ? 0 : 0.2
        UIView.animate(withDuration: duration) {
            self.qrImageView.alpha = 0
        }

        refreshTask = Task { [weak self] in
            // The preview QR renders synchronously. Keep the loading cue visible for a short beat.
            do { try await Task.sleep(nanoseconds: 380_000_000) } catch { return }
            guard let self, !self.hasResolved else { return }
            self.refreshTask = nil
            self.qrLoadingIndicator.stopAnimating()
            UIView.animate(withDuration: duration) {
                self.refreshQR()
            }
        }
        updateExpiry()
    }

    func refreshQR() {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("soker-ui-fixture://non-auth/\(UUID().uuidString)".utf8)
        if let output = filter.outputImage {
            let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
            if let image = CIContext().createCGImage(scaled, from: scaled.extent) {
                let qr = UIImage(cgImage: image)
                let canvas = CGSize(width: qr.size.width + 64, height: qr.size.height + 64)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                qrImageView.image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
                    context.cgContext.setFillColor(UIColor.hexFFFFFF.cgColor)
                    context.cgContext.fill(CGRect(origin: .zero, size: canvas))
                    qr.draw(at: CGPoint(x: 32, y: 32))
                }
            }
        }
        deadline = Date().addingTimeInterval(59)
        updateExpiry()
        countdown?.cancel()
        countdown = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
                guard !Task.isCancelled, self?.updateExpiry() == true else { return }
            }
        }
    }

    @discardableResult
    func updateExpiry() -> Bool {
        if refreshTask != nil {
            expiryLabel.text = "正在刷新二维码"
            saveButton.isEnabled = false
            return false
        }
        let seconds = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        let expiryText = seconds > 0 ? "剩余 \(seconds) 秒" : "二维码已过期"
        let actionTitle = seconds > 0 ? "保存二维码到相册" : "刷新二维码"
        if expiryLabel.text != expiryText { expiryLabel.text = expiryText }
        if saveButton.configuration?.title != actionTitle { saveButton.configuration?.title = actionTitle }
        if saveButton.isEnabled == isSaving { saveButton.isEnabled = !isSaving }
        let opacity: CGFloat = seconds > 0 ? 1 : 0.35
        if qrImageView.alpha != opacity { qrImageView.alpha = opacity }
        return seconds > 0
    }

    @objc func saveTapped() {
        guard !hasResolved, !isSaving, refreshTask == nil else { return }
        guard deadline > Date() else { animateQRRefresh(); return }
        guard let image = qrImageView.image else { return }
        guard Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") != nil else {
            showNotice("暂时无法保存二维码")
            return
        }
        isSaving = true
        updateExpiry()
        let imageDeadline = deadline
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard !hasResolved else { return }
            defer { isSaving = false; updateExpiry() }
            guard status == .authorized || status == .limited else {
                showNotice("无法保存二维码", message: "请在系统设置中允许添加照片后重试。")
                return
            }
            guard imageDeadline > Date() else {
                updateExpiry()
                showNotice("二维码已过期", message: "请刷新后重新保存。")
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                guard !hasResolved else { return }
                let alert = UIAlertController(title: "已保存到相册", message: "在抖音扫一扫中选择这张二维码。", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "取消", style: .cancel))
                alert.addAction(UIAlertAction(title: "跳转抖音", style: .default) { [weak self] _ in self?.openDouyin() })
                present(alert, animated: true)
            } catch {
                guard !hasResolved else { return }
                showNotice("保存失败", message: "请重试。")
            }
        }
    }

    @objc func openDouyin() {
        guard !hasResolved, let url = URL(string: "https://www.douyin.com/user/self") else { return }
        // This official URL is already used by the desktop integration.
        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { [weak self] opened in
            guard let self, !opened, !self.hasResolved else { return }
            self.showNotice("未能打开抖音", message: "请手动打开抖音，进入扫一扫。")
        }
    }

    @objc func helpTapped() {
        showNotice("扫码遇到问题", message: "检查二维码是否已过期。请在抖音打开扫一扫，从相册选择最新保存的二维码。")
    }

    func showNotice(_ title: String, message: String? = nil) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .cancel))
        present(alert, animated: true)
    }

    @objc func closeTapped() {
        #if DEBUG
        if let verification = previewVerification {
            verification.endEditing(true)
            verification.removeFromSuperview()
            previewVerification = nil
            titleLabel.text = "抖音扫码登录"
            closeButton.configuration?.title = "稍后登录"
            deadline = .distantPast
            qrImageView.image = nil
            cards.isHidden = false
            scrollView.setContentOffset(.zero, animated: false)
            animateQRRefresh()
            return
        }
        #endif
        resolve(completed: false)
    }

    #if DEBUG
    @objc func previewScan() {
        guard !hasResolved, refreshTask == nil, deadline > Date(), previewVerification == nil else { return }
        countdown?.cancel()
        lastPreviewCode = (lastPreviewCode + Int.random(in: 1..<1_000_000)) % 1_000_000
        let code = String(format: "%06d", lastPreviewCode)
        let verification = ENTDouyinSMSPreviewView(demoCode: code) { [weak self] in
            self?.resolve(completed: true)
        }
        previewVerification = verification
        titleLabel.text = "抖音安全验证"
        closeButton.configuration?.title = "返回"
        cards.isHidden = true
        scrollView.addSubview(verification)
        verification.snp.makeConstraints { make in
            make.edges.equalTo(cards)
        }
        scrollView.setContentOffset(.zero, animated: false)
        verification.focusCode()
    }
    #endif

    func resolve(completed: Bool) {
        guard !hasResolved else { return }
        hasResolved = true
        countdown?.cancel()
        refreshTask?.cancel()
        if completed { onCompleted() } else { onCancelled() }
    }
}
