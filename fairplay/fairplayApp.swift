import SwiftUI
#if DEBUG
@_exported import Inject
#endif

@main
struct fairplayApp: App {
    @State private var llmService = LLMService()

    init() {
        #if DEBUG
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(llmService: llmService)
                .task {
                    // Load LLM model in background at app launch
                    llmService.loadModelInBackground()
                }
        }
    }
}
