import SwiftUI
import WebKit

/// WKWebView wrapper for SwiftUI with loading state tracking
struct WebView: NSViewRepresentable {
    let url: URL?
    @Binding var isLoading: Bool

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Update coordinator's binding reference
        context.coordinator.isLoading = $isLoading

        guard let url else {
            webView.loadHTMLString("<html><body><h3>No URL</h3></body></html>", baseURL: nil)
            return
        }

        // Only load if URL changed
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var isLoading: Binding<Bool>

        init(isLoading: Binding<Bool>) {
            self.isLoading = isLoading
        }

        @MainActor
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading.wrappedValue = true
        }

        @MainActor
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
        }

        @MainActor
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
            print("WebView navigation failed: \(error.localizedDescription)")
        }

        @MainActor
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
            print("WebView provisional navigation failed: \(error.localizedDescription)")
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            // Allow all navigations within the webview
            // Could add logic to open external links in Safari
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url
            {
                // Open links in external browser with Cmd+click
                if navigationAction.modifierFlags.contains(.command) {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

#Preview {
    WebView(url: URL(string: "https://example.com"), isLoading: .constant(false))
        .frame(width: 600, height: 400)
}
