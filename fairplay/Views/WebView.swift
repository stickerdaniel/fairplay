import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @Bindable var page: WebPage

    init(_ page: WebPage) {
        self.page = page
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Connect webView to page model
        page.setWebView(webView)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Updates handled via page model
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(page: page)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let page: WebPage

        init(page: WebPage) {
            self.page = page
        }

        @MainActor
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            page.isLoading = true
        }

        @MainActor
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            page.url = webView.url
        }

        @MainActor
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            page.isLoading = false
            page.url = webView.url
        }

        @MainActor
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            page.isLoading = false
        }

        @MainActor
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            page.isLoading = false
        }
    }
}
