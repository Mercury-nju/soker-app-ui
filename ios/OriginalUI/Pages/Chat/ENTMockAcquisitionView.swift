import SnapKit
import UIKit

/// The discovery reply displayed in the local acquisition conversation.
@MainActor
final class ENTMockAcquisitionTurnView: UIView {
    private typealias Fixture = ENTMockAcquisitionFixture
    private enum PendingInput {
        case target
        case revision
        case account(Fixture.AccountMode)

        var prompt: String {
            switch self {
            case .target:
                return "你想找什么样的客户？补一句他们正在做什么，比如正在咨询换窗报价。"
            case .revision:
                return "在下方修改这条找人需求，发送后按新的条件继续。"
            case let .account(mode):
                return "请发送要设为「\(mode.rawValue)」的抖音账号名或主页链接。"
            }
        }
    }

    var onLayoutChange: (() -> Void)?
    var onRequestInput: ((String) -> Void)?

    private var requirement: String
    private var account = ""
    private var accountMode: Fixture.AccountMode = .none
    private var onlySpecified = false
    private var completedSteps = 0
    private var showProcess = false
    private var expandedSteps = Set<String>()
    private var runTask: Task<Void, Never>?
    private var activityStartedAt: CFTimeInterval = 0
    private var pendingInput: PendingInput?
    private var inputHistory: [(prompt: String, answer: String)] = []
    private var expandedLeads = Set<String>()
    private let content = UIStackView()

    init(requirement: String) {
        self.requirement = requirement.trimmingCharacters(in: .whitespacesAndNewlines)
        super.init(frame: .zero)
        content.axis = .vertical
        content.spacing = 12
        addSubview(content)
        content.snp.makeConstraints { $0.edges.equalToSuperview() }
        if needsTarget {
            pendingInput = .target
            render()
        } else {
            start()
        }
    }

    deinit { runTask?.cancel() }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @discardableResult
    func consumeFollowUp(_ text: String) -> Bool {
        let answer = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pendingInput, !answer.isEmpty else { return false }

        inputHistory.append((pendingInput.prompt, answer))
        self.pendingInput = nil
        switch pendingInput {
        case .target, .revision:
            requirement = answer
        case let .account(mode):
            account = answer
            accountMode = mode
            if mode == .reference { onlySpecified = false }
        }
        if needsTarget {
            self.pendingInput = .target
        }
        start(reset: true)
        return true
    }

    private func requestInput(_ input: PendingInput, prefill: String = "") {
        pendingInput = input
        render()
        onRequestInput?(prefill)
    }

    private var fixture: Fixture {
        .make(requirement: requirement, accountMode: accountMode, account: account, onlySpecified: onlySpecified)
    }

    private var needsTarget: Bool {
        let request = requirement.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        let generalRequests = ["帮我找客户", "我想找客户", "帮我获客", "我要找客户", "我要获客", "帮我找潜客", "帮我找一些客户", "我想找一些潜在客户"]
        return request.count < 6 || generalRequests.contains(request)
    }

    private func start(reset: Bool = false) {
        runTask?.cancel()
        if reset {
            completedSteps = 0
            expandedSteps.removeAll()
            expandedLeads.removeAll()
        }
        guard !needsTarget else {
            runTask = nil
            render()
            return
        }
        let stepCount = fixture.steps.count
        activityStartedAt = CACurrentMediaTime()
        runTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(850))
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                self.completedSteps += 1
                let finished = self.completedSteps == stepCount
                if finished { self.runTask = nil }
                self.render()
                if finished { return }
            }
        }
        render()
    }

    private func render() {
        let fixture = fixture
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        defer { onLayoutChange?() }

        for entry in inputHistory {
            content.addArrangedSubview(card([label(entry.prompt, style: .subheadline)]))
            content.addArrangedSubview(userBubble(entry.answer))
        }

        content.addArrangedSubview(row(
            label("Soker", style: .subheadline, weight: .semibold),
            label("模拟数据", style: .caption1, color: ENTAppColors.secondaryText)
        ))
        var summary: UIView = label("找人需求", style: .subheadline, color: ENTAppColors.primary, weight: .semibold)
        summary = row(summary, action("修改") { [weak self] in
            guard let self else { return }
            requestInput(needsTarget ? .target : .revision, prefill: needsTarget ? "" : requirement)
        })
        var requirementRows: [UIView] = [summary, label(fixture.title, style: .title3, weight: .semibold)]
        requirementRows += [divider(), detail("地区", fixture.region)]
        if !needsTarget {
            if accountMode != .none {
                requirementRows.append(detail(accountMode.rawValue, account))
            }
            requirementRows.append(accountOptions())
            if accountMode == .specified || accountMode == .both {
                let scope = UISwitch()
                scope.isOn = onlySpecified
                scope.accessibilityLabel = "仅在这个账号查找"
                scope.addAction(UIAction { [weak self, weak scope] _ in
                    guard let self, let scope else { return }
                    onlySpecified = scope.isOn
                    start(reset: true)
                }, for: .valueChanged)
                requirementRows.append(row(label("仅在这个账号查找", style: .subheadline), scope))
            }
        }
        content.addArrangedSubview(card(requirementRows))

        if let pendingInput {
            var promptRows: [UIView] = [label(pendingInput.prompt, style: .subheadline)]
            if !needsTarget {
                promptRows.append(action("取消补充") { [weak self] in
                    self?.pendingInput = nil
                    self?.render()
                })
            }
            content.addArrangedSubview(card(promptRows))
        }
        if needsTarget { return }

        let complete = completedSteps == fixture.steps.count
        let title = label(
            complete ? "本轮查找完成" : runTask == nil ? "已暂停" : "正在查找潜客",
            style: .headline
        )
        var progressRows: [UIView] = [title]
        if !complete {
            progressRows = [row(title, action(runTask == nil ? "继续" : "暂停") { [weak self] in
                guard let self else { return }
                if self.runTask == nil {
                    self.start()
                } else {
                    self.runTask?.cancel()
                    self.runTask = nil
                    self.render()
                }
            })]
            let progress = UIProgressView(progressViewStyle: .default)
            progress.progressTintColor = ENTAppColors.primary
            progress.progress = Float(completedSteps) / Float(max(1, fixture.steps.count))
            progress.accessibilityLabel = "查找进度"
            progressRows.append(progress)
            if let current = fixture.steps.dropFirst(completedSteps).first {
                progressRows.append(runTask == nil
                    ? label(current.title, style: .subheadline, color: ENTAppColors.secondaryText)
                    : activityStatus(current.title))
            }
        }

        progressRows.append(action(showProcess ? "收起查找过程" : "查看查找过程",
                                   symbol: showProcess ? "chevron.up" : "chevron.down") { [weak self] in
            guard let self else { return }
            self.showProcess.toggle()
            self.render()
        })
        if showProcess {
            if !fixture.keywords.isEmpty {
                progressRows.append(detail("搜索词", fixture.keywords.joined(separator: "、")))
            }
            for (index, step) in fixture.steps.enumerated() {
                let finished = index < completedSteps
                progressRows.append(divider())
                progressRows.append(label(step.title, style: .subheadline, weight: .semibold))
                progressRows.append(label(finished ? step.summary : index == completedSteps ? "当前步骤" : "待处理",
                                          style: .subheadline, color: ENTAppColors.secondaryText))
                if finished {
                    let expanded = expandedSteps.contains(step.id)
                    progressRows.append(action(expanded ? "收起详情" : "查看详情",
                                               symbol: expanded ? "chevron.up" : "chevron.down") { [weak self] in
                        guard let self else { return }
                        if expanded {
                            self.expandedSteps.remove(step.id)
                        } else {
                            self.expandedSteps.insert(step.id)
                        }
                        self.render()
                    })
                    if expanded {
                        progressRows.append(label(step.detail, style: .footnote, color: ENTAppColors.secondaryText))
                    }
                }
            }
        }
        content.addArrangedSubview(card(progressRows))

        guard complete else { return }
        if fixture.leads.isEmpty {
            content.addArrangedSubview(card([
                label("本轮没有符合条件的潜客", style: .headline),
                label(fixture.emptyReason, style: .subheadline, color: ENTAppColors.secondaryText),
                row(action("修改需求") { [weak self] in
                    guard let self else { return }
                    requestInput(.revision, prefill: requirement)
                },
                    action("再跑一轮") { [weak self] in self?.start(reset: true) })
            ]))
        } else {
            content.addArrangedSubview(label("\(fixture.leads.count) 位高意向潜客", style: .title3, weight: .semibold))
            for lead in fixture.leads {
                let expanded = expandedLeads.contains(lead.id)
                var rows: [UIView] = [
                    label(lead.name, style: .headline),
                    label("“\(lead.comment)”", style: .subheadline),
                    label(lead.postedAt, style: .caption1, color: ENTAppColors.secondaryText),
                    action(expanded ? "收起证据" : "查看证据", symbol: expanded ? "chevron.up" : "chevron.down") { [weak self] in
                        guard let self else { return }
                        if !expandedLeads.insert(lead.id).inserted {
                            expandedLeads.remove(lead.id)
                        }
                        render()
                    }
                ]
                if expanded {
                    rows += [
                        divider(),
                        detail("来源作品", lead.sourceTitle),
                        detail("来源账号", lead.sourceAccount),
                        detail("上下文", lead.context),
                        detail("为什么匹配", lead.rationale)
                    ]
                }
                content.addArrangedSubview(card(rows))
            }
        }
    }

    private func activityStatus(_ text: String) -> UIView {
        let dot = UIView()
        dot.backgroundColor = .hexB8B2C5
        dot.layer.cornerRadius = 3
        dot.snp.makeConstraints { $0.size.equalTo(6) }

        // Match Chat Tab's breathe keyframes, including phase across status changes.
        if !UIAccessibility.isReduceMotionEnabled {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1
            pulse.toValue = 0.35
            pulse.duration = 0.8
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            pulse.beginTime = activityStartedAt
            dot.layer.add(pulse, forKey: "breathe")
        }

        let status = label(text, style: .caption1, color: .hex96939D)
        status.numberOfLines = 1
        status.lineBreakMode = .byTruncatingTail
        let row = UIStackView(arrangedSubviews: [dot, status])
        row.alignment = .center
        row.spacing = 9
        row.snp.makeConstraints { $0.height.greaterThanOrEqualTo(22) }
        return row
    }

    private func accountOptions() -> UIButton {
        let button = action(accountMode == .none ? "补充抖音账号" : "调整账号用途", symbol: "chevron.down") {}
        button.showsMenuAsPrimaryAction = true
        button.menu = UIMenu(children: Fixture.AccountMode.allCases.map { mode in
            UIAction(title: mode.rawValue, state: mode == accountMode ? .on : .off) { [weak self] _ in
                guard let self else { return }
                if mode == .none {
                    accountMode = .none
                    account = ""
                    onlySpecified = false
                    pendingInput = nil
                    start(reset: true)
                } else if let currentAccount = account.isEmpty ? nil : account {
                    requestInput(.account(mode), prefill: currentAccount)
                } else {
                    requestInput(.account(mode))
                }
            }
        })
        return button
    }

    private func userBubble(_ text: String) -> UIView {
        let wrapper = UIView()
        let message = label(text, style: .subheadline, color: .white)
        let bubble = UIStackView(arrangedSubviews: [message])
        bubble.isLayoutMarginsRelativeArrangement = true
        bubble.layoutMargins = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        bubble.backgroundColor = ENTAppColors.primary
        bubble.layer.cornerRadius = 16
        bubble.layer.cornerCurve = .continuous
        wrapper.addSubview(bubble)
        bubble.snp.makeConstraints {
            $0.top.trailing.bottom.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview().offset(36)
        }
        return wrapper
    }

    private func card(_ rows: [UIView]) -> UIView {
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.backgroundColor = ENTAppColors.cardBackground
        stack.layer.cornerRadius = 18
        stack.layer.cornerCurve = .continuous
        return stack
    }

    private func row(_ start: UIView, _ end: UIView) -> UIView {
        let row = UIStackView(arrangedSubviews: [start, UIView(), end])
        row.alignment = .center
        row.spacing = 8
        end.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    private func label(_ text: String, style: UIFont.TextStyle,
                       color: UIColor? = nil, weight: UIFont.Weight? = nil) -> UILabel {
        let label = UILabel()
        label.text = text
        let font = UIFont.preferredFont(forTextStyle: style)
        label.font = weight.map { UIFont.systemFont(ofSize: font.pointSize, weight: $0) } ?? font
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color ?? ENTAppColors.primaryText
        label.numberOfLines = 0
        return label
    }

    private func detail(_ title: String, _ value: String) -> UIView {
        let stack = UIStackView(arrangedSubviews: [
            label(title, style: .caption1, color: ENTAppColors.secondaryText),
            label(value, style: .subheadline)
        ])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    private func divider() -> UIView {
        let line = UIView()
        line.backgroundColor = ENTAppColors.separator
        line.snp.makeConstraints { $0.height.equalTo(1 / UIScreen.main.scale) }
        return line
    }

    private func action(_ title: String, filled: Bool = false, symbol: String? = nil,
                        handler: @escaping () -> Void) -> UIButton {
        var configuration: UIButton.Configuration = filled ? .filled() : .plain()
        configuration.title = title
        configuration.image = symbol.flatMap { UIImage(systemName: $0) }
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        configuration.baseForegroundColor = filled ? .white : ENTAppColors.primary
        if filled { configuration.baseBackgroundColor = ENTAppColors.primary }
        configuration.preferredSymbolConfigurationForImage = .init(scale: .small)
        configuration.contentInsets = .init(top: 8, leading: 0, bottom: 8, trailing: 0)
        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in handler() })
        button.contentHorizontalAlignment = filled ? .center : .leading
        button.snp.makeConstraints { $0.height.greaterThanOrEqualTo(36) }
        return button
    }
}

private extension UIColor {
    static let hexB8B2C5 = UIColor(hex: 0xB8B2C5)
    static let hex96939D = UIColor(hex: 0x96939D)
}
