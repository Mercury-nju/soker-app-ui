import UIKit
import SnapKit

extension ENTChatViewController {
    func presentAcquisitionExample() {
        view.endEditing(true)
        present(ENTAcquisitionExampleViewController(), animated: true)
    }
}

/// A design preview with sample copy and sheet-local interaction state.
@MainActor
private final class ENTAcquisitionExampleViewController: UIViewController {
    private var isSaved = false

    private lazy var saveButton = UIButton(
        configuration: actionConfiguration(title: "收藏示例", icon: "bookmark"),
        primaryAction: UIAction { [weak self] _ in self?.toggleSaved() }
    )

    private lazy var detailButton = UIButton(
        configuration: actionConfiguration(title: "查看原文示例", icon: "chevron.down"),
        primaryAction: UIAction { [weak self] _ in self?.toggleDetails() }
    )

    private lazy var details = makeLabel(
        "我在杭州，家里有两个孩子。最近想换一台七座 SUV，预算 15 万，想看看空间宽敞、能放下婴儿车的二手车。",
        style: .subheadline,
        color: ENTAppColors.primaryText
    )

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        sheetPresentationController?.detents = [.large()]
        sheetPresentationController?.prefersGrabberVisible = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = ENTAppColors.pageBackground
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 16

        let heading = makeLabel("线索示例", style: .title2, color: ENTAppColors.primaryText)
        heading.accessibilityTraits.insert(.header)
        let close = UIButton(
            configuration: actionConfiguration(title: "完成"),
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        close.setContentHuggingPriority(.required, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [heading, close])
        header.alignment = .center
        header.spacing = 12

        let card = UIView()
        card.backgroundColor = ENTAppColors.cardBackground
        card.layer.cornerRadius = 18
        let cardContent = UIStackView()
        cardContent.axis = .vertical
        cardContent.alignment = .fill
        cardContent.spacing = 10

        let source = makeLabel("抖音评论 · 2 小时前（示例）", style: .footnote, color: ENTAppColors.secondaryText)
        let quote = makeLabel("「家里两个娃，最近想换台七座 SUV。」", style: .headline, color: ENTAppColors.primaryText)
        let matchLabel = makeLabel("匹配原因", style: .footnote, color: ENTAppColors.secondaryText)
        let match = makeLabel("人在杭州，明确提到七座 SUV，正在比较二手车。", style: .subheadline, color: ENTAppColors.primaryText)
        let separator = UIView()
        separator.backgroundColor = ENTAppColors.separator
        details.isHidden = true

        [source, quote, matchLabel, match, separator, detailButton, details, saveButton].forEach {
            cardContent.addArrangedSubview($0)
        }
        cardContent.setCustomSpacing(16, after: quote)
        cardContent.setCustomSpacing(14, after: match)
        cardContent.setCustomSpacing(6, after: separator)
        content.addArrangedSubview(header)
        content.addArrangedSubview(card)
        view.addSubview(scroll)
        scroll.addSubview(content)
        card.addSubview(cardContent)

        scroll.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        content.snp.makeConstraints { make in
            make.top.bottom.equalTo(scroll.contentLayoutGuide).inset(22)
            make.leading.trailing.equalTo(scroll.contentLayoutGuide).inset(20)
            make.width.equalTo(scroll.frameLayoutGuide).offset(-40)
        }
        cardContent.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(18)
        }
        separator.snp.makeConstraints { make in
            make.height.equalTo(1)
        }
    }

    private func toggleDetails() {
        details.isHidden.toggle()
        detailButton.configuration = actionConfiguration(
            title: details.isHidden ? "查看原文示例" : "收起原文示例",
            icon: details.isHidden ? "chevron.down" : "chevron.up"
        )
    }

    private func toggleSaved() {
        isSaved.toggle()
        saveButton.configuration = actionConfiguration(
            title: isSaved ? "已收藏示例" : "收藏示例",
            icon: isSaved ? "bookmark.fill" : "bookmark"
        )
        saveButton.isSelected = isSaved
        saveButton.accessibilityHint = isSaved ? "轻点取消收藏" : nil
    }

    private func makeLabel(_ text: String, style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func actionConfiguration(title: String, icon: String? = nil) -> UIButton.Configuration {
        var configuration: UIButton.Configuration = .plain()
        configuration.title = title
        if let icon {
            configuration.image = UIImage(systemName: icon)
            configuration.imagePadding = 8
        }
        configuration.baseForegroundColor = ENTAppColors.primary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10)
        configuration.titleLineBreakMode = .byWordWrapping
        return configuration
    }
}
