import WebKit

@Observable
class BrowserViewModel {
    var urlText: String = "https://www.google.com"
    var pageTitle: String = ""
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var isLoading: Bool = false
    var estimatedProgress: Double = 0

    weak var webView: WKWebView?
    private var isPushingFrame: Bool = false

    func loadURL() {
        var text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if !text.contains("://") {
            if text.contains(".") && !text.contains(" ") {
                text = "https://\(text)"
            } else {
                let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
                text = "https://www.google.com/search?q=\(q)"
            }
        }

        guard let url = URL(string: text) else { return }
        webView?.load(URLRequest(url: url))
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func stopLoading() { webView?.stopLoading() }

    func pushFrame(_ jpegData: Data) {
        guard let webView, !isPushingFrame else { return }
        isPushingFrame = true

        let base64 = jpegData.base64EncodedString()
        let js = "window.__vcam_pushFrame&&window.__vcam_pushFrame('\(base64)')"

        webView.evaluateJavaScript(js) { [weak self] _, _ in
            self?.isPushingFrame = false
        }
    }
}
