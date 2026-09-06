import AppKit
import WebKit

@main @MainActor final class Probe: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKURLSchemeHandler {
    static func main() { let app = NSApplication.shared; let delegate = Probe(); app.delegate = delegate; app.run() }
    var web: WKWebView!
    var window: NSWindow!
    var started = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(self, forURLScheme: "cider")
        config.userContentController.add(self, name: "editor")
        config.userContentController.add(self, name: "probe")
        config.userContentController.addUserScript(WKUserScript(source: "window.addEventListener('error',e=>window.webkit.messageHandlers.probe.postMessage(String(e.message)));window.addEventListener('unhandledrejection',e=>window.webkit.messageHandlers.probe.postMessage(String(e.reason)));document.addEventListener('securitypolicyviolation',e=>window.webkit.messageHandlers.probe.postMessage(e.violatedDirective+':'+e.blockedURI));", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame: CGRect(x:0,y:0,width:900,height:700), configuration: config)
        window = NSWindow(contentRect:web.frame,styleMask:[.titled],backing:.buffered,defer:false); window.contentView=web; window.orderFront(nil)
        web.load(URLRequest(url:URL(string:"cider://document/index.html")!))
        Task { try? await Task.sleep(for:.seconds(45)); print("TIMEOUT"); exit(2) }
    }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "probe" { print("JS:", message.body); return }
        guard let payload = message.body as? [String:String], payload["type"] == "ready", !started else { return }; started=true
        Task { await run() }
    }
    func expect(_ expression: String, _ label: String) async throws {
        for _ in 0..<80 {
            if (try await web.evaluateJavaScript(expression)) as? Bool == true { print("PASS: \(label)"); return }
            try await Task.sleep(for: .milliseconds(50))
        }
        print("FAIL: \(label)"); exit(1)
    }
    func run() async {
        do {
            _ = try await web.callAsyncJavaScript("window.loadNote(text)", arguments: ["text": "[Example](docs/example.md)"], in: nil, contentWorld: .page)
            try await expect("window.ciderLinkTarget(document.querySelector('.vditor-ir__link'))==='docs/example.md'", "editing-mode relative link resolves")
            try await expect("editor.getValue().includes('[Example](docs/example.md)')", "link source preserved")
            let table = "| Entity | Essential fields |\n| :--- | ---: |\n| Workspace | UUID, name, ordered root IDs, preferences |\n| FolderRoot | bookmark/access locator and a long field " + String(repeating: "LongIdentifier", count: 30) + " |\n"
            _ = try await web.callAsyncJavaScript("window.loadNote(text);window.tableSource=editor.getValue()", arguments: ["text": table], in: nil, contentWorld: .page)
            try await expect("document.querySelectorAll('.vditor-reset table tbody tr').length===2", "Markdown table renders rows")
            try await expect("getComputedStyle(document.querySelector('tbody tr')).backgroundColor==='rgb(21, 21, 22)' && getComputedStyle(document.querySelector('tbody tr:nth-child(2)')).backgroundColor==='rgb(28, 26, 25)'", "table rows use dark surfaces")
            try await expect("getComputedStyle(document.querySelector('th')).color==='rgb(255, 211, 173)' && getComputedStyle(document.querySelector('td')).color==='rgb(245, 242, 237)'", "table text has readable Cider colors")
            try await expect("getComputedStyle(document.querySelector('td')).whiteSpace==='normal' && document.querySelector('table').getBoundingClientRect().right <= innerWidth", "long table content wraps inside editor")
            try await expect("editor.getValue()===window.tableSource && editor.getValue().includes('LongIdentifier')", "table styling preserves Markdown")
            if let bitmap = try await web.takeSnapshot(configuration: nil).tiffRepresentation,
               let png = NSBitmapImageRep(data: bitmap)?.representation(using: .png, properties: [:]) {
                try png.write(to: URL(fileURLWithPath: "output/qa/editor-table.png"))
            }
            let source = "# Test\n\n```mermaid\nflowchart TD\n A[Start] --> B[Receive Request]\n B --> C[Process Request]\n C --> D[Validate Result]\n D --> E[Return Response]\n E --> F[End]\n```\n"
            _ = try await web.callAsyncJavaScript("window.loadNote(text);window.original=text", arguments: ["text": source], in: nil, contentWorld: .page)
            try await expect("document.querySelectorAll('.language-mermaid svg').length===1", "loaded six-node diagram")
            try await expect("document.querySelector('.language-mermaid svg').innerHTML.includes('#38271f')", "Cider theme applied")
            try await expect("editor.getValue()===window.original", "original Markdown preserved")
            _ = try await web.evaluateJavaScript("editor.focus();var area=document.querySelector('.vditor-ir [contenteditable=true]');var r=document.createRange();r.selectNodeContents(area);r.collapse(false);window.getSelection().removeAllRanges();window.getSelection().addRange(r)")
            let addition = "\n```mermaid\nflowchart LR\n X[New] --> Y[Diagram]\n```\n"
            _ = try await web.callAsyncJavaScript("editor.insertValue(text);window.addition=text", arguments: ["text": addition], in: nil, contentWorld: .page)
            try await expect("document.querySelectorAll('.language-mermaid svg').length===2", "new diagram during editing")
            try await expect("editor.getValue()===window.original+window.addition", "insertion preserves both Markdown blocks")
            _ = try await web.callAsyncJavaScript("window.loadNote(text)", arguments: ["text": "```mermaid\nflowchart TD\n A[\n```\n"], in: nil, contentWorld: .page)
            try await expect("document.querySelectorAll('.cider-diagram-error').length===1", "invalid syntax shows recoverable error")
            try await expect("editor.getValue().includes(' A[')", "invalid source is retained")
            _ = try await web.callAsyncJavaScript("window.loadNote(text);window.loadNote(text);window.loadNote(text)", arguments: ["text": source], in: nil, contentWorld: .page)
            try await expect("document.querySelectorAll('.language-mermaid svg').length===1 && !document.querySelector('.cider-diagram-error')", "rapid refresh and correction recover")
            try await expect("editor.getValue()===window.original", "rapid refresh preserves source")
        } catch { print("ERROR", error); exit(1) }
        exit(0)
    }
    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        let url=task.request.url!
        let base=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appending(path:"Sources/CiderPlatform/Resources/editor")
        do { let file=base.appending(path:String(url.path.dropFirst()));let data=try Data(contentsOf:file)
            let types=["js":"text/javascript","css":"text/css","html":"text/html","svg":"image/svg+xml"]
            task.didReceive(URLResponse(url:url,mimeType:types[file.pathExtension] ?? "application/octet-stream",expectedContentLength:data.count,textEncodingName:"utf-8"));task.didReceive(data);task.didFinish()
        } catch { print("RESOURCE",url.path);task.didFailWithError(error) }
    }
    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
