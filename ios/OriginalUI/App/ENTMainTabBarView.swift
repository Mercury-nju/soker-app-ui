import UIKit

enum ENTAIAssistantNameStore {
    static let defaultName = "Soker"
    static let didChangeNotification = Notification.Name("ENT.AIAssistantNameDidChange")

    static var name: String {
        let storedName = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let storedName, !storedName.isEmpty,
              !["AI", "小颜", "声单", "声单AI"].contains(storedName) else {
            return defaultName
        }
        return storedName
    }

    static func save(_ name: String) {
        UserDefaults.standard.set(name, forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private static let key = AppRuntime.identifier("enterprise.aiAssistantName")
}

final class ENTMainTabBarView: BeanMainTabBarView {
    static let capsuleHorizontalInset: CGFloat = 16
    static let capsuleMaximumWidth: CGFloat = 450

    override var tabBarItemWidth: CGFloat { max(0, capsuleFrame.width - 24) / CGFloat(tabBarTabs.count) }
    override var tabBarItemHeight: CGFloat { 60 }
    override var tabBarIconSize: CGFloat { 20 }
    override var tabBarIconTop: CGFloat { 10 }
    override var tabBarTitleTop: CGFloat { 32 }
    override var tabBarTabs: [MainTab] { [.transcript, .home] }
    override var recordButtonAvoidanceSize: CGFloat { 0 }
    override var recordButtonIsVisible: Bool { false }
    override var usesCurvedBackground: Bool { false }
    override var tabBarBackgroundColor: UIColor { .clear }
    override var tabBarBackgroundShadowOpacity: Float { 0 }

    private var capsuleFrame: CGRect {
        let width = min(Self.capsuleMaximumWidth, max(0, bounds.width - 2 * Self.capsuleHorizontalInset))
        let bottom = max(10, safeAreaInsets.bottom + 5)
        return CGRect(x: bounds.midX - width / 2, y: bounds.maxY - bottom - 60, width: width, height: 60)
    }

    private lazy var glassView: UIVisualEffectView = {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            effect = UIGlassEffect(style: .regular)
        } else {
            effect = UIBlurEffect(style: .systemMaterial)
        }
        let view = UIVisualEffectView(effect: effect)
        view.isUserInteractionEnabled = false
        if #available(iOS 26.0, *) {
            view.cornerConfiguration = .capsule()
        } else {
            view.layer.cornerRadius = 30
            view.clipsToBounds = true
        }
        return view
    }()

    override var visualFrameInSuperview: CGRect {
        guard let superview else { return frame }
        return convert(capsuleFrame, to: superview)
    }

    override var recordButtonFrameInSuperview: CGRect {
        .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let capsule = capsuleFrame
        if glassView.superview == nil {
            insertSubview(glassView, at: 0)
        }
        glassView.frame = capsule
        for (index, control) in tabItemControls.enumerated() {
            control.frame.origin = CGPoint(x: capsule.minX + 12 + tabBarItemWidth * CGFloat(index), y: capsule.minY)
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        super.point(inside: point, with: event)
            && UIBezierPath(roundedRect: capsuleFrame, cornerRadius: 30).contains(point)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    override func tabBarTitle(for tab: MainTab) -> String {
        switch tab {
        case .home:
            return "我的"
        case .transcript:
            return "获客"
        case .deliverables:
            return "客户"
        case .theme:
            return "盘客"
        case .recording:
            return "录音"
        }
    }

    override func tabBarImage(for tab: MainTab, selected: Bool) -> UIImage? {
        let assetName: String?
        switch tab {
        case .home:
            return UIImage(
                systemName: selected ? "person.fill" : "person",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: tabBarIconSize, weight: .medium)
            )?.withTintColor(
                selected ? ENTAppColors.primaryText : ENTAppColors.tertiaryText,
                renderingMode: .alwaysOriginal
            )
        case .transcript:
            assetName = "ENTNavCoHear"
        case .deliverables:
            assetName = "ENTNavChat"
        case .theme:
            return UIImage(
                systemName: "waveform",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: tabBarIconSize, weight: .medium)
            )?.withTintColor(
                selected ? ENTAppColors.primaryText : ENTAppColors.tertiaryText,
                renderingMode: .alwaysOriginal
            )
        case .recording:
            assetName = nil
        }

        guard let assetName, let image = UIImage(named: assetName) else {
            return nil
        }
        let color = selected ? ENTAppColors.primaryText : ENTAppColors.tertiaryText
        return image.withTintColor(color, renderingMode: .alwaysOriginal)
    }

    override func tabBarTitleColor(for tab: MainTab, selected: Bool) -> UIColor {
        selected ? ENTAppColors.primaryText : ENTAppColors.tertiaryText
    }
}
