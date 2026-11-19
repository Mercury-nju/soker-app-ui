#if DEBUG
import SnapKit
import UIKit

@MainActor
final class ENTDouyinSMSPreviewView: UIView {
    private let onVerified: () -> Void
    private let demoCode: String
    private let field = UITextField()
    private let slots = (0..<6).map { _ in UILabel() }
    private let feedback = UILabel()
    private var didVerify = false

    init(demoCode: String, onVerified: @escaping () -> Void) {
        self.demoCode = demoCode
        self.onVerified = onVerified
        super.init(frame: .zero)

        let title = UILabel()
        title.text = "输入短信验证码"
        title.font = .bold(ofSize: 26)
        title.accessibilityTraits.insert(.header)
        title.numberOfLines = 0
        let subtitle = UILabel()
        subtitle.text = "流程预览 · 请输入示例验证码 \(demoCode)"
        subtitle.font = .regular(ofSize: 16)
        subtitle.textColor = ENTAppColors.secondaryText
        subtitle.numberOfLines = 0

        let digits = UIStackView(arrangedSubviews: slots)
        digits.distribution = .fillEqually
        digits.spacing = 7
        digits.isUserInteractionEnabled = false
        for slot in slots {
            slot.textAlignment = .center
            slot.font = .monospacedDigitSystemFont(ofSize: 24, weight: .semibold)
            slot.layer.cornerRadius = 12
            slot.clipsToBounds = true
            slot.isAccessibilityElement = false
        }

        let input = UIView()
        field.keyboardType = .numberPad
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.textColor = .clear
        field.tintColor = .clear
        field.accessibilityLabel = "六位示例验证码"
        field.addTarget(self, action: #selector(codeChanged), for: .editingChanged)
        field.addTarget(self, action: #selector(updateSlots), for: [.editingDidBegin, .editingDidEnd])
        input.addSubview(field)
        input.addSubview(digits)
        field.snp.makeConstraints { $0.edges.equalToSuperview() }
        digits.snp.makeConstraints { $0.edges.equalToSuperview() }
        input.snp.makeConstraints { $0.height.equalTo(54) }

        feedback.font = .regular(ofSize: 14)
        feedback.textColor = ENTAppColors.error
        feedback.numberOfLines = 0
        feedback.snp.makeConstraints { $0.height.greaterThanOrEqualTo(18) }

        let stack = UIStackView(arrangedSubviews: [title, subtitle, input, feedback])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(30, after: subtitle)
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.trailing.equalToSuperview().inset(3)
        }
        updateSlots()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func focusCode() {
        field.becomeFirstResponder()
    }

    @objc private func codeChanged() {
        guard !didVerify else { return }
        let code = String((field.text ?? "").filter { "0123456789".contains($0) }.prefix(slots.count))
        if field.text != code { field.text = code }
        feedback.text = nil
        if code.count == slots.count {
            if code == demoCode {
                didVerify = true
                field.resignFirstResponder()
                onVerified()
                return
            }
            field.text = ""
            feedback.text = "示例验证码不正确，请重新输入"
            UIAccessibility.post(notification: .announcement, argument: feedback.text)
        }
        updateSlots()
    }

    @objc private func updateSlots() {
        let digits = Array(field.text ?? "")
        for (index, slot) in slots.enumerated() {
            let active = field.isFirstResponder && index == digits.count
            slot.text = index < digits.count ? String(digits[index]) : (active ? "│" : nil)
            slot.textColor = active ? ENTAppColors.primary : ENTAppColors.primaryText
            slot.backgroundColor = active ? ENTAppColors.primary.withAlphaComponent(0.12) : ENTAppColors.controlBackground
        }
    }

}
#endif
