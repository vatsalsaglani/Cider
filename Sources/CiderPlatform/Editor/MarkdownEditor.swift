import SwiftUI
import WebKit

public struct MarkdownEditor: NSViewRepresentable {
    let openLink: (String) -> Void
    let fragment: String
    let text: String
    let document: URL
    let changed: (String) -> Void
    let imagePasted: (Data, String) -> Bool
    public init(text: String, document: URL, changed: @escaping (String) -> Void, imagePasted: @escaping (Data, String) -> Bool, openLink: @escaping (String) -> Void = { _ in }, fragment: String = "") {
        self.openLink = openLink; self.fragment = fragment
        self.text = text; self.document = document; self.changed = changed; self.imagePasted = imagePasted
    }
    public func makeCoordinator() -> Coordinator { Coordinator(self) }
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "editor")
        config.setURLSchemeHandler(context.coordinator, forURLScheme: "cider")
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        context.coordinator.view = view
        view.load(URLRequest(url: URL(string: "cider://document/index.html")!))
        return view
    }
    public func updateNSView(_ view: WKWebView, context: Context) { context.coordinator.parent = self }
    public static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "editor")
        view.stopLoading(); view.navigationDelegate = nil
    }
    public final class Coordinator: NSObject, WKScriptMessageHandler, WKURLSchemeHandler, WKNavigationDelegate {
        var parent: MarkdownEditor
        weak var view: WKWebView?
        init(_ parent: MarkdownEditor) { self.parent = parent }
        public func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.scheme == "cider", let value = message.body as? [String: String] else { return }
            if value["type"] == "ready" {
                Task { _ = try? await view?.callAsyncJavaScript("window.assetFolder=folder;window.loadNote(text);setTimeout(()=>window.scrollToNoteAnchor(anchor),150)", arguments: ["text": parent.text, "anchor": parent.fragment, "folder": parent.document.deletingPathExtension().lastPathComponent + ".assets"], in: nil, contentWorld: .page) }
            } else if value["type"] == "link", let href = value["href"], href.count < 8192 { parent.openLink(href)
            } else if value["type"] == "changed", let text = value["text"], text.utf8.count < 2_000_000 { parent.changed(text) }
            else if value["type"] == "image", let encoded = value["data"], encoded.count < 34_000_000, let bytes = Data(base64Encoded: encoded), let name = value["name"] { if parent.imagePasted(bytes, name) {
                Task { _ = try? await view?.callAsyncJavaScript("editor.insertValue(link)", arguments: ["link": "![Image](" + (parent.document.deletingPathExtension().lastPathComponent + ".assets/" + name).addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "/-._~")))! + ")"], in: nil, contentWorld: .page) }
            } }
        }
        public func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
            guard let url = urlSchemeTask.request.url, url.host == "document" else { urlSchemeTask.didFailWithError(URLError(.badURL)); return }
            let path = url.path
            let bundle = Bundle.main.bundleURL.appending(path: "Contents/Resources/Cider_CiderPlatform.bundle/Resources").appending(path: "editor")
            let resource = EditorResourcePolicy.isBundled(path)
            let base = resource ? bundle : parent.document.deletingLastPathComponent()
            let file = base.appending(path: String(path.dropFirst())).resolvingSymlinksInPath().standardizedFileURL
            let root = base.resolvingSymlinksInPath().standardizedFileURL.path + "/"
            guard file.path.hasPrefix(root), resource || ["png", "jpg", "jpeg", "gif", "webp"].contains(file.pathExtension.lowercased()) else { urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile)); return }
            do {
                let data = try Data(contentsOf: file)
                guard data.count < 30_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
                let types = ["html":"text/html", "js":"text/javascript", "css":"text/css", "svg":"image/svg+xml", "png":"image/png", "jpg":"image/jpeg", "jpeg":"image/jpeg", "woff2":"font/woff2"]
                urlSchemeTask.didReceive(URLResponse(url: url, mimeType: types[file.pathExtension] ?? "application/octet-stream", expectedContentLength: data.count, textEncodingName: "utf-8"))
                urlSchemeTask.didReceive(data); urlSchemeTask.didFinish()
            } catch { urlSchemeTask.didFailWithError(error) }
        }
        public func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
        public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            decisionHandler(action.request.url?.scheme == "cider" ? .allow : .cancel)
        }
    }
}

// Shared by the native scheme handler and its resource regression check.
enum EditorResourcePolicy {
    static func isBundled(_ path: String) -> Bool {
        path == "/index.html" || path == "/cider-tables.css" || path.hasPrefix("/dist/")
    }
}
