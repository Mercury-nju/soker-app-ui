import UIKit
import SnapKit

@MainActor
final class ENTChatProcessView: UIView {
    // MARK: - Private Properties

    private var process = ENTChatProcessState()
    private var timer: Timer?
    private var expanded = false

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateTimer()
    }

    // MARK: - UI Components

    private lazy var expandedDisclosureImage = makeDisclosureImage(expanded: true)
    private lazy var collapsedDisclosureImage = makeDisclosureImage(expanded: false)

    private lazy var stack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        view.spacing = 10
        return view
    }()

    private lazy var clockButton: UIButton = {
        makeDisclosureButton()
    }()

    private lazy var detailStack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        view.spacing = 10
        return view
    }()

    private lazy var acquisitionStatus: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = ENTAppColors.secondaryText
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
}

extension ENTChatProcessView {
    func configure(
        process: ENTChatProcessState,
        expanded: Bool,
        expandedGroups: Set<String>,
        fallbackStatus: String,
        active: Bool,
        onToggle: @escaping () -> Void,
        onToggleGroup: @escaping (String) -> Void
    ) {
        self.process = process
        self.expanded = expanded
        if process.usesAcquisitionPresentation {
            isHidden = !active || process.replyTextStarted
            clockButton.isHidden = true
            detailStack.isHidden = true
            acquisitionStatus.isHidden = isHidden
            let completed = process.completedAcquisitionStepCount
            acquisitionStatus.text = completed > 0 ? "已完成 \(completed) 项处理" : "正在处理请求…"
            updateTimer()
            return
        }
        isHidden = false
        acquisitionStatus.isHidden = true
        clockButton.removeAction(identifiedBy: UIAction.Identifier("toggle"), for: .touchUpInside)
        clockButton.addAction(UIAction(identifier: UIAction.Identifier("toggle")) { _ in onToggle() }, for: .touchUpInside)
        clockButton.isHidden = process.startedAt == nil && process.durationSeconds == nil
        clockButton.isEnabled = process.replyTextStarted
        clockButton.accessibilityLabel = expanded ? "收起处理过程" : "展开处理过程"
        detailStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        detailStack.isHidden = process.replyTextStarted && !expanded
        for group in process.groups {
            let isOpen = expandedGroups.contains(group.id)
            let button = makeDisclosureButton()
            button.setTitle(group.title, for: .normal)
            button.setImage(isOpen ? expandedDisclosureImage : collapsedDisclosureImage, for: .normal)
            button.tintColor = ENTAppColors.secondaryText
            button.accessibilityLabel = "\(isOpen ? "收起" : "展开")\(group.title)"
            button.addAction(UIAction { _ in onToggleGroup(group.id) }, for: .touchUpInside)
            detailStack.addArrangedSubview(button)
            if isOpen {
                for step in group.steps {
                    let text = ([step.isThinking ? "" : step.statusDetail]
                        + step.previousFailures.map { "前次失败：\($0)" }
                        + [step.detail]
                        + (step.toolInput.isEmpty ? [] : ["调用参数\n\(step.toolInput)"])
                        + (step.toolResult.isEmpty ? [] : ["工具结果\n\(step.toolResult)"]))
                        .filter { !$0.isEmpty }.joined(separator: "\n")
                    let label = UILabel()
                    label.numberOfLines = 0
                    label.font = .regular(ofSize: 14)
                    label.textColor = ENTAppColors.secondaryText
                    label.text = text
                    label.setContentCompressionResistancePriority(.required, for: .vertical)
                    detailStack.addArrangedSubview(label)
                }
            }
        }
        if active && !process.replyTextStarted && !process.steps.contains(where: \.isActive) {
            let label = UILabel()
            label.numberOfLines = 0
            label.font = .regular(ofSize: 15)
            label.textColor = ENTAppColors.secondaryText
            label.text = process.groups.isEmpty ? (process.statusText ?? fallbackStatus) : "正在思考"
            detailStack.addArrangedSubview(label)
        }
        if !active && !expandedGroups.isEmpty && !process.groups.isEmpty {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
            button.contentHorizontalAlignment = .leading
            button.tintColor = ENTAppColors.secondaryText
            button.accessibilityLabel = "复制处理过程"
            let text = process.groups.flatMap { $0.steps }.map { step in
                [step.title, step.statusDetail, step.detail, step.toolInput, step.toolResult]
                    .filter { !$0.isEmpty }.joined(separator: "\n")
            }.joined(separator: "\n\n")
            button.addAction(UIAction { _ in
                UIPasteboard.general.string = text
                AppToast.show("消息已复制", style: .success)
            }, for: .touchUpInside)
            detailStack.addArrangedSubview(button)
        }
        updateClock()
        updateTimer()
    }
}

private extension ENTChatProcessView {
    func makeDisclosureImage(expanded: Bool) -> UIImage? {
        guard let symbol = UIImage(
            systemName: "chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12)
        ) else { return nil }
        // A shared square canvas keeps the title origin unchanged when the arrow rotates.
        return UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            context.cgContext.translateBy(x: 8, y: 8)
            if !expanded { context.cgContext.rotate(by: -.pi / 2) }
            symbol.draw(in: CGRect(
                x: -symbol.size.width / 2, y: -symbol.size.height / 2,
                width: symbol.size.width, height: symbol.size.height
            ))
        }.withRenderingMode(.alwaysTemplate)
    }

    func makeDisclosureButton() -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = .zero
        configuration.imagePadding = 8
        configuration.baseForegroundColor = ENTAppColors.secondaryText
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .regular(ofSize: 14)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        return button
    }

    func setupUI() {
        self += [stack]
        stack.addArrangedSubview(clockButton)
        stack.addArrangedSubview(detailStack)
        stack.addArrangedSubview(acquisitionStatus)
        stack.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalToSuperview()
        }
    }

    func updateTimer() {
        timer?.invalidate()
        timer = nil
        guard window != nil, !process.usesAcquisitionPresentation,
              process.startedAt != nil, process.durationSeconds == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateClock() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func updateClock() {
        let seconds = process.elapsedSeconds()
        let duration: String
        if seconds < 60 { duration = "\(seconds) 秒" }
        else if seconds % 60 == 0 { duration = "\(seconds / 60) 分钟" }
        else { duration = "\(seconds / 60) 分钟 \(seconds % 60) 秒" }
        clockButton.setTitle("已思考 \(duration)", for: .normal)
        clockButton.setImage(
            process.replyTextStarted ? (expanded ? expandedDisclosureImage : collapsedDisclosureImage) : nil,
            for: .normal
        )
        clockButton.tintColor = ENTAppColors.secondaryText
    }
}
