import SnapKit
import UIKit

@MainActor
final class ENTDouyinAuthorizationSuccessViewController: UIViewController {
    private let onFinish: () -> Void
    private var transitionTask: Task<Void, Never>?

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard transitionTask == nil else { return }
        UIAccessibility.post(notification: .announcement, argument: "授权成功")
        transitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_450_000_000)
            guard !Task.isCancelled else { return }
            self?.onFinish()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        transitionTask?.cancel()
        transitionTask = nil
    }

    private func setupUI() {
        view.backgroundColor = ENTAppColors.pageBackground.withAlphaComponent(0.9)
        view.isOpaque = false
        let artwork = UIImageView(image: UIImage(named: "DouyinAuthorizationArtwork"))
        artwork.contentMode = .scaleToFill
        let title = UILabel()
        title.text = "授权成功"
        title.font = .bold(ofSize: 36)
        title.textColor = .black
        title.accessibilityTraits = .header

        let subtitle = UILabel()
        subtitle.text = "抖音账号已完成授权"
        subtitle.font = .regular(ofSize: 20)
        subtitle.textColor = UIColor(hex: 0x153252)

        let copy = UIStackView(arrangedSubviews: [title, subtitle])
        copy.axis = .vertical
        copy.alignment = .center
        copy.spacing = 12
        view.addSubview(artwork)
        view.addSubview(copy)
        let artworkTop = UILayoutGuide()
        view.addLayoutGuide(artworkTop)
        artworkTop.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(view.snp.height).multipliedBy(86.0 / 1792.0)
        }
        artwork.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(artworkTop.snp.bottom)
            make.height.equalTo(view.snp.height).multipliedBy(954.0 / 1792.0)
        }
        copy.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(artwork.snp.bottom).offset(5)
        }

    }
}
