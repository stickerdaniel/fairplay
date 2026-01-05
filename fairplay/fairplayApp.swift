import SwiftUI
#if DEBUG
@_exported import Inject
#endif

@main
struct fairplayApp: App {
    init() {
        #if DEBUG
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
