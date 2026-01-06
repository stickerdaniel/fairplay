import SwiftUI
import WebKit

struct ContentView: View {
    @State private var urlString = ""
    @State private var page = WebPage()
    @FocusState private var isURLFieldFocused: Bool
    @State private var darkPatternVM: DarkPatternViewModel
    @ObserveInjection var forceRedraw

    // Sheet state
    @State private var showDebugHTML = false
    @State private var showDebugResponse = false
    @State private var showReasoningAlert = false
    @State private var showErrorAlert = false
    @State private var showSettings = false

    let llmService: LLMService

    init(llmService: LLMService) {
        self.llmService = llmService

        // Create scanner and modifier based on mock mode toggle
        let scanner: DarkPatternScannerProtocol
        let modifier: PatternModifierProtocol

        if LLMService.useMockData {
            scanner = MockDarkPatternScanner()
            modifier = MockPatternModifier()
        } else {
            scanner = DarkPatternLLMScanner(llmService: llmService)
            modifier = DarkPatternLLMModifier(llmService: llmService)
        }

        _darkPatternVM = State(initialValue: DarkPatternViewModel(scanner: scanner, modifier: modifier))
    }

    var body: some View {
        ZStack(alignment: .top) {
            // WebView
            WebView(page)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .bottomTrailing) {
                    rightSideButtons
                        .padding()
                        .safeAreaPadding(.bottom)
                }

            // Top URL Bar
            HStack(spacing: 12) {
                // Back button
                Button {
                    if let previousPage = page.backForwardList?.backItem {
                        page.load(previousPage)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(page.canGoBack ? .primary : .tertiary)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .disabled(!page.canGoBack)

                // URL Bar
                HStack(spacing: 8) {
                    TextField("Search or enter website", text: $urlString)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .focused($isURLFieldFocused)
                        .onSubmit {
                            loadURL()
                            isURLFieldFocused = false
                        }

                    if !urlString.isEmpty && isURLFieldFocused {
                        Button {
                            urlString = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, -8)
                    } else if page.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassEffect(in: .capsule)

                // Dark Pattern Scanner Button
                scannerButton
            }
            .padding(.horizontal)
            .safeAreaPadding(.top)
        }
        .onAppear {
            loadURL()
        }
        .onChange(of: page.url) { _, newURL in
            // Reset scan state for new page
            darkPatternVM.resetForNewPage()

            if let newURL, !isURLFieldFocused {
                // Show empty URL bar for DuckDuckGo landing page only (not search results)
                let isDuckDuckGoHome = newURL.host?.contains("duckduckgo.com") == true &&
                                       (newURL.query == nil || newURL.query?.isEmpty == true)
                if isDuckDuckGoHome {
                    urlString = ""
                } else {
                    urlString = newURL.absoluteString
                }
            }
        }
        .onChange(of: page.isLoading) { wasLoading, isLoading in
            // Trigger scan when page finishes loading
            if wasLoading && !isLoading {
                Task {
                    await scanCurrentPage()
                }
            }
        }
        .sheet(isPresented: $darkPatternVM.isSheetPresented) {
            DarkPatternsSheet(viewModel: darkPatternVM)
        }
        .sheet(isPresented: $showDebugHTML) {
            DebugTextSheet(
                title: "HTML Sent to LLM",
                content: darkPatternVM.debugHTMLSent,
                htmlPercentage: darkPatternVM.originalHTMLSize > 0
                    ? (darkPatternVM.sentHTMLSize * 100) / darkPatternVM.originalHTMLSize
                    : 0,
                chunkAttempts: darkPatternVM.chunkAttempts
            )
        }
        .sheet(isPresented: $showDebugResponse) {
            DebugTextSheet(
                title: "LLM Response",
                content: darkPatternVM.debugLLMResponse,
                showBackendBadge: true,
                usedBackend: darkPatternVM.usedBackend,
                usedMLXModel: darkPatternVM.usedMLXModel
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(llmService: llmService)
        }
        .alert("No Dark Patterns Found", isPresented: $showReasoningAlert) {
            Button("OK") {}
        } message: {
            Text(darkPatternVM.reasoning)
        }
        .alert("Scan Failed", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            if case .error(let errorMessage) = darkPatternVM.scanState {
                Text(errorMessage)
            }
        }
        .enableInjection()
    }

    @ViewBuilder
    private var scannerButton: some View {
        Button {
            switch darkPatternVM.scanState {
            case .patternsFound:
                darkPatternVM.isSheetPresented = true
            case .safe:
                showReasoningAlert = true
            case .error:
                showErrorAlert = true
            default:
                break
            }
        } label: {
            Group {
                if page.url == nil {
                    // No page loaded yet - show paused
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if page.isLoading {
                    // Page loading - show hourglass
                    Image(systemName: "hourglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    switch darkPatternVM.scanState {
                    case .idle, .scanning:
                        // Page loaded, now analyzing
                        ProgressView()

                    case .safe:
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.green)

                    case .patternsFound:
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .medium))

                            // Badge showing pattern count
                            if darkPatternVM.patterns.count > 0 {
                                Text("\(darkPatternVM.patterns.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(.red, in: .circle)
                                    .offset(x: 8, y: -8)
                            }
                        }

                    case .error:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.orange)

                    case .excluded:
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .disabled(page.isLoading ||
                  page.url == nil ||
                  darkPatternVM.scanState == .idle ||
                  darkPatternVM.scanState == .scanning ||
                  darkPatternVM.scanState == .excluded)
    }

    @ViewBuilder
    private var rightSideButtons: some View {
        VStack(spacing: 12) {
            // HTML Debug
            Button {
                showDebugHTML = true
            } label: {
                Image(systemName: "doc.text")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .disabled(darkPatternVM.debugHTMLSent.isEmpty)

            // LLM Response Debug
            Button {
                showDebugResponse = true
            } label: {
                Image(systemName: "text.bubble")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .disabled(darkPatternVM.debugLLMResponse.isEmpty)

            // Settings
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
        }
    }

    private func loadURL() {
        let input = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty input = go to DuckDuckGo homepage
        if input.isEmpty {
            if let url = URL(string: "https://duckduckgo.com") {
                page.load(URLRequest(url: url))
            }
            return
        }

        let url: URL?

        if looksLikeURL(input) {
            var urlString = input
            if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                urlString = "https://" + urlString
            }
            url = URL(string: urlString)
        } else {
            let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            url = URL(string: "https://duckduckgo.com/?q=\(encoded)")
        }

        if let url {
            page.load(URLRequest(url: url))
        }
    }

    private func looksLikeURL(_ input: String) -> Bool {
        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            return true
        }
        return input.contains(".") && !input.contains(" ")
    }

    private func shouldExcludeFromScanning(_ url: URL?) -> Bool {
        guard let host = url?.host else { return true }
        return host.contains("duckduckgo.com")
    }

    private func scanCurrentPage() async {
        // Check if page should be excluded from scanning
        guard !shouldExcludeFromScanning(page.url) else {
            darkPatternVM.scanState = .excluded
            return
        }

        // Retry up to 3 times with increasing delays
        for attempt in 1...3 {
            try? await Task.sleep(for: .milliseconds(500 * attempt))

            do {
                let result = try await page.callJavaScript("document.documentElement.outerHTML")

                if let html = result as? String, !html.isEmpty {
                    print("[ContentView] Got HTML on attempt \(attempt), length: \(html.count)")
                    await darkPatternVM.scanPage(html: html)
                    return
                }
            } catch {
                print("[ContentView] Attempt \(attempt) failed: \(error)")
            }
        }

        print("[ContentView] All attempts failed, marking as safe")
        darkPatternVM.scanState = .safe
    }
}

#Preview {
    ContentView(llmService: LLMService())
}
