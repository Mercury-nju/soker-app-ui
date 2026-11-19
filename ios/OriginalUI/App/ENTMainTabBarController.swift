import UIKit

final class ENTMainTabBarController: MainTabBarController {
    override var customTabBarHeight: CGFloat { 0 }
    override var usesLegacyTabLifecycle: Bool { false }

    override func viewDidLoad() {
        super.viewDidLoad()
        customTabBarView.onRecordButtonTapped = nil
        selectTab(.transcript)
        setMainTabBarHidden(true, animated: false)
    }

    override func setMainTabBarHidden(_ hidden: Bool, animated: Bool) {
        super.setMainTabBarHidden(true, animated: animated)
    }

    override func makeMainTabBarView() -> BeanMainTabBarView {
        ENTMainTabBarView(frame: .zero)
    }

    override func selectTab(_ tab: MainTab, popToRoot: Bool = false) {
        guard tab != .recording else { return }
        super.selectTab((tab == .deliverables || tab == .theme) ? .transcript : tab, popToRoot: popToRoot)
    }

    override func makeViewController(for tab: MainTab) -> UIViewController {
        switch tab {
        case .home:
            return ENTProfileViewController()
        case .transcript:
            return ENTChatViewController()
        case .recording, .deliverables, .theme:
            return UIViewController()
        }
    }

    override func openAudioImport(url: URL, source: AudioImportSource = .documentPicker) {}
}
