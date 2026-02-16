import SwiftUI

@main
struct QuelIOApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let scenario = ScreenshotScenario.fromProcessArguments() {
                scenario.makeView()
                    .environment(\.locale, Locale(identifier: "fr_FR"))
            } else {
                AppRootView(viewModel: viewModel)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
            }
            #else
            AppRootView(viewModel: viewModel)
                .environment(\.locale, Locale(identifier: "fr_FR"))
            #endif
        }
    }
}

#Preview("App Scene") {
    AppRootView(viewModel: PreviewFixtures.makeLoggedInViewModel())
        .environment(\.locale, Locale(identifier: "fr_FR"))
}
