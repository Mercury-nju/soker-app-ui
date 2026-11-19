import SwiftUI
import WebKit

@main
struct SokerApp: App {
    @StateObject private var chat = ChatBridge()

    var body: some Scene {
        WindowGroup {
            WebSurface(chat: chat)
                .ignoresSafeArea(.container)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if chat.ready && !chat.menuOpen {
                        HStack(spacing: 10) {
                            TextField(chat.reviewing ? "你想看哪位客户的朋友圈？" : "描述你想找的客户", text: $chat.draft)
                                .onSubmit(chat.send)
                            Button(action: chat.send) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 26))
                            }
                            .accessibilityLabel("发送")
                            .disabled(chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }
                }
                .alert("此功能需要企业服务", isPresented: $chat.showServiceMessage) {
                    Button("好", role: .cancel) {}
                }
        }
    }
}

struct WebSurface: UIViewRepresentable {
    let chat: ChatBridge

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        for name in ChatBridge.messageNames {
            configuration.userContentController.add(chat, name: name)
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        chat.webView = webView
        webView.load(URLRequest(url: chat.demoURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

@MainActor
final class ChatBridge: NSObject, ObservableObject, WKScriptMessageHandler {
    static let messageNames = ["sokerAcquisitionReady", "sokerAcquisitionInput", "sokerChatMode", "sokerAccountMenu"]

    @Published var draft = ""
    @Published var ready = false
    @Published var reviewing = false
    @Published var menuOpen = false
    @Published var showServiceMessage = false
    weak var webView: WKWebView?
    private var drafts: [Bool: String] = [:]

    let demoURL: URL = {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--demo-url"),
           arguments.indices.contains(index + 1),
           let url = URL(string: arguments[index + 1]),
           url.scheme == "https" || (url.scheme == "http" && url.host == "127.0.0.1") {
            return url
        }
        return URL(string: "http://127.0.0.1:3131/chat-tab?mode=acquisition&embedded=1")!
    }()

    func send() {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, let webView else { return }
        draft = ""
        Task {
            _ = try? await webView.callAsyncJavaScript(
                "window.dispatchEvent(new CustomEvent('soker-acquisition-submit', { detail: message }));",
                arguments: ["message": message],
                in: nil,
                contentWorld: .page
            )
        }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url == demoURL else { return }
        switch message.name {
        case "sokerAcquisitionReady":
            ready = true
        case "sokerAcquisitionInput":
            if let input = message.body as? String { draft = input }
        case "sokerChatMode":
            let nextMode = message.body as? String == "review"
            if nextMode != reviewing {
                drafts[reviewing] = draft
                reviewing = nextMode
                draft = drafts[nextMode] ?? ""
            }
        case "sokerAccountMenu":
            switch message.body as? String {
            case "open": menuOpen = true
            case "close": menuOpen = false
            case "notificationSettings":
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            default: showServiceMessage = true
            }
        default:
            break
        }
    }
}
