import Foundation
import WebKit

@Observable
@MainActor
final class WebPage {
    var url: URL?
    var isLoading = false

    private(set) weak var webView: WKWebView?

    var backForwardList: WKBackForwardList? {
        webView?.backForwardList
    }

    var canGoBack: Bool {
        webView?.canGoBack ?? false
    }

    var canGoForward: Bool {
        webView?.canGoForward ?? false
    }

    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    func load(_ request: URLRequest) {
        webView?.load(request)
    }

    func load(_ item: WKBackForwardListItem) {
        webView?.go(to: item)
    }

    func callJavaScript(_ script: String) async throws -> Any? {
        guard let webView else {
            throw WebPageError.webViewNotInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

enum WebPageError: LocalizedError {
    case webViewNotInitialized

    var errorDescription: String? {
        switch self {
        case .webViewNotInitialized:
            return "WebView not initialized"
        }
    }
}
