import UIKit
import WebKit
import UniformTypeIdentifiers
import SnapKit
import MarkdownView
import MarkdownParser

@MainActor
protocol ChatViewDelegate: AnyObject {
    func chatViewDidRequestRetry(_ chatView: ChatView)
    func chatView(_ chatView: ChatView, didSubmit text: String)
    func chatViewDidRequestFocus(_ chatView: ChatView)
    func chatViewDidBeginVoiceInput(_ chatView: ChatView)
    func chatView(_ chatView: ChatView, didChangeVoiceTranslation translation: CGSize)
    func chatView(_ chatView: ChatView, didEndVoiceInput commit: Bool)
    func chatView(_ chatView: ChatView, didToggleThinking messageID: String)
    func chatView(_ chatView: ChatView, didToggleProcessGroup groupID: String, messageID: String)
    func chatView(_ chatView: ChatView, didSelectQuestion question: String)
}

@MainActor
final class ChatView: UIView {
    private static let markdownLogger = AppLogger.logger(category: "ENTChat.Markdown")
    weak var delegate: ChatViewDelegate?

    private lazy var collectionView: UICollectionView = {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(80)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: itemSize,
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 14
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 16,
            leading: 10,
            bottom: 0,
            trailing: 10
        )
        let layout = UICollectionViewCompositionalLayout(section: section)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = ENTAppColors.pageBackground
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.showsVerticalScrollIndicator = false
        view.contentInset.bottom = 16
        view.verticalScrollIndicatorInsets.bottom = 16
        view.delegate = self
        view.register(ENTChatMessageCell.self, forCellWithReuseIdentifier: ENTChatMessageCell.reuseIdentifier)
        view.register(ENTChatVoicePreviewCell.self, forCellWithReuseIdentifier: ENTChatVoicePreviewCell.reuseIdentifier)
        return view
    }()

    private lazy var chatInputView: ENTChatInputView = {
        let view = ENTChatInputView()
        view.delegate = self
        view.onPickAttachments = { [weak self] in self?.pickAcquisitionAttachments() }
        return view
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(appStyle: .mediumInk)
        view.hidesWhenStopped = true
        return view
    }()

    private lazy var voiceHintLabel: UILabel = {
        let label = UILabel()
        label.font = .medium(ofSize: 13)
        label.textAlignment = .center
        label.textColor = .hex828282
        label.isHidden = true
        return label
    }()

    private lazy var sessionErrorView: UIView = {
        let container = UIView()
        container.backgroundColor = ENTAppColors.pageBackground

        let title = UILabel()
        title.text = "聊天加载失败"
        title.font = .semibold(ofSize: 18)
        title.textColor = ENTAppColors.primaryText
        title.textAlignment = .center

        let message = UILabel()
        message.tag = 1001
        message.font = .regular(ofSize: 14)
        message.textColor = ENTAppColors.secondaryText
        message.text = "聊天服务暂时不可用，请重试。"
        message.textAlignment = .center
        message.numberOfLines = 0

        let retry = UIButton(type: .system)
        retry.setTitle("重试", for: .normal)
        retry.setTitleColor(.white, for: .normal)
        retry.titleLabel?.font = .medium(ofSize: 15)
        retry.backgroundColor = ENTAppColors.primary
        retry.layer.cornerRadius = 20
        retry.addTarget(self, action: #selector(retrySessionLoad), for: .touchUpInside)

        container += [title, message, retry]
        title.snp.makeConstraints { make in
            make.centerY.equalToSuperview().offset(-28)
            make.leading.trailing.equalToSuperview().inset(32)
        }
        message.snp.makeConstraints { make in
            make.top.equalTo(title.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(40)
        }
        retry.snp.makeConstraints { make in
            make.top.equalTo(message.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.width.equalTo(104)
            make.height.equalTo(40)
        }
        return container
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    private static let acquisitionURL = URL(string: "http://127.0.0.1:3131/chat-tab?mode=acquisition&embedded=1")!
    private static let acquisitionAttachmentCountMessage = "sokerAcquisitionAttachmentCount"
    private static let accountMenuMessage = "sokerAccountMenu"
    private static let chatModeMessage = "sokerChatMode"
    private static let acquisitionReadyMessage = "sokerAcquisitionReady"
    private static let acquisitionInputMessage = "sokerAcquisitionInput"
#if DEBUG
    private static let acquisitionDeliveryMessage = "sokerAcquisitionDelivery"
    private static let acquisitionHistoryMessage = "sokerAcquisitionHistory"
#endif

    private enum EmbeddedChatMode: String {
        case acquisition
        case review
    }

    private var accountMenuOpen = false
    private var isLoadingBilling = false
    private var embeddedChatMode = EmbeddedChatMode.acquisition
    private var embeddedChatDrafts: [EmbeddedChatMode: String] = [:]
    private var acquisitionWebView: WKWebView?
    private var acquisitionReady = false
    private var acquisitionBottomInset: Int?
    private var acquisitionLoadTask: Task<Void, Never>?
    private var acquisitionSendTask: Task<Void, Never>?
    private var pendingAcquisitionMessages: [String] = []

    func submitAcquisition(_ text: String) {
        pendingAcquisitionMessages.append(text)
        sendPendingAcquisitionMessages()
    }

    private func mountAcquisitionWebView() {
        guard acquisitionWebView == nil else { return }
        let bridge = ENTChatAcquisitionBridge(owner: self)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(bridge, name: Self.acquisitionReadyMessage)
        configuration.userContentController.add(bridge, name: Self.acquisitionAttachmentCountMessage)
        configuration.userContentController.add(bridge, name: Self.acquisitionInputMessage)
        configuration.userContentController.add(bridge, name: Self.chatModeMessage)
        configuration.userContentController.add(bridge, name: Self.accountMenuMessage)
#if DEBUG
        configuration.userContentController.add(bridge, name: Self.acquisitionDeliveryMessage)
        configuration.userContentController.add(bridge, name: Self.acquisitionHistoryMessage)
#endif

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.underPageBackgroundColor = .white
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        webView.navigationDelegate = self
        acquisitionWebView = webView

        insertSubview(webView, belowSubview: voiceHintLabel)
        webView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        loadAcquisitionWebView()
    }

    private func loadAcquisitionWebView() {
        acquisitionReady = false
        accountMenuOpen = false
        acquisitionBottomInset = nil
        chatInputView.attachmentCount = 0
        acquisitionLoadTask?.cancel()
        sessionErrorView.removeFromSuperview()
        acquisitionWebView?.isHidden = false
        chatInputView.isHidden = false
        loadingIndicator.startAnimating()
        acquisitionWebView?.load(URLRequest(url: Self.acquisitionURL))
        acquisitionLoadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, !self.acquisitionReady else { return }
            self.showAcquisitionWebError()
        }
    }

    private func showAcquisitionWebError() {
        acquisitionReady = false
        acquisitionLoadTask?.cancel()
        acquisitionWebView?.isHidden = true
        renderSessionError("获客对话暂时加载不了，请确认本机 Chat 服务已启动后重试。")
    }

    private func sendPendingAcquisitionMessages() {
        guard acquisitionReady, acquisitionSendTask == nil,
              !pendingAcquisitionMessages.isEmpty, let webView = acquisitionWebView else { return }
        acquisitionSendTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.acquisitionSendTask = nil }
            while self.acquisitionReady, let text = self.pendingAcquisitionMessages.first {
                do {
                    _ = try await webView.callAsyncJavaScript(
                        "window.dispatchEvent(new CustomEvent('soker-acquisition-submit', { detail: text }));",
                        arguments: ["text": text],
                        in: nil,
                        contentWorld: .page
                    )
                    self.pendingAcquisitionMessages.removeFirst()
                } catch {
                    self.showAcquisitionWebError()
                    return
                }
            }
        }
    }

    fileprivate func receiveAcquisitionMessage(_ message: WKScriptMessage) {
        guard message.webView === acquisitionWebView,
              message.frameInfo.isMainFrame,
              message.frameInfo.request.url == Self.acquisitionURL else { return }
        switch message.name {
        case Self.acquisitionReadyMessage:
            acquisitionReady = true
            acquisitionLoadTask?.cancel()
            loadingIndicator.stopAnimating()
            sessionErrorView.removeFromSuperview()
            acquisitionWebView?.isHidden = false
            chatInputView.isHidden = accountMenuOpen
            updateAcquisitionBottomInset()
            sendPendingAcquisitionMessages()
        case Self.accountMenuMessage:
            if let action = message.body as? String {
                handleAccountMenuAction(action)
            }
        case Self.chatModeMessage:
            guard let value = message.body as? String,
                  let mode = EmbeddedChatMode(rawValue: value),
                  mode != embeddedChatMode else { return }
            embeddedChatDrafts[embeddedChatMode] = chatInputView.draftText
            embeddedChatMode = mode
            chatInputView.isReviewMode = mode == .review
            chatInputView.setTextFromModel(embeddedChatDrafts[mode] ?? "")
        case Self.acquisitionAttachmentCountMessage:
            if acquisitionReady, let count = message.body as? Int {
                chatInputView.attachmentCount = max(0, count)
            }
        case Self.acquisitionInputMessage:
            if acquisitionReady, let text = message.body as? String {
                prepareAcquisitionPrompt(text)
            }
#if DEBUG
        case Self.acquisitionDeliveryMessage:
            guard acquisitionReady else { return }
            ENTAcquisitionDeliveryStore.shared.receive(message.body)
        case Self.acquisitionHistoryMessage:
            guard let webView = acquisitionWebView else { return }
            let frame = message.frameInfo
            let records = ENTAcquisitionDeliveryStore.shared.deliveries.map { delivery in
                [
                    "id": delivery.id,
                    "name": delivery.name,
                    "need": delivery.need,
                    "contact": delivery.contact,
                    "source": delivery.source,
                    "nextAction": delivery.nextAction,
                    "avatar": delivery.avatarAsset
                ]
            }
            Task { @MainActor in
                _ = try? await webView.callAsyncJavaScript(
                    "window.dispatchEvent(new CustomEvent('soker-acquisition-history', { detail: records }));",
                    arguments: ["records": records],
                    in: frame,
                    contentWorld: .page
                )
            }
#endif
        default:
            break
        }
    }

    private var items: [String: ENTChatListItem] = [:]
    private var shouldAutoScroll = true
    private var hasRenderedInitialContent = false
    private var pendingBottomScrollPasses = 0
    private var isBottomScrollRetryScheduled = false
    private var allowsBackwardBottomCorrection = false
    private var chatInputBottomConstraint: Constraint?
    private var voiceHintHeightConstraint: Constraint?
    private var keyboardFrameObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupDataSource()
        setupUI()
        keyboardFrameObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
            let curve = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
            Task { @MainActor [weak self] in
                self?.applyKeyboardFrame(frame, duration: duration, curve: curve)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let keyboardFrameObserver {
            NotificationCenter.default.removeObserver(keyboardFrameObserver)
        }
    }

    private func handleAccountMenuAction(_ action: String) {
        switch action {
        case "open":
            accountMenuOpen = true
            endEditing(true)
            chatInputView.isHidden = true
        case "close":
            accountMenuOpen = false
            chatInputView.isHidden = !acquisitionReady
        case "notificationSettings":
            guard acquisitionReady,
                  let notificationsURL = URL(string: UIApplication.openNotificationSettingsURLString),
                  let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            Task { @MainActor in
                if await !UIApplication.shared.open(notificationsURL) {
                    await UIApplication.shared.open(settingsURL)
                }
            }
        case "account", "douyin", "billing":
            guard acquisitionReady, let presenter = attachmentPresenter,
                  presenter.presentedViewController == nil else { return }
            endEditing(true)
            if action == "account" {
                let account = UINavigationController(rootViewController: ENTProfileViewController())
                presenter.presentBottomSheet(account, configuration: .init(detents: [.large]))
            } else if action == "douyin" {
                ENTProfileViewController.presentDouyinAccount(from: presenter)
            } else {
                openBilling(from: presenter)
            }
        default:
            break
        }
    }

    private func openBilling(from presenter: UIViewController) {
        guard !isLoadingBilling else { return }
        isLoadingBilling = true
        let catalogService = ProfileMembershipSubscriptionCatalogService()
        Task { @MainActor [weak self, weak presenter] in
            defer { self?.isLoadingBilling = false }
            do {
                let presentation = try await catalogService.fetchCatalog()
                guard let presenter, presenter.viewIfLoaded?.window != nil,
                      presenter.presentedViewController == nil else { return }
                let page = ProfileMembershipSubscriptionPurchaseViewController(
                    presentation: presentation,
                    catalogService: catalogService,
                    isPresentedAsPaywallSheet: true
                )
                presenter.presentBottomSheet(page, configuration: .init(detents: [.large]))
            } catch {
                guard let presenter, presenter.viewIfLoaded?.window != nil,
                      presenter.presentedViewController == nil else { return }
                let alert = UIAlertController(title: "套餐暂时无法加载", message: "请稍后再试。", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "好", style: .default))
                presenter.present(alert, animated: true)
            }
        }
    }

    private func updateAcquisitionBottomInset() {
        guard acquisitionReady, let webView = acquisitionWebView else { return }
        let inset = Int(max(0, webView.frame.maxY - voiceHintLabel.frame.minY).rounded(.up))
        guard acquisitionBottomInset != inset else { return }
        acquisitionBottomInset = inset
        webView.evaluateJavaScript("document.documentElement.style.setProperty('--acquisition-bottom-inset', '\(inset)px')")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateAcquisitionBottomInset()
        collectionView.layoutIfNeeded()
        guard shouldAutoScroll else { return }
        guard pendingBottomScrollPasses > 0 else { return }
        pendingBottomScrollPasses -= 1
        scrollToBottom(allowsBackwardCorrection: allowsBackwardBottomCorrection)
        if pendingBottomScrollPasses == 0 {
            allowsBackwardBottomCorrection = false
        }
        scheduleBottomScrollRetryIfNeeded()
    }

    func render(model: ENTChatViewModel?, forceScrollToBottom: Bool = false) {
        guard let model else { return }
        if case .global = model.chatContext {
            collectionView.isHidden = true
            updateVoiceHint(isActive: model.isVoiceInputActive, isCancelling: model.voiceInputCancelling)
            chatInputView.showsAttachments = true
            chatInputView.updateComposerState(enabled: true, streaming: false)
            backgroundColor = .white
            mountAcquisitionWebView()
            return
        }
        chatInputView.showsAttachments = false
        if forceScrollToBottom {
            shouldAutoScroll = true
        }
        if let errorMessage = model.sessionLoadErrorMessage {
            renderSessionError(errorMessage)
            return
        }
        if model.isLoadingSession {
            clearConversation()
            sessionErrorView.removeFromSuperview()
            collectionView.isHidden = true
            chatInputView.isHidden = true
            loadingIndicator.isHidden = false
            loadingIndicator.startAnimating()
            return
        }
        updateVoiceHint(isActive: model.isVoiceInputActive, isCancelling: model.voiceInputCancelling)
        sessionErrorView.removeFromSuperview()
        collectionView.isHidden = false
        chatInputView.isHidden = false
        chatInputView.updateComposerState(enabled: false, streaming: false)
        let wasNearBottom = isNearBottom
        var nextItems: [String: ENTChatListItem] = [:]
        var identifiers: [String] = []

        for message in model.visibleMessages {
            nextItems[message.id] = .message(
                message,
                assistantName: model.assistantName,
                isActive: message.id == model.activeAssistantID,
                isSending: message.id == model.activeAssistantID && model.isSending,
                thinkingStatusText: message.id == model.activeAssistantID ? model.thinkingStatusText : ""
            )
            identifiers.append(message.id)
        }

        if model.isVoiceInputActive {
            let id = "chat-voice-preview"
            nextItems[id] = .voicePreview(
                text: model.voiceInputText,
                isCancelling: model.voiceInputCancelling
            )
            identifiers.append(id)
        }

        let previousItems = items
        let existingIdentifiers = dataSource.snapshot().itemIdentifiers.filter { identifiers.contains($0) }
        let changedIdentifiers = existingIdentifiers.filter { identifier in
            previousItems[identifier] != nextItems[identifier]
        }

        items = nextItems
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(identifiers)
        if !changedIdentifiers.isEmpty {
            snapshot.reconfigureItems(changedIdentifiers)
        }
        Self.markdownLogger.info(
            "list.render items=\(identifiers.count) changed=\(changedIdentifiers.count) changedIds=\(changedIdentifiers.joined(separator: ","))"
        )

        UIView.performWithoutAnimation {
            dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                guard let self else { return }
                UIView.performWithoutAnimation {
                    self.setNeedsLayout()
                    self.layoutIfNeeded()
                    self.collectionView.collectionViewLayout.invalidateLayout()
                    self.collectionView.layoutIfNeeded()
                    let requiresInitialScroll = !self.hasRenderedInitialContent
                    if forceScrollToBottom || requiresInitialScroll || (self.shouldAutoScroll && wasNearBottom) {
                        self.requestBottomScroll(
                            allowsBackwardCorrection: forceScrollToBottom || requiresInitialScroll
                        )
                    }
                    self.hasRenderedInitialContent = true
                }
            }
        }

        loadingIndicator.isHidden = !model.isLoadingSession
        if model.isLoadingSession {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    private func renderSessionError(_ message: String) {
        clearConversation()
        collectionView.isHidden = true
        chatInputView.isHidden = true
        loadingIndicator.stopAnimating()
        if sessionErrorView.superview == nil {
            addSubview(sessionErrorView)
            sessionErrorView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        let normalizedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        (sessionErrorView.viewWithTag(1001) as? UILabel)?.text = normalizedMessage.isEmpty
            ? "聊天服务暂时不可用，请重试。"
            : normalizedMessage
    }

    private func clearConversation() {
        hasRenderedInitialContent = false
        pendingBottomScrollPasses = 0
        isBottomScrollRetryScheduled = false
        allowsBackwardBottomCorrection = false
        guard !dataSource.snapshot().itemIdentifiers.isEmpty else {
            return
        }
        items.removeAll(keepingCapacity: false)
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    @objc private func retrySessionLoad() {
        if acquisitionWebView != nil {
            loadAcquisitionWebView()
        } else {
            delegate?.chatViewDidRequestRetry(self)
        }
    }

    func setInputText(_ text: String) {
        chatInputView.setTextFromModel(text)
    }

    func focusInput() {
        chatInputView.focusTextView()
    }

    func prepareAcquisitionPrompt(_ prompt: String) {
        guard !chatInputView.isHidden else { return }
        chatInputView.preparePrompt(prompt)
    }

    func scrollToBottom(allowsBackwardCorrection: Bool = false) {
        guard collectionView.numberOfSections > 0,
              collectionView.numberOfItems(inSection: 0) > 0 else { return }
        shouldAutoScroll = true
        let targetY = max(
            -collectionView.adjustedContentInset.top,
            collectionView.contentSize.height
                - collectionView.bounds.height
                + collectionView.adjustedContentInset.bottom
        )
        let currentY = collectionView.contentOffset.y
        guard abs(targetY - currentY) > 0.5,
              allowsBackwardCorrection || targetY > currentY else {
            return
        }
        collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: targetY), animated: false)
    }

    private func requestBottomScroll(allowsBackwardCorrection: Bool = false) {
        pendingBottomScrollPasses = max(pendingBottomScrollPasses, 3)
        self.allowsBackwardBottomCorrection = self.allowsBackwardBottomCorrection || allowsBackwardCorrection
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func scheduleBottomScrollRetryIfNeeded() {
        guard pendingBottomScrollPasses > 0, !isBottomScrollRetryScheduled else { return }
        isBottomScrollRetryScheduled = true

        // Self-sizing Markdown cells may finish measuring after the snapshot completion.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.isBottomScrollRetryScheduled = false
            guard self.shouldAutoScroll else { return }
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.setNeedsLayout()
        }
    }

    private var isNearBottom: Bool {
        let bottom = collectionView.contentOffset.y + collectionView.bounds.height
        return bottom >= collectionView.contentSize.height - collectionView.contentInset.bottom - 24
    }

    private func setupUI() {
        backgroundColor = ENTAppColors.pageBackground
        self += [collectionView, voiceHintLabel, chatInputView, loadingIndicator]

        collectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(voiceHintLabel.snp.top)
        }
        voiceHintLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(chatInputView.snp.top)
            voiceHintHeightConstraint = make.height.equalTo(0).constraint
        }
        chatInputView.snp.makeConstraints { make in
            let inset = ENTMainTabBarView.capsuleHorizontalInset
            let maximumWidth = ENTMainTabBarView.capsuleMaximumWidth
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(maximumWidth)
            make.width.lessThanOrEqualToSuperview().offset(-2 * inset)
            make.width.equalToSuperview().offset(-2 * inset).priority(999)
            chatInputBottomConstraint = make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-12).constraint
        }
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func applyKeyboardFrame(_ screenFrame: CGRect, duration: TimeInterval, curve: UInt) {
        let wasAtBottom = shouldAutoScroll && isNearBottom
        let localFrame = convert(screenFrame, from: nil)
        let keyboardIsVisible = localFrame.minY < bounds.maxY
        let keyboardOverlap = keyboardIsVisible ? max(0, bounds.maxY - localFrame.minY) : 0
        let bottomOffset = keyboardIsVisible
            ? min(0, safeAreaInsets.bottom - keyboardOverlap - 12)
            : -12
        chatInputBottomConstraint?.update(offset: bottomOffset)

        let options = UIView.AnimationOptions(rawValue: curve << 16)
            .union(.beginFromCurrentState)
            .union(.allowUserInteraction)
        UIView.animate(withDuration: duration, delay: 0, options: options) { [weak self] in
            guard let self else { return }
            self.layoutIfNeeded()
            if wasAtBottom {
                self.scrollToBottom()
            }
        }
    }

    private func updateVoiceHint(isActive: Bool, isCancelling: Bool) {
        voiceHintLabel.text = isCancelling ? "松手取消" : "上滑取消，松开发送"
        voiceHintLabel.textColor = isCancelling ? .hexFF4737 : .hex828282
        voiceHintLabel.isHidden = !isActive
        voiceHintHeightConstraint?.update(offset: isActive ? 28 : 0)
        UIView.animate(withDuration: 0.15) { [weak self] in
            self?.layoutIfNeeded()
        }
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { [weak self] collectionView, indexPath, identifier in
            guard let item = self?.items[identifier] else { return nil }
            switch item {
            case .message(let message, let assistantName, let isActive, let isSending, let thinkingStatusText):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: ENTChatMessageCell.reuseIdentifier,
                    for: indexPath
                ) as? ENTChatMessageCell
                cell?.configure(
                    message: message,
                    assistantName: assistantName,
                    isActive: isActive,
                    isSending: isSending,
                    thinkingStatusText: thinkingStatusText,
                    onToggleThinking: { [weak self] in
                        guard let self else { return }
                        self.shouldAutoScroll = false
                        self.delegate?.chatView(self, didToggleThinking: message.id)
                    },
                    onToggleProcessGroup: { [weak self] groupID in
                        guard let self else { return }
                        self.shouldAutoScroll = false
                        self.delegate?.chatView(self, didToggleProcessGroup: groupID, messageID: message.id)
                    },
                    onSelectQuestion: { [weak self] question in
                        guard let self else { return }
                        self.delegate?.chatView(self, didSelectQuestion: question)
                    }
                )
                return cell
            case .voicePreview(let text, let isCancelling):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: ENTChatVoicePreviewCell.reuseIdentifier,
                    for: indexPath
                ) as? ENTChatVoicePreviewCell
                cell?.configure(text: text, isCancelling: isCancelling)
                return cell
            }
        }
    }
}

extension ChatView: UIDocumentPickerDelegate {
    private var attachmentPresenter: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }

    private func pickAcquisitionAttachments() {
        guard acquisitionReady, let controller = attachmentPresenter else { return }
        endEditing(true)
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        controller.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard acquisitionReady, let webView = acquisitionWebView else { return }
        Task { @MainActor in
            do {
                let records = try await Task.detached {
                    var totalSize = 0
                    return try urls.map { url -> [String: String] in
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                        guard let size, size <= 10 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                        totalSize += size
                        guard totalSize <= 40 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                        return [
                            "name": url.lastPathComponent,
                            "type": UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream",
                            "base64": try Data(contentsOf: url).base64EncodedString()
                        ]
                    }
                }.value
                guard acquisitionReady, acquisitionWebView === webView else { return }
                _ = try await webView.callAsyncJavaScript(
                    "window.dispatchEvent(new CustomEvent('soker-acquisition-attachments', { detail: records }));",
                    arguments: ["records": records],
                    in: nil,
                    contentWorld: .page
                )
            } catch {
                let message = (error as? CocoaError)?.code == .fileReadTooLarge
                    ? "单个附件最多 10 MB，每次选择最多 40 MB。"
                    : "无法读取所选附件，请重新选择。"
                let alert = UIAlertController(title: "无法添加附件", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "好", style: .default))
                attachmentPresenter?.present(alert, animated: true)
            }
        }
    }
}

@MainActor
extension ChatView: ENTChatInputViewDelegate {
    func chatInputView(_ inputView: ENTChatInputView, didSubmit text: String) {
        if acquisitionWebView != nil, text.isEmpty {
            endEditing(true)
            submitAcquisition(text)
        } else {
            delegate?.chatView(self, didSubmit: text)
        }
    }

    func chatInputViewDidRequestFocus(_ inputView: ENTChatInputView) {
        delegate?.chatViewDidRequestFocus(self)
    }

    func chatInputViewDidBeginVoiceInput(_ inputView: ENTChatInputView) {
        delegate?.chatViewDidBeginVoiceInput(self)
    }

    func chatInputView(_ inputView: ENTChatInputView, didChangeVoiceTranslation translation: CGSize) {
        delegate?.chatView(self, didChangeVoiceTranslation: translation)
    }

    func chatInputView(_ inputView: ENTChatInputView, didEndVoiceInput commit: Bool) {
        delegate?.chatView(self, didEndVoiceInput: commit)
    }
}

@MainActor
extension ChatView: UICollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        shouldAutoScroll = false
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate, isNearBottom {
            shouldAutoScroll = true
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if isNearBottom {
            shouldAutoScroll = true
        }
    }

}

@MainActor
extension ChatView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        navigationAction.targetFrame?.isMainFrame == true
            && navigationAction.request.url == Self.acquisitionURL ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showAcquisitionWebError() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showAcquisitionWebError() }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        showAcquisitionWebError()
    }
}

@MainActor
private final class ENTChatAcquisitionBridge: NSObject, WKScriptMessageHandler {
    private weak var owner: ChatView?

    init(owner: ChatView) {
        self.owner = owner
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.receiveAcquisitionMessage(message)
    }
}

private enum ENTChatListItem: Equatable {
    case message(
        ENTChatViewModel.Message,
        assistantName: String,
        isActive: Bool,
        isSending: Bool,
        thinkingStatusText: String
    )
    case voicePreview(text: String, isCancelling: Bool)
}

@MainActor
protocol ENTChatInputViewDelegate: AnyObject {
    func chatInputView(_ inputView: ENTChatInputView, didSubmit text: String)
    func chatInputViewDidRequestFocus(_ inputView: ENTChatInputView)
    func chatInputViewDidBeginVoiceInput(_ inputView: ENTChatInputView)
    func chatInputView(_ inputView: ENTChatInputView, didChangeVoiceTranslation translation: CGSize)
    func chatInputView(_ inputView: ENTChatInputView, didEndVoiceInput commit: Bool)
}

@MainActor
final class ENTChatInputView: UIView, UITextViewDelegate, UIGestureRecognizerDelegate {
    weak var delegate: ENTChatInputViewDelegate?
    private(set) var isKeyboardVisible = false
    var isReviewMode = false {
        didSet { updatePlaceholder() }
    }
    var draftText: String { textView.text ?? "" }
    private var composerEffectEnabled = false
    private var composerStreaming = false
    private let composerBorder = CALayer()
    private let composerMask = CAShapeLayer()
    private let composerGradient = CAGradientLayer()

    override var isHidden: Bool {
        didSet { refreshComposerBorder() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshComposerBorder()
    }
    private var voiceGestureView: UIView?
    private var longPressStartLocation: CGPoint?

    private lazy var glassView: UIVisualEffectView = {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            effect = UIGlassEffect(style: .regular)
        } else {
            effect = UIBlurEffect(style: .systemChromeMaterial)
        }
        let view = UIVisualEffectView(effect: effect)
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        view.layer.cornerRadius = 28
        return view
    }()

    var onPickAttachments: (() -> Void)?
    var attachmentCount = 0 {
        didSet { updateInputState() }
    }
    var showsAttachments = false {
        didSet {
            guard oldValue != showsAttachments else { return }
            attachmentButton.isHidden = !showsAttachments
            textView.snp.updateConstraints { make in
                make.leading.equalToSuperview().offset(showsAttachments ? 44 : 16)
            }
        }
    }

    private lazy var attachmentButton: UIButton = {
        let button = UIButton(type: .system)
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        button.setPreferredSymbolConfiguration(symbolConfiguration, forImageIn: .normal)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.tintColor = .hex000000
        button.accessibilityLabel = "添加附件"
        button.isHidden = true
        button.addAction(UIAction { [weak self] _ in self?.onPickAttachments?() }, for: .touchUpInside)
        return button
    }()

    private lazy var microphoneView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "mic"))
        view.tintColor = .hex000000
        view.contentMode = .center
        return view
    }()

    private lazy var textView: UITextView = {
        let view = UITextView()
        view.delegate = self
        view.font = .regular(ofSize: 16)
        view.textColor = .hex000000
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.textAlignment = .left
        view.returnKeyType = .send
        return view
    }()

    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.font = .regular(ofSize: 16)
        label.textColor = .hex828282
        label.text = "输入你的问题，长按语音输入"
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.up"), for: .normal)
        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 13, weight: .bold),
            forImageIn: .normal
        )
        button.tintColor = .white
        button.accessibilityLabel = "发送"
        button.backgroundColor = ENTAppColors.primary
        button.layer.cornerRadius = 14
        button.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setVoiceInputEnabled(true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = bounds.height / 2
        layer.cornerRadius = radius
        glassView.layer.cornerRadius = radius
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        composerBorder.frame = bounds
        composerMask.frame = composerBorder.bounds
        let outline = composerMask.bounds.insetBy(dx: 0.5, dy: 0.5)
        composerMask.path = outline.isEmpty ? nil : UIBezierPath(roundedRect: outline, cornerRadius: outline.height / 2).cgPath
        // A square covering the diagonal keeps the fixed capsule mask filled at every angle.
        let size = ceil(hypot(bounds.width, bounds.height)) + 2
        composerGradient.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        composerGradient.position = CGPoint(x: composerBorder.bounds.midX, y: composerBorder.bounds.midY)
        CATransaction.commit()
    }

    func updateComposerState(enabled: Bool, streaming: Bool) {
        if composerEffectEnabled != enabled {
            composerEffectEnabled = enabled
            updatePlaceholder()
            updateInputState()
        }
        composerStreaming = streaming
        refreshComposerBorder()
    }

    private func updatePlaceholder() {
        if composerEffectEnabled {
            placeholderLabel.text = isReviewMode ? "你想看哪位客户的朋友圈？" : "描述你想找的客户"
        } else {
            placeholderLabel.text = isKeyboardVisible ? "输入你的问题" : "输入你的问题，长按语音输入"
        }
        microphoneView.accessibilityLabel = "长按语音输入"
    }

    private func refreshComposerBorder() {
        let active = composerEffectEnabled && window != nil && !isHidden
        let opacity: Float = active ? 1 : 0
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        if composerBorder.opacity != opacity {
            let previous = composerBorder.presentation()?.opacity ?? composerBorder.opacity
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            composerBorder.opacity = opacity
            CATransaction.commit()
            composerBorder.removeAnimation(forKey: "composerOpacity")
            if active && !reduceMotion {
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = previous
                fade.toValue = opacity
                fade.duration = 0.3
                fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                composerBorder.add(fade, forKey: "composerOpacity")
            }
        }
        if active && !reduceMotion {
            guard composerGradient.animation(forKey: "composerRotation") == nil else { return }
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = 0
            rotation.toValue = 2 * Double.pi
            rotation.duration = 4
            rotation.repeatCount = .infinity
            rotation.timingFunction = CAMediaTimingFunction(name: .linear)
            composerGradient.add(rotation, forKey: "composerRotation")
        } else {
            composerGradient.removeAnimation(forKey: "composerRotation")
        }
    }

    func setTextFromModel(_ text: String) {
        guard textView.text != text else { return }
        textView.text = text
        updateInputState()
    }

    func preparePrompt(_ prompt: String) {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            setTextFromModel(prompt)
        }
        focusTextView()
    }

    func focusTextView() {
        textView.becomeFirstResponder()
    }

    func setVoiceInputEnabled(_ enabled: Bool) {
        voiceGestureView?.removeFromSuperview()
        voiceGestureView = nil
        guard enabled, !isKeyboardVisible else { return }

        let gestureView = ENTChatVoiceGestureView()
        gestureView.backgroundColor = .clear
        gestureView.passthroughView = sendButton
        let tap = UITapGestureRecognizer(target: self, action: #selector(inputOverlayTapped))
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(inputOverlayLongPressed(_:)))
        longPress.minimumPressDuration = 0.25
        longPress.cancelsTouchesInView = true
        longPress.delegate = self
        tap.require(toFail: longPress)
        gestureView.addGestureRecognizer(tap)
        gestureView.addGestureRecognizer(longPress)
        addSubview(gestureView)
        bringSubviewToFront(attachmentButton)
        gestureView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        voiceGestureView = gestureView
    }

    private func setupUI() {
        backgroundColor = .clear
        self += [glassView, microphoneView, textView, placeholderLabel, sendButton, attachmentButton]
        composerBorder.opacity = 0
        composerMask.fillColor = UIColor.clear.cgColor
        composerMask.strokeColor = UIColor.black.cgColor
        composerMask.lineWidth = 1
        composerBorder.mask = composerMask
        composerGradient.type = .conic
        composerGradient.colors = ENTAppColors.chatComposerBorderGradient
        composerGradient.locations = [0, 0.3333, 0.6667, 1]
        composerGradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        composerGradient.endPoint = CGPoint(x: 0.5, y: 1)
        composerBorder.addSublayer(composerGradient)
        layer.addSublayer(composerBorder)
        glassView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        layer.cornerRadius = 28
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.72).cgColor
        microphoneView.snp.makeConstraints { make in
            make.edges.equalTo(sendButton)
        }
        attachmentButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(2)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(42)
        }
        textView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(sendButton.snp.leading).offset(-8)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
            make.height.greaterThanOrEqualTo(28)
        }
        placeholderLabel.snp.makeConstraints { make in
            make.leading.equalTo(textView)
            make.trailing.equalTo(textView)
            make.top.equalTo(textView).offset(textView.textContainerInset.top)
        }
        sendButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }
        updateInputState()
    }

    private func updateInputState() {
        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        placeholderLabel.isHidden = hasText
        let canSend = hasText || attachmentCount > 0
        microphoneView.isHidden = canSend
        sendButton.isHidden = !canSend
        sendButton.isEnabled = canSend
        sendButton.backgroundColor = canSend ? ENTAppColors.primary : ENTAppColors.controlBackground
        sendButton.tintColor = canSend ? .white : ENTAppColors.tertiaryText
    }

    @objc private func sendButtonTapped() {
        submitText()
    }

    @objc private func inputOverlayTapped() {
        delegate?.chatInputViewDidRequestFocus(self)
    }

    @objc private func inputOverlayLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        let location = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            longPressStartLocation = location
            delegate?.chatInputViewDidBeginVoiceInput(self)
        case .changed:
            guard let longPressStartLocation else { return }
            delegate?.chatInputView(
                self,
                didChangeVoiceTranslation: CGSize(
                    width: location.x - longPressStartLocation.x,
                    height: location.y - longPressStartLocation.y
                )
            )
        case .ended, .cancelled, .failed:
            let translationY = longPressStartLocation.map { location.y - $0.y } ?? 0
            delegate?.chatInputView(self, didEndVoiceInput: recognizer.state == .ended && translationY >= -48)
            longPressStartLocation = nil
        default:
            break
        }
    }

    private func submitText() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || attachmentCount > 0 else { return }
        delegate?.chatInputView(self, didSubmit: text)
        textView.text = ""
        updateInputState()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        isKeyboardVisible = true
        refreshComposerBorder()
        updatePlaceholder()
        setVoiceInputEnabled(false)
        updateInputState()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        isKeyboardVisible = false
        refreshComposerBorder()
        updatePlaceholder()
        setVoiceInputEnabled(true)
        updateInputState()
    }

    func textViewDidChange(_ textView: UITextView) {
        updateInputState()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            submitText()
            return false
        }
        return true
    }
}

private final class ENTChatVoiceGestureView: UIView {
    weak var passthroughView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let passthroughView, !passthroughView.isHidden,
              (passthroughView as? UIControl)?.isEnabled != false else {
            return super.hitTest(point, with: event)
        }
        let pointInPassthroughView = convert(point, to: passthroughView)
        if passthroughView.bounds.contains(pointInPassthroughView) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

@MainActor
private final class ENTChatMessageCell: UICollectionViewCell {
    static let reuseIdentifier = "ENTChatMessageCell"
    private static let markdownLogger = AppLogger.logger(category: "ENTChat.Markdown")

    private var configuredMessageID: String?
    private var streamingMarkdownView: ENTChatMarkdownContainer?
    private var processView: ENTChatProcessView?
    private var renderedQuestionCards: [ENTChatQuestionCard] = []

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let width = layoutAttributes.size.width
        guard width > 0 else { return super.preferredLayoutAttributesFitting(layoutAttributes) }
        contentView.bounds.size.width = width
        contentView.setNeedsLayout()
        contentView.layoutIfNeeded()
        let size = contentView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        layoutAttributes.size.height = ceil(size.height)
        return layoutAttributes
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.subviews.forEach { $0.removeFromSuperview() }
        configuredMessageID = nil
        streamingMarkdownView = nil
        processView = nil
    }

    func configure(
        message: ENTChatViewModel.Message,
        assistantName: String,
        isActive: Bool,
        isSending: Bool,
        thinkingStatusText: String,
        onToggleThinking: @escaping () -> Void,
        onToggleProcessGroup: @escaping (String) -> Void,
        onSelectQuestion: @escaping (String) -> Void
    ) {
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        Self.markdownLogger.info(
            "cell.configure id=\(message.id) phase=\(String(describing: message.phase)) active=\(isActive) contentLength=\(content.count)"
        )
        if message.role == "assistant", configuredMessageID == message.id,
           isActive, isSending, message.phase == .thinking, let processView {
            processView.configure(
                process: message.process, expanded: message.isThinkingExpanded,
                expandedGroups: message.expandedProcessGroups, fallbackStatus: thinkingStatusText,
                active: true, onToggle: onToggleThinking, onToggleGroup: onToggleProcessGroup
            )
            return
        }
        if message.role == "assistant",
           configuredMessageID == message.id,
           isActive,
           isSending,
           message.phase == .streaming,
           renderedQuestionCards == message.questionCards,
           let streamingMarkdownView,
           !content.isEmpty {
            Self.markdownLogger.info("markdown.reuse id=\(message.id) contentLength=\(content.count)")
            updateMarkdownView(streamingMarkdownView, content: content)
            processView?.configure(
                process: message.process, expanded: message.isThinkingExpanded,
                expandedGroups: message.expandedProcessGroups, fallbackStatus: thinkingStatusText,
                active: true, onToggle: onToggleThinking, onToggleGroup: onToggleProcessGroup
            )
            return
        }

        contentView.subviews.forEach { $0.removeFromSuperview() }
        configuredMessageID = message.role == "assistant" ? message.id : nil
        streamingMarkdownView = nil
        processView = nil
        renderedQuestionCards = message.questionCards
        contentView.backgroundColor = .clear
        if message.role == "user" {
            configureUserMessage(message.content)
        } else {
            configureAssistantMessage(
                message: message,
                assistantName: assistantName,
                isActive: isActive,
                isSending: isSending,
                thinkingStatusText: thinkingStatusText,
                onToggleThinking: onToggleThinking,
                onToggleProcessGroup: onToggleProcessGroup,
                onSelectQuestion: onSelectQuestion
            )
        }
    }

    private func configureUserMessage(_ text: String) {
        let bubble = ENTChatBubbleView()
        bubble.backgroundColor = ENTAppColors.primary
        bubble.layer.masksToBounds = true

        let label = makeLabel(text: text, font: .regular(ofSize: 16), color: .hexFFFFFF)
        label.textAlignment = .left
        bubble.addSubview(label)
        contentView.addSubview(bubble)
        bubble.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.trailing.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(48)
            make.width.lessThanOrEqualToSuperview().multipliedBy(0.82)
        }
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        }
    }

    private func configureAssistantMessage(
        message: ENTChatViewModel.Message,
        assistantName: String,
        isActive: Bool,
        isSending: Bool,
        thinkingStatusText: String,
        onToggleThinking: @escaping () -> Void,
        onToggleProcessGroup: @escaping (String) -> Void,
        onSelectQuestion: @escaping (String) -> Void
    ) {
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let bubble = UIView()
        bubble.backgroundColor = ENTAppColors.chatUserBubble
        bubble.layer.cornerRadius = 16
        bubble.layer.masksToBounds = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill
        contentView.addSubview(bubble)
        bubble.addSubview(stack)
        bubble.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        let isThinkingMessage = isActive && isSending && message.phase == .thinking
        let isStreamingMessage = isActive && isSending && message.phase == .streaming
        let header = UIStackView()
        header.axis = .horizontal
        header.spacing = 4
        let icon: UIView
        if isThinkingMessage || isStreamingMessage {
            icon = ENTChatThinkingMarkView()
        } else {
            let imageView = UIImageView(image: UIImage(systemName: "sparkles"))
            imageView.tintColor = ENTAppColors.primary
            icon = imageView
        }
        icon.snp.makeConstraints { make in make.width.height.equalTo(18) }
        let nameLabel = makeLabel(text: assistantName, font: .semibold(ofSize: 15), color: ENTAppColors.secondaryText)
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        header.addArrangedSubview(icon)
        header.addArrangedSubview(nameLabel)
        let headerContainer = UIView()
        headerContainer.addSubview(header)
        header.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        stack.addArrangedSubview(headerContainer)
        stack.setCustomSpacing(16, after: headerContainer)

        if message.process.startedAt != nil || message.process.durationSeconds != nil || !message.process.groups.isEmpty {
            let processView = ENTChatProcessView()
            processView.configure(
                process: message.process, expanded: message.isThinkingExpanded,
                expandedGroups: message.expandedProcessGroups, fallbackStatus: thinkingStatusText,
                active: isActive && isSending, onToggle: onToggleThinking,
                onToggleGroup: onToggleProcessGroup
            )
            self.processView = processView
            stack.addArrangedSubview(processView)
        }

        if !content.isEmpty {
            let markdownView = makeMarkdownView(content: content)
            streamingMarkdownView = isStreamingMessage ? markdownView : nil
            stack.addArrangedSubview(markdownView)
        }

        if !message.questionCards.isEmpty {
            let title = makeLabel(text: "还可以继续问", font: .regular(ofSize: 14), color: .hex828282)
            title.textAlignment = .center
            if let previousView = stack.arrangedSubviews.last {
                stack.setCustomSpacing(16, after: previousView)
            }
            stack.addArrangedSubview(title)
            stack.setCustomSpacing(16, after: title)
            let actionsStack = UIStackView()
            actionsStack.axis = .vertical
            actionsStack.alignment = .leading
            actionsStack.spacing = 8
            actionsStack.distribution = .fill
            actionsStack.setContentCompressionResistancePriority(.required, for: .vertical)
            stack.addArrangedSubview(actionsStack)
            for card in message.questionCards {
                for question in card.questions {
                    var configuration = UIButton.Configuration.plain()
                    var title = AttributedString(question.text)
                    title.font = UIFont.regular(ofSize: 15)
                    configuration.attributedTitle = title
                    configuration.baseForegroundColor = .hex000000
                    configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                    configuration.background.backgroundColor = .clear
                    configuration.background.strokeColor = UIColor.hex828282.withAlphaComponent(0.45)
                    configuration.background.strokeWidth = 1 / traitCollection.displayScale
                    configuration.background.cornerRadius = 9
                    configuration.cornerStyle = .fixed
                    let button = UIButton(configuration: configuration)
                    button.contentHorizontalAlignment = .leading
                    button.setContentHuggingPriority(.required, for: .horizontal)
                    button.setContentCompressionResistancePriority(.required, for: .horizontal)
                    button.setContentCompressionResistancePriority(.required, for: .vertical)
                    button.addAction(UIAction { _ in onSelectQuestion(question.query) }, for: .touchUpInside)
                    actionsStack.addArrangedSubview(button)
                    button.snp.makeConstraints { make in
                        make.leading.equalToSuperview()
                        make.width.lessThanOrEqualTo(actionsStack.snp.width)
                        make.height.greaterThanOrEqualTo(36)
                    }
                }
            }
        }

        if message.phase == .completed && !content.isEmpty {
            let copyButton = UIButton(type: .system)
            copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
            copyButton.setPreferredSymbolConfiguration(
                UIImage.SymbolConfiguration(pointSize: 12, weight: .regular),
                forImageIn: .normal
            )
            copyButton.tintColor = ENTAppColors.secondaryText
            copyButton.accessibilityLabel = "复制回复"
            copyButton.contentHorizontalAlignment = .center
            copyButton.contentVerticalAlignment = .center
            copyButton.addAction(UIAction { _ in
                UIPasteboard.general.string = message.content
                copyButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
                AppToast.show("消息已复制", style: .success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
                }
            }, for: .touchUpInside)
            let footer = UIView()
            footer.addSubview(copyButton)
            copyButton.snp.makeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                make.width.height.equalTo(20)
            }
            footer.snp.makeConstraints { make in
                make.height.equalTo(20)
            }
            stack.addArrangedSubview(footer)
        }
    }

    private func makeLabel(text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    private func makeMarkdownView(content: String) -> ENTChatMarkdownContainer {
        Self.markdownLogger.info("markdown.create contentLength=\(content.count)")
        var theme = MarkdownTheme.default
        theme.align(to: 16)
        theme.colors.body = .hex000000
        theme.colors.code = .hex000000
        theme.colors.emphasis = ENTAppColors.primaryText
        theme.colors.highlight = ENTAppColors.primary
        let view = ENTChatMarkdownContainer()
        let parserResult = MarkdownParser().parse(content)
        let preprocessed = MarkdownTextView.PreprocessedContent(
            parserResult: parserResult,
            theme: theme
        )
        view.configure(preprocessed: preprocessed, theme: theme)
        compactMarkdownSpacing(in: view.markdownView)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        return view
    }

    private func updateMarkdownView(_ view: ENTChatMarkdownContainer, content: String) {
        Self.markdownLogger.info("markdown.update contentLength=\(content.count) bounds=\(view.bounds.size) intrinsic=\(view.intrinsicContentSize)")
        var theme = MarkdownTheme.default
        theme.align(to: 16)
        theme.colors.body = .hex000000
        theme.colors.code = .hex000000
        theme.colors.emphasis = ENTAppColors.primaryText
        theme.colors.highlight = ENTAppColors.primary
        let parserResult = MarkdownParser().parse(content)
        let preprocessed = MarkdownTextView.PreprocessedContent(
            parserResult: parserResult,
            theme: theme
        )
        view.configure(preprocessed: preprocessed, theme: theme)
        compactMarkdownSpacing(in: view.markdownView)
    }

    private func compactMarkdownSpacing(in view: MarkdownTextView) {
        guard let attributedText = view.textView.attributedText.mutableCopy() as? NSMutableAttributedString else {
            return
        }
        let range = NSRange(location: 0, length: attributedText.length)
        attributedText.enumerateAttribute(.paragraphStyle, in: range) { value, paragraphRange, _ in
            guard let style = value as? NSParagraphStyle,
                  let compactStyle = style.mutableCopy() as? NSMutableParagraphStyle else {
                return
            }
            let isListItem = compactStyle.firstLineHeadIndent > 0
            compactStyle.lineSpacing = 2
            compactStyle.paragraphSpacing = isListItem ? 4 : min(compactStyle.paragraphSpacing, 6)
            compactStyle.paragraphSpacingBefore = min(compactStyle.paragraphSpacingBefore, 6)
            attributedText.addAttribute(.paragraphStyle, value: compactStyle, range: paragraphRange)
        }
        view.textView.attributedText = attributedText
    }
}

@MainActor
private final class ENTChatMarkdownContainer: UIView {
    let markdownView = MarkdownTextView()
    private var lastMeasuredWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        markdownView.throttleInterval = 1.0 / 20.0
        addSubview(markdownView)
        markdownView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        guard bounds.width > 0 else {
            return CGSize(width: UIView.noIntrinsicMetric, height: 1)
        }
        let size = markdownView.boundingSize(for: bounds.width)
        return CGSize(width: UIView.noIntrinsicMetric, height: ceil(size.height))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, abs(lastMeasuredWidth - bounds.width) > 0.5 else { return }
        lastMeasuredWidth = bounds.width
        markdownView.textView.preferredMaxLayoutWidth = bounds.width
        invalidateIntrinsicContentSize()
    }

    func configure(preprocessed: MarkdownTextView.PreprocessedContent, theme: MarkdownTheme) {
        markdownView.theme = theme
        markdownView.setMarkdownManually(preprocessed)
        markdownView.invalidateIntrinsicContentSize()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}

@MainActor
private final class ENTChatThinkingMarkView: UIView {
    private let imageView = UIImageView(image: UIImage(systemName: "sparkles"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.tintColor = ENTAppColors.primary
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            imageView.layer.removeAllAnimations()
        } else {
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.fromValue = 0.88
            animation.toValue = 1.12
            animation.duration = 0.9
            animation.autoreverses = true
            animation.repeatCount = .greatestFiniteMagnitude
            imageView.layer.add(animation, forKey: "thinking-breathe")

            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.55
            opacity.toValue = 1.0
            opacity.duration = 0.9
            opacity.autoreverses = true
            opacity.repeatCount = .greatestFiniteMagnitude
            imageView.layer.add(opacity, forKey: "thinking-opacity")
        }
    }
}

@MainActor
private final class ENTChatVoicePreviewCell: UICollectionViewCell {
    static let reuseIdentifier = "ENTChatVoicePreviewCell"

    func configure(text: String, isCancelling: Bool) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        let bubble = ENTChatBubbleView()
        bubble.backgroundColor = ENTAppColors.chatUserBubble
        bubble.layer.borderWidth = 1
        bubble.layer.borderColor = UIColor.hexE8E7EC.cgColor
        bubble.layer.masksToBounds = true

        let label = UILabel()
        label.text = isCancelling ? "松手取消" : (text.isEmpty ? "正在聆听..." : text)
        label.font = .regular(ofSize: 16)
        label.textColor = isCancelling ? .hexFF4737 : .hex000000
        label.numberOfLines = 0
        bubble.addSubview(label)
        contentView.addSubview(bubble)
        bubble.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.trailing.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(48)
            make.width.lessThanOrEqualToSuperview().multipliedBy(0.82)
        }
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        }
    }
}

@MainActor
private final class ENTChatBubbleView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.height / 2, 18)
    }
}

@MainActor
extension ENTChatViewController: ChatViewDelegate {
    func chatViewDidRequestRetry(_ chatView: ChatView) {
        model.reloadForSessionContextChange()
    }

    func chatView(_ chatView: ChatView, didSubmit text: String) {
        sendQuestion(with: text)
    }

    func chatViewDidRequestFocus(_ chatView: ChatView) {
        chatView.focusInput()
    }

    func chatViewDidBeginVoiceInput(_ chatView: ChatView) {
        model.beginVoiceInput()
    }

    func chatView(_ chatView: ChatView, didChangeVoiceTranslation translation: CGSize) {
        model.updateVoiceInput(translation: translation)
    }

    func chatView(_ chatView: ChatView, didEndVoiceInput commit: Bool) {
        model.endVoiceInput(commit: commit)
    }

    func chatView(_ chatView: ChatView, didToggleThinking messageID: String) {
        model.toggleThinking(for: messageID)
    }

    func chatView(_ chatView: ChatView, didToggleProcessGroup groupID: String, messageID: String) {
        model.toggleProcessGroup(groupID, for: messageID)
    }

    func chatView(_ chatView: ChatView, didSelectQuestion question: String) {
        sendQuestion(with: question)
    }
}
