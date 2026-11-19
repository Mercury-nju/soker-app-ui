import UIKit
import Combine
import OSLog

@MainActor
final class ENTChatViewController: UIViewController, AuthSessionContentRefreshing, UIAdaptivePresentationControllerDelegate {
    let model: ENTChatViewModel
    private let chatView = ChatView()
    private var cancellables = Set<AnyCancellable>()
    private var scheduledChatRenderTask: Task<Void, Never>?
    private var pendingForceScrollToBottom = false

    private func pageTitle(for assistantName: String) -> String? {
        switch model.chatContext {
        case .global:
            return nil
        case .customer:
            return assistantName
        }
    }

    init(customerId: String? = nil) {
        let model = ENTChatViewModel(customerId: customerId)
        self.model = model
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(assistantNameDidChange),
            name: ENTAIAssistantNameStore.didChangeNotification,
            object: nil
        )
        model.preload()
    }

    override func loadView() {
        view = chatView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        chatView.delegate = self
        bindModel()
        Task { @MainActor [weak self] in
            await self?.model.load()
        }
    }

    func sendQuestion(with prompt: String) {
        let question = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        if case .global = model.chatContext {
            view.endEditing(true)
            chatView.submitAcquisition(question)
        } else {
            model.sendPromptWhenReady(question)
        }
    }

    func refreshAfterLogin() {
        model.reloadForSessionContextChange()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = pageTitle(for: model.assistantName)
        navigationItem.largeTitleDisplayMode = .never
        switch model.chatContext {
        case .global:
            navigationController?.setNavigationBarHidden(true, animated: animated)
        case .customer:
            navigationController?.setNavigationBarHidden(false, animated: animated)
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain,
                target: self,
                action: #selector(closeCustomerChat)
            )
            navigationItem.leftBarButtonItem?.accessibilityLabel = "关闭客户对话"
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard case .customer = model.chatContext,
              navigationController?.isBeingDismissed == true else { return }
        model.discardCustomerChatState()
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        model.discardCustomerChatState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        cancellables.removeAll()
        scheduledChatRenderTask?.cancel()
        let model = model
        Task { @MainActor in
            model.cancelAllTasks()
        }
    }

    @objc private func assistantNameDidChange() {
        navigationItem.title = pageTitle(for: ENTAIAssistantNameStore.name)
    }

    @objc private func closeCustomerChat() {
        model.discardCustomerChatState()
        navigationController?.dismiss(animated: true)
    }

    private func bindModel() {
        model.$messages
            .sink { [weak self] _ in self?.scheduleChatRender() }
            .store(in: &cancellables)
        model.$isLoadingSession
            .sink { [weak self] _ in self?.scheduleChatRender() }
            .store(in: &cancellables)
        model.$sessionLoadErrorMessage
            .sink { [weak self] _ in self?.scheduleChatRender() }
            .store(in: &cancellables)
        model.$isSending
            .sink { [weak self] _ in self?.scheduleChatRender() }
            .store(in: &cancellables)
        model.$sendRevision
            .sink { [weak self] _ in self?.scheduleChatRender(forceScrollToBottom: true) }
            .store(in: &cancellables)
        model.$activeAssistantID
            .sink { [weak self] _ in self?.scheduleChatRender() }
            .store(in: &cancellables)
        model.$thinkingStatusText
            .sink { [weak self] _ in self?.scheduleChatRender() }
            .store(in: &cancellables)
        model.$assistantName
            .sink { [weak self] name in
                guard let self else { return }
                navigationItem.title = pageTitle(for: name)
                scheduleChatRender()
            }
            .store(in: &cancellables)
        model.$isVoiceInputActive
            .sink { [weak self] _ in self?.scheduleChatRender() }
            .store(in: &cancellables)
        model.$voiceInputText
            .sink { [weak self] _ in self?.scheduleChatRender() }
            .store(in: &cancellables)
        model.$voiceInputCancelling
            .sink { [weak self] _ in self?.scheduleChatRender() }
            .store(in: &cancellables)
        model.$input
            .sink { [weak self] text in self?.chatView.setInputText(text) }
            .store(in: &cancellables)
        chatView.render(model: model, forceScrollToBottom: true)
    }

    private func scheduleChatRender(forceScrollToBottom: Bool = false) {
        pendingForceScrollToBottom = pendingForceScrollToBottom || forceScrollToBottom
        guard scheduledChatRenderTask == nil else { return }
        scheduledChatRenderTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self else { return }
            self.scheduledChatRenderTask = nil
            let shouldForceScroll = self.pendingForceScrollToBottom
            self.pendingForceScrollToBottom = false
            self.chatView.render(model: self.model, forceScrollToBottom: shouldForceScroll)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

nonisolated enum ENTChatStreamPhase: Sendable, Equatable {
    case thinking
    case streaming
    case completed
    case failed
}

nonisolated struct ENTChatStreamUpdate: Sendable, Equatable {
    let committedMarkdown: String
    let streamingTail: String
    let questionCards: [ENTChatQuestionCard]
    let componentSuppressed: Bool
    let thinkingText: String
    let process: ENTChatProcessState
    let statusText: String?
    let phase: ENTChatStreamPhase
    let errorMessage: String?
    let terminal: Bool
}

actor ENTChatStreamReducer {
    private var pendingEvents: [ENTAgentEvent] = []
    private var committedMarkdown = ""
    private var streamingTail = ""
    private var questionCards: [ENTChatQuestionCard] = []
    private var componentSuppressed = false
    private let answerParser = ENTChatAnswerStreamParser()
    private var thinkingText = ""
    private var process = ENTChatProcessState()
    private var statusText: String?
    private var phase: ENTChatStreamPhase = .thinking
    private var errorMessage: String?
    private var terminal = false
    private var isCancelled = false

    init(assistantID: String, usesAcquisitionPresentation: Bool = false) {
        _ = assistantID
        process.usesAcquisitionPresentation = usesAcquisitionPresentation
        process.start()
    }

    func append(event: ENTAgentEvent) {
        guard !isCancelled, !terminal else { return }
        pendingEvents.append(event)
    }

    func hasPendingEvents() -> Bool {
        !pendingEvents.isEmpty
    }

    func cancel() {
        isCancelled = true
        pendingEvents.removeAll(keepingCapacity: false)
    }

    func drain() -> ENTChatStreamUpdate? {
        guard !isCancelled, !pendingEvents.isEmpty else { return nil }
        let events = pendingEvents
        pendingEvents.removeAll(keepingCapacity: true)
        for event in events {
            reduce(event)
        }
        return ENTChatStreamUpdate(
            committedMarkdown: committedMarkdown,
            streamingTail: streamingTail,
            questionCards: questionCards,
            componentSuppressed: componentSuppressed,
            thinkingText: thinkingText,
            process: process,
            statusText: statusText,
            phase: phase,
            errorMessage: errorMessage,
            terminal: terminal
        )
    }

    private func reduce(_ event: ENTAgentEvent) {
        let result = event.data?.result?.message ?? ""
        let delta = event.data?.delta ?? ""
        let thinkingTypes = [
            "run.thinking.delta", "message.thinking.delta", "run.thinking",
            "message.thinking", "run.reasoning", "message.reasoning", "run.trace", "trace", "thinking",
            "run.started", "message.started", "context.resolved"
        ]
        let displayStatusText = [event.data?.statusText, event.data?.processStatusText, event.data?.message]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
        if let displayStatusText {
            statusText = displayStatusText
        }

        let payload = event.data?.value ?? .object([:])
        let isThinking = thinkingTypes.contains(event.type)
            || event.type == "message.delta" && ENTChatProcessState.isThinkingDelta(payload)
        if isThinking || event.type == "agent.native" {
            process.consume(payload, type: event.type)
        }
        if isThinking {
            if !delta.isEmpty { appendThinking(delta) }
            if !result.isEmpty { appendThinking(result) }
            if let displayStatusText, delta.isEmpty, result.isEmpty { appendThinking(displayStatusText) }
            // Late thinking events can update the text without reopening it over an active answer.
        } else if event.type == "message.delta", !delta.isEmpty {
            appendAssistantDelta(delta)
            process.beginAnswer()
            phase = .streaming
        }

        if event.type == "message.completed", !result.isEmpty,
           committedMarkdown.isEmpty, streamingTail.isEmpty {
            applyParsedAnswer(answerParser.finish(finalText: result))
            process.beginAnswer()
            phase = .streaming
        }
        if event.type == "run.completed", !result.isEmpty {
            applyParsedAnswer(answerParser.finish(finalText: result))
            process.beginAnswer()
            phase = .completed
        }
        if let error = event.data?.error?.message, !error.isEmpty {
            errorMessage = error
        }
        if ["run.completed", "run.failed", "run.cancelled", "run.aborted"].contains(event.type) {
            process.finish()
            if event.type == "run.completed" {
                applyParsedAnswer(answerParser.finish())
                phase = .completed
            } else {
                phase = .failed
            }
            terminal = true
        }
    }

    private func appendThinking(_ text: String) {
        guard !text.isEmpty else { return }
        if !thinkingText.isEmpty, !thinkingText.hasSuffix("\n") {
            thinkingText += "\n"
        }
        thinkingText += text
    }

    private func appendAssistantDelta(_ delta: String) {
        guard !delta.isEmpty else { return }
        let parsed = answerParser.append(delta)
        committedMarkdown = parsed.visibleMarkdown
        streamingTail = ""
        questionCards = parsed.questionCards
        componentSuppressed = parsed.componentSuppressed
    }

    private func applyParsedAnswer(_ parsed: ENTChatParseResult) {
        committedMarkdown = parsed.visibleMarkdown
        streamingTail = ""
        questionCards = parsed.questionCards
        componentSuppressed = false
    }

    private func stableMarkdownPrefix(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var boundary: String.Index?
        if let blankLine = text.range(of: "\n\n", options: .backwards) {
            boundary = blankLine.upperBound
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if let delimiterIndex = lines.firstIndex(where: { line in
            let value = line.trimmingCharacters(in: .whitespaces)
            return value.contains("|") && value.replacingOccurrences(of: "|", with: "")
                .replacingOccurrences(of: " ", with: "")
                .allSatisfy { $0 == "-" || $0 == ":" }
        }), delimiterIndex > 0, lines.count > delimiterIndex + 1 {
            let lastCompleteLine = lines.dropLast().count
            let offset = lines.prefix(lastCompleteLine).reduce(0) { $0 + $1.count + 1 }
            let tableBoundary = text.index(text.startIndex, offsetBy: min(offset, text.count))
            if boundary == nil || tableBoundary > boundary! { boundary = tableBoundary }
        }
        let fenceLines = lines.enumerated().filter { $0.element.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
        if fenceLines.count >= 2, let closing = fenceLines.last?.offset {
            let offset = lines.prefix(closing + 1).reduce(0) { $0 + $1.count + 1 }
            let fenceBoundary = text.index(text.startIndex, offsetBy: min(offset, text.count))
            if boundary == nil || fenceBoundary > boundary! { boundary = fenceBoundary }
        }

        guard let boundary else { return "" }
        return String(text[..<boundary])
    }
}

@MainActor
final class ENTChatViewModel: NSObject, ObservableObject {
    enum ChatContext {
        case global
        case customer(String)
    }
    enum MessagePhase: Equatable {
        case completed
        case thinking
        case streaming
        case failed
    }

    struct Message: Identifiable, Equatable {
        let id: String
        let role: String
        var committedMarkdown: String
        var streamingTail: String
        var questionCards: [ENTChatQuestionCard]
        var componentSuppressed: Bool
        var phase: MessagePhase
        var thinkingText: String = ""
        var isThinkingExpanded = false
        var process = ENTChatProcessState()
        var expandedProcessGroups: Set<String> = []

        var content: String {
            get {
                let text = committedMarkdown + streamingTail
                guard role.lowercased() == "assistant" else { return text }
                // Adapt legacy self-introductions at display time without changing stored history.
                return text
                    .replacingOccurrences(of: "我是小颜", with: "我是Soker")
                    .replacingOccurrences(of: "我是声单", with: "我是Soker")
            }
            set {
                committedMarkdown = newValue
                streamingTail = ""
            }
        }

        init(
            id: String,
            role: String,
            content: String,
            phase: MessagePhase,
            thinkingText: String = "",
            isThinkingExpanded: Bool = false
        ) {
            self.id = id
            self.role = role
            self.committedMarkdown = content
            self.streamingTail = ""
            self.questionCards = []
            self.componentSuppressed = false
            self.phase = phase
            self.thinkingText = thinkingText
            self.isThinkingExpanded = isThinkingExpanded
        }
    }

    @Published var messages: [Message] = []
    @Published var input = ""
    @Published var isSending = false
    @Published var thinkingStatusText = "正在理解上下文"
    @Published var activeAssistantID: String? = nil
    @Published var isLoadingSession = true
    @Published private(set) var sendRevision = 0
    @Published private(set) var streamRevision = 0
    @Published var isVoiceInputActive = false
    @Published var voiceInputText = ""
    @Published var voiceInputCancelling = false
    @Published var errorMessage: String?
    @Published private(set) var sessionLoadErrorMessage: String?
    @Published var assistantName = ENTAIAssistantNameStore.name

    private var api: ENTAgentService
    let chatContext: ChatContext
    private var speechService: SearchSpeechService?
    private var session: ENTAgentSession?
    private var loadTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    private var voiceTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var streamFlushTask: Task<Void, Never>?
    private var streamReducer: ENTChatStreamReducer?
    private var pendingPrompt: String?
    private var isAppActive = UIApplication.shared.applicationState == .active
    private var shouldReloadAfterForeground = false
    private var sessionContextGeneration = 0
    private var activeLoadGeneration: Int?
    private var activePreloadGeneration: Int?
    private static let loadLogger = AppLogger.logger(category: "ENTChat.Load")
    private static let markdownLogger = AppLogger.logger(category: "ENTChat.Markdown")


    init(customerId: String? = nil) {
        let normalizedCustomerId = customerId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let customerId: String? = normalizedCustomerId.flatMap { value in
            guard let id = Int64(value), id > 0 else { return nil }
            return value
        }
        chatContext = customerId.map(ChatContext.customer) ?? .global
        api = ENTAgentService(customerId: customerId)
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(assistantNameDidChange),
            name: ENTAIAssistantNameStore.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(chatMockSettingDidChange),
            name: ENTDebugSettingsStore.chatMockDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func assistantNameDidChange() {
        assistantName = ENTAIAssistantNameStore.name
    }

    @objc private func appWillResignActive() {
        guard isAppActive else { return }
        isAppActive = false
        AppLogger.logger(category: "ENTChat.Lifecycle").info("chat suspend begin")
        shouldReloadAfterForeground = isSending || isLoadingSession
        cancelAllTasks()
        pendingPrompt = nil
        isSending = false
        activeAssistantID = nil
        isVoiceInputActive = false
        voiceInputText = ""
        voiceInputCancelling = false
        if let speechService {
            Task {
                await speechService.cancel()
            }
        }
    }

    @objc private func appDidBecomeActive() {
        isAppActive = true
        AppLogger.logger(category: "ENTChat.Lifecycle").info("chat resumed")
        // The initial page can request loading before the app becomes active.
        let hasDeferredInitialLoad = isLoadingSession && session == nil
        guard shouldReloadAfterForeground || hasDeferredInitialLoad else { return }
        shouldReloadAfterForeground = false
        reloadForSessionContextChange()
    }

    func discardCustomerChatState() {
        guard case .customer = chatContext else { return }
        sessionContextGeneration &+= 1
        cancelAllTasks()
        loadTask = nil
        preloadTask = nil
        activeLoadGeneration = nil
        activePreloadGeneration = nil
        pendingPrompt = nil
        session = nil
        messages = []
        input = ""
        errorMessage = nil
        sessionLoadErrorMessage = nil
        isSending = false
        activeAssistantID = nil
        isLoadingSession = false
        isVoiceInputActive = false
        voiceInputText = ""
        voiceInputCancelling = false
        if let speechService {
            Task {
                await speechService.cancel()
            }
        }
    }

    @objc private func chatMockSettingDidChange() {
        guard isAppActive else { return }
        reloadForSessionContextChange()
    }

    var hasStartedChat: Bool { !messages.isEmpty || isSending }

    var visibleMessages: [Message] {
        messages.filter { message in
            let role = message.role.lowercased()
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return ["user", "assistant"].contains(role)
                && (!content.isEmpty || !message.questionCards.isEmpty || !message.process.groups.isEmpty || message.id == activeAssistantID)
                && content != "小颜"
                && content != assistantName
        }
    }

    func preload() {
        guard !usesLocalComposer else { isLoadingSession = false; return }
        guard isAppActive, session == nil, preloadTask == nil, loadTask == nil else {
            Self.loadLogger.info("preload.skip active=\(isAppActive) hasSession=\(session != nil) hasPreload=\(preloadTask != nil) hasLoad=\(loadTask != nil)")
            return
        }
        Self.loadLogger.info("preload.begin")
        let generation = sessionContextGeneration
        activePreloadGeneration = generation
        preloadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await loadSession(contextGeneration: generation)
            guard self.sessionContextGeneration == generation,
                  self.activePreloadGeneration == generation else { return }
            preloadTask = nil
            activePreloadGeneration = nil
            Self.loadLogger.info("preload.end loading=\(isLoadingSession) error=\(sessionLoadErrorMessage ?? "<none>")")
        }
    }

    func reloadForSessionContextChange() {
        guard !usesLocalComposer else { isLoadingSession = false; return }
        sessionContextGeneration &+= 1
        cancelAllTasks()
        loadTask = nil
        preloadTask = nil
        activeLoadGeneration = nil
        activePreloadGeneration = nil
        if case let .customer(customerId) = chatContext {
            api = ENTAgentService(customerId: customerId)
        } else {
            api = ENTAgentService()
        }
        session = nil
        messages = []
        errorMessage = nil
        sessionLoadErrorMessage = nil
        isSending = false
        activeAssistantID = nil
        isLoadingSession = true
        let generation = sessionContextGeneration
        activePreloadGeneration = generation
        preloadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await loadSession(contextGeneration: generation)
            guard self.sessionContextGeneration == generation,
                  self.activePreloadGeneration == generation else { return }
            preloadTask = nil
            activePreloadGeneration = nil
        }
    }

    func load() async {
        guard !usesLocalComposer else { isLoadingSession = false; return }
        Self.loadLogger.info("load.begin hasPreload=\(preloadTask != nil) hasLoad=\(loadTask != nil) loading=\(isLoadingSession)")
        let generation = sessionContextGeneration
        if let preloadTask, activePreloadGeneration == generation {
            await preloadTask.value
            guard generation == sessionContextGeneration else { return }
            if session != nil || sessionLoadErrorMessage != nil {
                Self.loadLogger.info("load.finish afterPreload session=\(session != nil) error=\(sessionLoadErrorMessage ?? "<none>") loading=\(isLoadingSession)")
                return
            }
            self.preloadTask = nil
            self.activePreloadGeneration = nil
        }
        await loadSession(contextGeneration: generation)
        Self.loadLogger.info("load.end session=\(session != nil) error=\(sessionLoadErrorMessage ?? "<none>") loading=\(isLoadingSession)")
    }

    private func loadSession(contextGeneration: Int? = nil) async {
        let contextGeneration = contextGeneration ?? sessionContextGeneration
        guard !usesLocalComposer, isAppActive,
              session == nil,
              contextGeneration == sessionContextGeneration else {
            Self.loadLogger.info("loadTask.skip active=\(isAppActive) hasSession=\(session != nil)")
            return
        }
        if let loadTask, activeLoadGeneration == contextGeneration {
            Self.loadLogger.info("loadTask.await-existing")
            await loadTask.value
            return
        }
        loadTask?.cancel()
        isLoadingSession = true
        sessionLoadErrorMessage = nil
        Self.loadLogger.info("loadTask.begin")
        activeLoadGeneration = contextGeneration
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let forceNewSession: Bool = {
                    if case .customer = self.chatContext { return false }
                    return ENTDebugSettingsStore.forceNewChatSessionAfterIndustrySwitch
                }()
                Self.loadLogger.info("session.resolve.begin forceNew=\(forceNewSession)")
                let current = try await withTimeout(seconds: 20) { [api] in
                    let storedId: String?
                    if forceNewSession {
                        storedId = nil
                    } else {
                        let existingSessions = try await api.fetchSessions()
                        storedId = existingSessions
                            .max { ($0.updatedAt ?? 0) < ($1.updatedAt ?? 0) }?
                            .sessionId
                    }
                    return try await api.createOrRestoreSession(sessionId: storedId)
                }
                Self.loadLogger.info("session.resolve.success sessionId=\(loggedSessionID(current.sessionId))")
                guard isAppActive,
                      !Task.isCancelled,
                      contextGeneration == sessionContextGeneration else { return }
                session = current
                Self.loadLogger.info("messages.fetch.begin sessionId=\(loggedSessionID(current.sessionId))")
                let fetchedMessages = try await withTimeout(seconds: 8) { [api] in
                    try await api.fetchMessages(sessionId: current.sessionId)
                }
                Self.loadLogger.info("messages.fetch.success count=\(fetchedMessages.count)")
                guard isAppActive,
                      !Task.isCancelled,
                      contextGeneration == sessionContextGeneration else { return }
                let visibleMessages: [Message] = fetchedMessages.enumerated().compactMap { offset, message in
                    // Tool/system records and protocol-only assistant markers are not chat content.
                    let role = message.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard ["user", "assistant"].contains(role),
                          !content.isEmpty,
                          content != "小颜",
                          content != self.assistantName else {
                        return nil
                    }
                    let parsed = ENTChatAnswerParser.parse(content)
                    var visibleMessage = Message(
                        id: "history-\(offset)-\(message.id)",
                        role: role,
                        content: parsed.visibleMarkdown,
                        phase: .completed
                    )
                    visibleMessage.questionCards = parsed.questionCards
                    return visibleMessage
                }
                messages = visibleMessages
            } catch is CancellationError {
                Self.loadLogger.error("loadTask.cancelled active=\(isAppActive)")
                if isAppActive, contextGeneration == sessionContextGeneration {
                    errorMessage = "聊天连接已取消，请重试"
                    sessionLoadErrorMessage = errorMessage
                    isLoadingSession = false
                }
            } catch {
                Self.loadLogger.error("loadTask.failed type=\(String(describing: type(of: error))) message=\(error.localizedDescription)")
                if isCancellationError(error) {
                    if isAppActive, contextGeneration == sessionContextGeneration {
                        errorMessage = "聊天连接已取消，请重试"
                        sessionLoadErrorMessage = errorMessage
                        isLoadingSession = false
                    }
                    return
                }
                if contextGeneration == sessionContextGeneration {
                    let message = ENTAgentService.userFacingMessage(for: error)
                    errorMessage = message
                    sessionLoadErrorMessage = message
                    isLoadingSession = false
                }
            }
            guard contextGeneration == sessionContextGeneration else { return }
            isLoadingSession = false
            Self.loadLogger.info("loadTask.finally loading=\(isLoadingSession) session=\(session != nil) error=\(sessionLoadErrorMessage ?? "<none>")")
        }
        let task = loadTask
        await task?.value
        if activeLoadGeneration == contextGeneration {
            loadTask = nil
            activeLoadGeneration = nil
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: Int,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                throw ENTAgentError.timeout
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    private func loggedSessionID(_ sessionId: String) -> String {
        if case .customer = chatContext {
            return "<customer-scoped>"
        }
        return sessionId
    }

    private var usesLocalComposer: Bool { true }

    func send(_ text: String? = nil) {
        let question = (text ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAppActive, !question.isEmpty, !isSending else { return }
        input = ""
        if usesLocalComposer {
            messages.append(Message(id: UUID().uuidString, role: "user", content: question, phase: .completed))
            messages.append(Message(id: UUID().uuidString, role: "assistant", content: "已收到你的获客需求。搜索服务接通后，可在这里查看匹配的潜客。", phase: .completed))
            return
        }
        isSending = true
        thinkingStatusText = "正在理解上下文"
        errorMessage = nil
        let assistantID = "assistant-\(UUID().uuidString)"
        activeAssistantID = assistantID
        let usesAcquisitionPresentation = switch chatContext {
        case .global: true
        case .customer: false
        }
        let reducer = ENTChatStreamReducer(assistantID: assistantID, usesAcquisitionPresentation: usesAcquisitionPresentation)
        streamReducer = reducer
        sendTask = Task { @MainActor in
            defer {
                self.isSending = false
                self.activeAssistantID = nil
                self.streamFlushTask?.cancel()
                self.streamFlushTask = nil
                self.streamReducer = nil
                self.sendTask = nil
            }
            do {
                if session == nil { await load() }
                guard let session else { throw ENTAgentError.invalidResponse("\(assistantName)会话未建立") }
                messages.append(Message(id: "user-\(UUID().uuidString)", role: "user", content: question, phase: .completed))
                var assistant = Message(id: assistantID, role: "assistant", content: "", phase: .thinking)
                assistant.process.usesAcquisitionPresentation = usesAcquisitionPresentation
                assistant.process.start()
                assistant.isThinkingExpanded = true
                messages.append(assistant)
                sendRevision += 1
                try await api.streamReply(question: question, sessionId: session.sessionId) { [weak self] event in
                    guard let self, await self.isAppActive else { return }
                    await reducer.append(event: event)
                    await self.scheduleStreamFlush(for: reducer)
                }
                streamFlushTask?.cancel()
                streamFlushTask = nil
                await flushStreamUpdates(from: reducer)
            } catch is CancellationError {
                await reducer.cancel()
            } catch {
                streamFlushTask?.cancel()
                streamFlushTask = nil
                await flushStreamUpdates(from: reducer)
                await reducer.cancel()
                if isCancellationError(error) { return }
                let message = ENTAgentService.userFacingMessage(for: error)
                errorMessage = message
                if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                    messages[index].process.finish()
                    messages[index].phase = .failed
                }
                AppToast.show(message, style: .error)
            }
        }
    }

    func cancelAllTasks() {
        if let index = messages.firstIndex(where: { $0.id == activeAssistantID }) {
            messages[index].process.finish()
            messages[index].phase = .failed
        }
        loadTask?.cancel()
        preloadTask?.cancel()
        voiceTask?.cancel()
        sendTask?.cancel()
        streamFlushTask?.cancel()
        streamFlushTask = nil
        let reducer = streamReducer
        streamReducer = nil
        Task {
            await reducer?.cancel()
        }
    }

    func sendPromptWhenReady(_ prompt: String) {
        let question = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAppActive, !question.isEmpty, !isSending else { return }
        if usesLocalComposer { send(question); return }
        pendingPrompt = question
        Task { @MainActor [weak self] in
            guard let self else { return }
            await load()
            guard pendingPrompt == question else { return }
            pendingPrompt = nil
            guard session != nil else { return }
            send(question)
        }
    }

    func beginVoiceInput() {
        guard isAppActive, !isVoiceInputActive, !isSending else { return }
        guard !usesLocalComposer else { return }
        let speechService = speechServiceIfNeeded()
        isVoiceInputActive = true
        voiceInputText = ""
        voiceInputCancelling = false
        voiceTask?.cancel()
        voiceTask = Task {
            await speechService.startListening()
        }
    }

    func updateVoiceInput(translation: CGSize) {
        guard isVoiceInputActive else { return }
        voiceInputCancelling = translation.height < -48
    }

    func endVoiceInput(commit: Bool) {
        guard isVoiceInputActive else { return }
        let shouldCommit = commit && !voiceInputCancelling
        voiceTask?.cancel()
        voiceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let text = await self.speechService?.stopListening(commit: shouldCommit) ?? ""
            isVoiceInputActive = false
            voiceInputText = ""
            voiceInputCancelling = false
            if shouldCommit, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                send(text)
            }
        }
    }

    private func speechServiceIfNeeded() -> SearchSpeechService {
        if let speechService {
            return speechService
        }

        let speechService = SearchSpeechService()
        speechService.onUpdate = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                guard let self, self.isAppActive, self.isVoiceInputActive else { return }
                self.voiceInputText = snapshot.transcriptText
            }
        }
        speechService.onUserMessage = { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self, self.isAppActive else { return }
                self.isVoiceInputActive = false
                self.voiceInputText = ""
                self.voiceInputCancelling = false
                self.errorMessage = message.message
                AppToast.show(message.message, style: .error)
            }
        }
        self.speechService = speechService
        return speechService
    }

    private func scheduleStreamFlush(for reducer: ENTChatStreamReducer) {
        guard isAppActive, streamFlushTask == nil else { return }
        streamFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            await self?.flushStreamUpdates(from: reducer)
        }
    }

    private func flushStreamUpdates(from reducer: ENTChatStreamReducer) async {
        streamFlushTask = nil
        guard let update = await reducer.drain() else { return }
        apply(update: update)
        if await reducer.hasPendingEvents() {
            scheduleStreamFlush(for: reducer)
        }
    }

    private func apply(update: ENTChatStreamUpdate) {
        guard isAppActive else { return }
        thinkingStatusText = update.statusText ?? thinkingStatusText
        if let index = messages.firstIndex(where: { $0.id == activeAssistantID }) {
            messages[index].committedMarkdown = update.committedMarkdown
            messages[index].streamingTail = update.streamingTail
            messages[index].questionCards = update.questionCards
            messages[index].componentSuppressed = update.componentSuppressed
            messages[index].thinkingText = update.thinkingText
            if !messages[index].process.replyTextStarted && update.process.replyTextStarted {
                messages[index].isThinkingExpanded = false
            }
            messages[index].process = update.process
            messages[index].phase = messagePhase(for: update.phase)
        }
        if let errorMessage = update.errorMessage, !errorMessage.isEmpty {
            self.errorMessage = errorMessage
        }
        if update.terminal, update.phase == .completed {
            let fullMarkdown = update.committedMarkdown + update.streamingTail
            if case .global = chatContext {
                Self.markdownLogger.info(
                    "run.completed fullMarkdown.begin\n\(fullMarkdown, privacy: .public)\nrun.completed fullMarkdown.end"
                )
            }
        }
        streamRevision += 1
    }

    private func messagePhase(for phase: ENTChatStreamPhase) -> MessagePhase {
        switch phase {
        case .thinking: return .thinking
        case .streaming: return .streaming
        case .completed: return .completed
        case .failed: return .failed
        }
    }

    func toggleThinking(for messageID: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].isThinkingExpanded.toggle()
    }

    func toggleProcessGroup(_ groupID: String, for messageID: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        if !messages[index].expandedProcessGroups.insert(groupID).inserted {
            messages[index].expandedProcessGroups.remove(groupID)
        }
    }


    private func isCancellationError(_ error: Error) -> Bool {
        (error as? URLError)?.code == .cancelled
    }
}
