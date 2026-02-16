import SwiftUI

@main
struct QuelIOApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            AppRootView(viewModel: viewModel)
                .environment(\.locale, Locale(identifier: "fr_FR"))
        }
    }
}

#Preview("App Scene") {
    AppRootView(viewModel: PreviewFixtures.makeLoggedInViewModel())
        .environment(\.locale, Locale(identifier: "fr_FR"))
}
