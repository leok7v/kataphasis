import SwiftUI
import WebKit

let agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
    "AppleWebKit/605.1.15 (KHTML, like Gecko) " +
    "Version/18.0 Safari/605.1.15"

let rules = """
    [{"trigger": {"url-filter": ".*", "load-type": ["third-party"]},
      "action": {"type": "block-cookies"}},
     {"trigger": {"url-filter": ".*", "resource-type": ["media"]},
      "action": {"type": "block"}}]
    """

let gpc = """
    Object.defineProperty(Navigator.prototype, "globalPrivacyControl",
        { get: () => true });
    """

let extractor = #"""
    const head = "h1, h2, h3, h4, h5, h6, [role=heading]";
    const exits = ["/url", "/goto", "/l/"];
    const clean = (s) => (s ?? "").replace(/\s+/g, " ").trim();
    const lines = (e) => e.innerText.split("\n").map(clean).filter(
        (s) => s.length > 1);
    const crumb = (s) => s.includes("\u203a") ||
        /^(https?:\/\/)?[^\s\/]+\.[a-z]{2,}(\/\S*)?$/i.test(s);
    const outward = (a) => a.protocol.startsWith("http") &&
        (a.host !== location.host ||
         exits.some((p) => a.pathname.startsWith(p)));
    const heading = (a) => a.querySelector(head) ?? a.closest(head);
    const found = () => Array.from(
        document.querySelectorAll("a[href]")
    ).filter((a) => outward(a) && heading(a) !== null &&
                    clean(heading(a).innerText) !== "");
    const settle = () => new Promise((done) => {
        const tick = (last, still, left) => {
            const n = found().length;
            const calm = n === last && n > 0 ? still + 1 : 0;
            if (calm >= 3 || left === 0) {
                done();
            } else {
                setTimeout(() => tick(n, calm, left - 1), 200);
            }
        };
        tick(-1, 0, 40);
    });
    await settle();
    const links = found();
    const alone = (e) => links.filter((a) => e.contains(a)).length === 1;
    const small = (e) => clean(e.innerText).length < 1500;
    const block = (a) => {
        let b = a;
        while (b.parentElement !== null &&
               b.parentElement !== document.body &&
               alone(b.parentElement) && small(b.parentElement)) {
            b = b.parentElement;
        }
        return b;
    };
    const others = (b, a) => Array.from(b.querySelectorAll("a")).filter(
        (x) => !x.contains(a) && !a.contains(x)
    ).map((x) => clean(x.innerText)).filter((t) => t.length > 0);
    const trim = (s, tails) => tails.reduce(
        (x, t) => x.length > t.length && x.endsWith(t) ?
            clean(x.slice(0, -t.length)) : x, s);
    const hit = (a) => {
        const own = new Set(lines(a));
        const title = clean(heading(a).innerText);
        const b = block(a);
        const tails = others(b, a);
        const rest = lines(b).map((s) => trim(s, tails)).filter(
            (s) => s.length > 1 && s !== title && !own.has(s));
        const body = rest.filter((s) => !crumb(s));
        return {
            url: a.href,
            title: title,
            site: [...own, ...rest].find(crumb) ?? "",
            short: body.reduce((x, s) => s.length > x.length ? s : x, ""),
            long: body.join("\n")
        };
    };
    return links.map(hit);
    """#

let pager = #"""
    const clean = (s) => (s ?? "").replace(/\s+/g, " ").trim();
    const label = (e) => clean(e.value || e.innerText ||
        e.getAttribute("aria-label"));
    const next = document.querySelector("a[rel=next]") ?? Array.from(
        document.querySelectorAll("a[href], input[type=submit], button")
    ).find((e) => /^(next|next page|more results)$/i.test(label(e)) ||
                   e.id === "pnnext");
    if (next instanceof HTMLAnchorElement) {
        location.assign(next.href);
    } else if (next) {
        next.click();
    }
    return next !== undefined && next !== null;
    """#

let reader = #"""
    const clean = (s) => (s ?? "").replace(/\s+/g, " ").trim();
    const text = (e) => clean(e.innerText);
    const meta = (k) => clean(document.querySelector(
        `meta[name="${k}"], meta[property="${k}"]`)?.content);
    const size = () => (document.body?.innerText ?? "").length;
    const settle = () => new Promise((done) => {
        const tick = (last, still, left) => {
            const n = size();
            const calm = n === last && n > 0 ? still + 1 : 0;
            if (calm >= 2 || left === 0) {
                done();
            } else {
                setTimeout(() => tick(n, calm, left - 1), 250);
            }
        };
        tick(-1, 0, 20);
    });
    await settle();
    const skip = "nav, header, footer, aside, form, dialog, " +
        "[role=navigation], [role=banner], [role=contentinfo], " +
        "[aria-hidden=true]";
    const parts = "h1, h2, h3, h4, h5, h6, p, li, pre, blockquote";
    const score = new Map();
    const add = (e, n) => {
        if (e) {
            score.set(e, (score.get(e) ?? 0) + n);
        }
    };
    Array.from(document.querySelectorAll("p")).filter(
        (p) => p.closest(skip) === null && text(p).length >= 40
    ).forEach((p) => {
        add(p.parentElement, text(p).length);
        add(p.parentElement?.parentElement, text(p).length / 2);
    });
    const root = document.querySelector("article, main, [role=main]") ??
        document.body;
    const best = [...score.entries()].reduce(
        (x, e) => e[1] > x[1] ? e : x, [root, 0])[0];
    const outer = (e) => {
        const up = e.parentElement?.closest(parts);
        return !up || !best.contains(up);
    };
    const seen = new Set();
    const lines = Array.from(best.querySelectorAll(parts)).filter(
        (e) => outer(e) && (e.closest(skip) === null ||
                            best.closest(skip) !== null)
    ).map(text).filter(
        (s) => s.length > 1 && !seen.has(s) && seen.add(s));
    const long = (lines.length > 0 ? lines.join("\n") : text(best))
        .slice(0, 20000);
    return {
        title: meta("og:title") || clean(document.title),
        short: meta("description") || meta("og:description") ||
            (lines.find((s) => s.length >= 80) ?? long.slice(0, 300)),
        long: long
    };
    """#

let sheet = """
    :root { color-scheme: light dark;
            font: 14px -apple-system, sans-serif; }
    body { margin: 16px; }
    h1 { font-size: 18px; }
    details { border-bottom: 1px solid #8884; padding: 8px 0; }
    summary { cursor: pointer; }
    a { font-weight: 600; text-decoration: none; }
    .s { display: block; font-size: 12px; opacity: .6; }
    .d { display: block; margin-top: 4px; }
    section { margin: 8px 0 0 16px; }
    h4 { margin: 12px 0 4px; font-size: 11px; opacity: .6;
         text-transform: uppercase; }
    p { margin: 4px 0; line-height: 1.45; }
    """

let desk = NSSize(width: 1280, height: 1280)
let readers = 3
let patience = 8.0

enum Engine: String, CaseIterable, Identifiable {
    case ddg = "DuckDuckGo"
    case google = "Google"
    var id: String { rawValue }
}

struct Page: Sendable {
    let title: String
    let short: String
    let long: String
}

enum Visit: Sendable {
    case pending
    case failed
    case read(Page)
}

struct Hit: Identifiable, Sendable {
    let url: URL
    let title: String
    let site: String
    let short: String
    let long: String
    var visit = Visit.pending
    var id: URL { url }
}

final class Halt: NSObject, URLSessionTaskDelegate {
    func urlSession(_: URLSession, task _: URLSessionTask,
                    willPerformHTTPRedirection _: HTTPURLResponse,
                    newRequest _: URLRequest) async -> URLRequest? {
        nil
    }
}

let quiet = URLSession(configuration: .ephemeral, delegate: Halt(),
                       delegateQueue: nil)

func searchURL(_ engine: Engine, _ query: String) -> URL? {
    var c = URLComponents()
    c.scheme = "https"
    c.queryItems = [URLQueryItem(name: "q", value: query)]
    if engine == .ddg {
        c.host = "html.duckduckgo.com"
        c.path = "/html/"
        c.queryItems?.append(URLQueryItem(name: "kl", value: "wt-wt"))
    } else {
        c.host = "www.google.com"
        c.path = "/search"
        c.queryItems?.append(URLQueryItem(name: "pws", value: "0"))
        c.queryItems?.append(URLQueryItem(name: "udm", value: "14"))
    }
    return c.url
}

func webURL(_ text: String) -> URL? {
    var out: URL? = nil
    if let u = URL(string: text), let s = u.scheme,
       s == "http" || s == "https" {
        out = u
    }
    return out
}

func engineHost(_ url: URL) -> Bool {
    let host = url.host ?? ""
    return host == "google.com" || host.hasSuffix(".google.com") ||
        host.hasSuffix("duckduckgo.com")
}

func redirectKey(_ host: String, _ path: String) -> String? {
    var key: String? = nil
    if host.hasSuffix("google.com") && path == "/url" {
        key = "q"
    } else if host.hasSuffix("duckduckgo.com") && path == "/l/" {
        key = "uddg"
    }
    return key
}

func unwrap(_ url: URL) -> URL? {
    var out: URL? = nil
    let c = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let key = redirectKey(c?.host ?? "", c?.path ?? "")
    if let key,
       let item = c?.queryItems?.first(where: { item in item.name == key }),
       let v = item.value {
        out = webURL(v)
    }
    return out
}

func landing(_ url: URL) async -> URL {
    var req = URLRequest(url: url)
    req.setValue(agent, forHTTPHeaderField: "User-Agent")
    let reply = try? await quiet.data(for: req)
    let http = reply?.1 as? HTTPURLResponse
    let location = http?.value(forHTTPHeaderField: "Location") ?? ""
    return webURL(location) ?? url
}

func destination(_ url: URL) async -> URL {
    var out = unwrap(url) ?? url
    if engineHost(out) {
        out = await landing(out)
    }
    return out
}

func resolved(_ h: Hit) async -> Hit {
    let url = await destination(h.url)
    let site = h.site.isEmpty ? url.host ?? "" : h.site
    return Hit(url: url, title: h.title, site: site, short: h.short,
               long: h.long)
}

func resolveAll(_ found: [Hit]) async -> [Hit] {
    var out = found
    await withTaskGroup(of: (Int, Hit).self) { group in
        for (i, h) in found.enumerated() {
            group.addTask { (i, await resolved(h)) }
        }
        for await (i, h) in group {
            out[i] = h
        }
    }
    return out.filter { h in !engineHost(h.url) }
}

func hit(_ row: [String: String]) -> Hit? {
    var out: Hit? = nil
    if let url = webURL(row["url"] ?? "") {
        out = Hit(url: url, title: row["title"] ?? "",
                  site: row["site"] ?? "", short: row["short"] ?? "",
                  long: row["long"] ?? "")
    }
    return out
}

func parseHits(_ raw: Any?) -> [Hit] {
    let rows = raw as? [[String: String]] ?? []
    return rows.compactMap(hit)
}

func parsePage(_ raw: Any?) -> Page? {
    var out: Page? = nil
    if let row = raw as? [String: String], let long = row["long"],
       !long.isEmpty {
        out = Page(title: row["title"] ?? "", short: row["short"] ?? "",
                   long: long)
    }
    return out
}

func escape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

func paragraphs(_ s: String) -> String {
    s.split(separator: "\n").map { p in "<p>\(escape(String(p)))</p>" }
        .joined()
}

func brief(_ h: Hit) -> String {
    var out = h.short
    if case .read(let p) = h.visit, !p.short.isEmpty {
        out = p.short
    }
    return out
}

func content(_ v: Visit) -> String {
    var out = "<p>Not read yet.</p>"
    switch v {
    case .pending:
        break
    case .failed:
        out = "<p>The page could not be read.</p>"
    case .read(let p):
        out = paragraphs(p.long)
    }
    return out
}

func entry(_ h: Hit) -> String {
    let url = escape(h.url.absoluteString)
    return "<details><summary><a href=\"\(url)\">\(escape(h.title))</a>" +
        "<span class=s>\(url)</span>" +
        "<span class=d>\(escape(brief(h)))</span></summary><section>" +
        "<h4>Search result</h4>\(paragraphs(h.long))" +
        "<h4>Page</h4>\(content(h.visit))</section></details>"
}

func report(_ query: String, _ hits: [Hit]) -> String {
    "<!doctype html><html><head><meta charset=utf-8>" +
        "<meta http-equiv=\"Content-Security-Policy\" " +
        "content=\"default-src 'none'; style-src 'unsafe-inline'\">" +
        "<title>\(escape(query))</title><style>\(sheet)</style>" +
        "</head><body><h1>\(escape(query))</h1>" +
        hits.map(entry).joined() + "</body></html>"
}

@MainActor
func blockTrackersAndMedia(_ ucc: WKUserContentController) {
    WKContentRuleListStore.default().compileContentRuleList(
        forIdentifier: "no-third-party-cookies-no-media",
        encodedContentRuleList: rules
    ) { list, _ in
        if let list {
            ucc.add(list)
        }
    }
}

@MainActor
func hidden(_ store: WKWebsiteDataStore) -> WKWebView {
    let cfg = WKWebViewConfiguration()
    cfg.websiteDataStore = store
    cfg.mediaTypesRequiringUserActionForPlayback = .all
    cfg.userContentController.addUserScript(WKUserScript(
        source: gpc, injectionTime: .atDocumentStart,
        forMainFrameOnly: false))
    blockTrackersAndMedia(cfg.userContentController)
    let view = WKWebView(frame: NSRect(origin: .zero, size: desk),
                         configuration: cfg)
    view.customUserAgent = agent
    return view
}

@MainActor
func wipe(_ store: WKWebsiteDataStore) {
    let all = WKWebsiteDataStore.allWebsiteDataTypes()
    store.removeData(ofTypes: all, modifiedSince: .distantPast) {}
}

@MainActor
final class Visitor: NSObject, WKNavigationDelegate {
    let view: WKWebView
    private var waiting: CheckedContinuation<Void, Never>?
    private var visit = 0
    private var job = 0
    init(_ store: WKWebsiteDataStore) {
        view = hidden(store)
        super.init()
        view.navigationDelegate = self
    }
    func read(_ url: URL) async -> Page? {
        job += 1
        let n = job
        Task {
            try? await Task.sleep(for: .seconds(patience * 3))
            if n == job {
                view.loadHTMLString("", baseURL: nil)
            }
        }
        let page = await fetch(url)
        job += 1
        return page
    }
    private func fetch(_ url: URL) async -> Page? {
        var req = URLRequest(url: url)
        req.setValue("1", forHTTPHeaderField: "Sec-GPC")
        view.load(req)
        await settle()
        var page = await scrape()
        if page == nil && view.isLoading {
            await settle()
            page = await scrape()
        }
        return page
    }
    func stop() {
        view.stopLoading()
        finish()
    }
    private func settle() async {
        visit += 1
        let n = visit
        Task {
            try? await Task.sleep(for: .seconds(patience))
            if n == visit {
                finish()
            }
        }
        await withCheckedContinuation { c in waiting = c }
    }
    private func finish() {
        let w = waiting
        waiting = nil
        w?.resume()
    }
    private func scrape() async -> Page? {
        let raw = try? await view.callAsyncJavaScript(
            reader, arguments: [:], in: nil, contentWorld: .defaultClient)
        return parsePage(raw)
    }
    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        finish()
    }
    func webView(_: WKWebView, didFail _: WKNavigation!,
                 withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled {
            finish()
        }
    }
    func webView(_: WKWebView,
                 didFailProvisionalNavigation _: WKNavigation!,
                 withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled {
            finish()
        }
    }
}

@MainActor
final class Paper: NSObject, WKNavigationDelegate {
    let view: WKWebView
    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = false
        view = WKWebView(frame: .zero, configuration: cfg)
        super.init()
        view.navigationDelegate = self
    }
    func show(_ html: String) {
        view.loadHTMLString(html, baseURL: nil)
    }
    func webView(_: WKWebView,
                 decidePolicyFor action: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        var policy = WKNavigationActionPolicy.allow
        if action.navigationType == .linkActivated,
           let url = action.request.url {
            policy = .cancel
            NSWorkspace.shared.open(url)
        }
        return policy
    }
}

@MainActor
final class Browser: NSObject, ObservableObject, WKNavigationDelegate {
    let view: WKWebView
    let away: WKWebsiteDataStore
    let visitors: [Visitor]
    let paper = Paper()
    @Published var hits: [Hit] = []
    @Published var busy = false
    @Published var working: [Bool]
    @Published var status = ""
    private var query = ""
    private var engine = Engine.ddg
    private var want = 0
    private var page = 0
    private var queue: [URL] = []
    override init() {
        let store = WKWebsiteDataStore.nonPersistent()
        view = hidden(.nonPersistent())
        away = store
        visitors = (0..<readers).map { _ in Visitor(store) }
        working = Array(repeating: false, count: readers)
        super.init()
        view.navigationDelegate = self
    }
    var reading: Bool { working.contains(true) }
    var read: Int {
        hits.filter { h in
            if case .pending = h.visit { false } else { true }
        }.count
    }
    func search(_ e: Engine, _ q: String, _ limit: Int) {
        engine = e
        query = q
        want = limit
        page = 0
        hits = []
        queue = []
        status = ""
        busy = !q.isEmpty
        if busy, let url = searchURL(e, q) {
            load(url)
        }
    }
    func open(_ url: URL) {
        query = url.absoluteString
        want = 1
        page = 0
        busy = false
        queue = []
        status = url.host ?? ""
        hits = [Hit(url: url, title: url.host ?? query, site: query,
                    short: "", long: "")]
        enqueue([url])
    }
    func more(_ limit: Int) {
        want = hits.count + limit
        busy = true
        turn()
    }
    func forget() {
        busy = false
        hits = []
        queue = []
        status = ""
        view.stopLoading()
        visitors.forEach { v in v.stop() }
        wipe(view.configuration.websiteDataStore)
        wipe(away)
        view.loadHTMLString("", baseURL: nil)
        paper.show("")
    }
    private func load(_ url: URL) {
        var req = URLRequest(url: url)
        req.setValue("1", forHTTPHeaderField: "Sec-GPC")
        view.load(req)
    }
    private func harvest() {
        let key = (query, engine, page)
        Task {
            let found = await extract()
            if key == (query, engine, page) {
                take(found)
            }
        }
    }
    private func extract() async -> [Hit]? {
        var out: [Hit]? = nil
        do {
            let raw = try await view.callAsyncJavaScript(
                extractor, arguments: [:], in: nil,
                contentWorld: .defaultClient)
            out = await resolveAll(parseHits(raw))
        } catch {
            status = view.isLoading ? status : error.localizedDescription
        }
        return out
    }
    private func take(_ found: [Hit]?) {
        if let found {
            merge(found)
        } else {
            busy = view.isLoading
        }
    }
    private func merge(_ found: [Hit]) {
        var seen = Set(hits.map { h in h.url })
        let novel = found.filter { h in seen.insert(h.url).inserted }
        let fresh = Array(novel.prefix(max(want - hits.count, 0)))
        hits += fresh
        page += 1
        busy = !novel.isEmpty && hits.count < want
        status = summary(novel.isEmpty)
        enqueue(fresh.map { h in h.url })
        if busy {
            turn()
        }
        publish()
    }
    private func summary(_ dry: Bool) -> String {
        let path = view.url?.path ?? ""
        var s = "\(hits.count) results, \(page) pages"
        if dry && path.hasPrefix("/sorry") {
            s = "Google asks for a captcha"
        } else if dry && hits.isEmpty {
            s = "No results"
        }
        return s
    }
    private func turn() {
        let key = (query, engine, page)
        Task {
            let raw = try? await view.callAsyncJavaScript(
                pager, arguments: [:], in: nil,
                contentWorld: .defaultClient)
            if raw as? Bool != true && key == (query, engine, page) {
                busy = false
                publish()
            }
        }
    }
    private func enqueue(_ urls: [URL]) {
        queue += urls
        for i in visitors.indices where !working[i] && !queue.isEmpty {
            working[i] = true
            Task { await drain(i) }
        }
    }
    private func drain(_ i: Int) async {
        while !queue.isEmpty {
            let url = queue.removeFirst()
            let page = await visitors[i].read(url)
            record(url, page)
        }
        working[i] = false
        publish()
    }
    private func record(_ url: URL, _ page: Page?) {
        if let i = hits.firstIndex(where: { h in h.url == url }) {
            hits[i].visit = page.map { p in Visit.read(p) } ?? .failed
        }
    }
    private func publish() {
        if !busy && !reading {
            paper.show(report(query, hits))
        }
    }
    private func failed(_ error: Error) {
        let cancelled = (error as NSError).code == NSURLErrorCancelled
        busy = busy && cancelled
        if !cancelled {
            status = error.localizedDescription
            publish()
        }
    }
    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        if busy {
            harvest()
        }
    }
    func webView(_: WKWebView, didFail _: WKNavigation!,
                 withError error: Error) {
        failed(error)
    }
    func webView(_: WKWebView,
                 didFailProvisionalNavigation _: WKNavigation!,
                 withError error: Error) {
        failed(error)
    }
}

final class Stamp: NSView {
    init(_ web: WKWebView) {
        super.init(frame: NSRect(origin: .zero, size: desk))
        web.frame = NSRect(origin: .zero, size: desk)
        addSubview(web)
    }
    required init?(coder _: NSCoder) {
        nil
    }
    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        setBoundsSize(desk)
    }
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}

struct StampView: NSViewRepresentable {
    let view: WKWebView
    func makeNSView(context _: Context) -> Stamp { Stamp(view) }
    func updateNSView(_: Stamp, context _: Context) {}
}

struct PaperView: NSViewRepresentable {
    let view: WKWebView
    func makeNSView(context _: Context) -> WKWebView { view }
    func updateNSView(_: WKWebView, context _: Context) {}
}

struct ContentView: View {
    @StateObject private var browser = Browser()
    @State private var text = ""
    @State private var query = ""
    @State private var limit = "10"
    @State private var engine = Engine.ddg
    @State private var selected: URL?
    @State private var peek = false
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ZStack(alignment: .bottomTrailing) {
                HSplitView {
                    results
                        .frame(minWidth: 260, idealWidth: 340)
                    detail
                        .frame(minWidth: 260, idealWidth: 400)
                    PaperView(view: browser.paper.view)
                        .frame(minWidth: 300, idealWidth: 460)
                }
                stamps
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .onChange(of: engine) { rerun() }
    }
    private var count: Int { max(Int(limit) ?? 10, 1) }
    private var chosen: Hit? {
        browser.hits.first { h in h.id == selected }
    }
    private var toolbar: some View {
        HStack {
            Picker("", selection: $engine) {
                ForEach(Engine.allCases) { e in Text(e.rawValue).tag(e) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            TextField("Search, or https:// address", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(go)
            TextField("10", text: $limit)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 48)
                .help("Results to retrieve before More results")
                .onSubmit(go)
            Text(browser.status)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(browser.read) of \(browser.hits.count) read")
                .foregroundStyle(.secondary)
                .opacity(browser.hits.isEmpty ? 0 : 1)
            Button { peek.toggle() } label: {
                Image(systemName: peek ? "eye" : "eye.slash")
            }
            .help("Show page thumbnails while pages load")
            Button(action: forget) { Image(systemName: "flame") }
                .help("Forget cookies, cache and storage")
        }
        .padding(8)
    }
    private var results: some View {
        List(selection: $selected) {
            ForEach(browser.hits) { h in row(h).tag(h.url) }
            if !query.isEmpty && !browser.hits.isEmpty && !browser.busy {
                Button("More results") { browser.more(count) }
            }
        }
    }
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let h = chosen {
                    sheet(h)
                } else {
                    Text("Select a result")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .textSelection(.enabled)
    }
    private var stamps: some View {
        HStack(spacing: 8) {
            stamp(browser.view, browser.busy)
            ForEach(browser.visitors.indices, id: \.self) { i in
                stamp(browser.visitors[i].view, browser.working[i])
            }
        }
        .padding(16)
        .allowsHitTesting(false)
    }
    private func stamp(_ view: WKWebView, _ on: Bool) -> some View {
        StampView(view: view)
            .frame(width: 128, height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(.separator))
            .shadow(radius: 6)
            .opacity(peek && on ? 1 : 0)
    }
    private func row(_ h: Hit) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(h.title)
                    .font(.headline)
                Text(h.site)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(h.short)
                    .lineLimit(2)
            }
            Spacer()
            mark(h.visit)
        }
        .padding(.vertical, 4)
    }
    private func mark(_ v: Visit) -> some View {
        var name = "clock"
        switch v {
        case .pending:
            break
        case .failed:
            name = "xmark.circle"
        case .read:
            name = "doc.text"
        }
        return Image(systemName: name).foregroundStyle(.secondary)
    }
    @ViewBuilder
    private func sheet(_ h: Hit) -> some View {
        Link(h.title, destination: h.url)
            .font(.title3.bold())
        Text(h.url.absoluteString)
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("Search result")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        Text(h.short)
        Text(h.long)
            .foregroundStyle(.secondary)
            .opacity(h.long == h.short ? 0 : 1)
        Text("Page")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        pageText(h.visit)
    }
    @ViewBuilder
    private func pageText(_ v: Visit) -> some View {
        switch v {
        case .pending:
            Text("Not read yet.")
                .foregroundStyle(.secondary)
        case .failed:
            Text("The page could not be read.")
                .foregroundStyle(.secondary)
        case .read(let p):
            Text(p.title).bold()
            Text(p.short)
            Text(p.long)
                .foregroundStyle(.secondary)
        }
    }
    private func go() {
        if let url = webURL(text) {
            query = ""
            browser.open(url)
            selected = url
        } else {
            query = text
            browser.search(engine, query, count)
        }
    }
    private func rerun() {
        if !query.isEmpty {
            browser.search(engine, query, count)
        }
    }
    private func forget() {
        browser.forget()
        text = ""
        query = ""
        selected = nil
    }
}

@MainActor
func front() {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate()
}

@main
struct KataphasisApp: App {
    var body: some Scene {
        WindowGroup("Kataphasis") {
            ContentView().onAppear(perform: front)
        }
    }
}
