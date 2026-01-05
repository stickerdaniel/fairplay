import SwiftUI
import WebKit

struct ContentView: View {
    @State private var urlString = "https://duckduckgo.com"
    @State private var page = WebPage()
    @FocusState private var isURLFieldFocused: Bool
    @State private var isSanitizing = false
    @ObserveInjection var forceRedraw

    var body: some View {
        ZStack(alignment: .top) {
            // WebView
            WebView(page)
                .ignoresSafeArea(edges: .bottom)

            // Top URL Bar
            HStack(spacing: 12) {
                // Back button
                Button {
                    if let previousPage = page.backForwardList.backList.last {
                        page.load(previousPage)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(page.backForwardList.backList.isEmpty ? .tertiary : .primary)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .disabled(page.backForwardList.backList.isEmpty)

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
                        }
                    } else if page.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassEffect(in: .capsule)

                // Sanitize button (LLM dark pattern removal)
                Button {
                    sanitizePage()
                } label: {
                    Group {
                        if isSanitizing {
                            ProgressView()
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
                }
                .disabled(isSanitizing || page.isLoading)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .safeAreaPadding(.top)
        }
        .onAppear {
            loadURL()
        }
        .onChange(of: page.url) { _, newURL in
            if let newURL, !isURLFieldFocused {
                urlString = newURL.absoluteString
            }
        }
        .enableInjection()
    }

    private func loadURL() {
        let input = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

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

    private func sanitizePage() {
        isSanitizing = true

        Task {
            defer { isSanitizing = false }

            do {
                let html = try await page.callJavaScript("document.documentElement.outerHTML") as? String
                guard let html else { return }

                print("Extracted \(html.count) characters of HTML")

                // TODO: Send to LLM for dark pattern removal
                // TODO: Inject sanitized HTML back

            } catch {
                print("Failed to extract HTML: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
