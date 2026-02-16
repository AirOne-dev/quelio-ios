import SwiftUI

struct AppRootView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if viewModel.phase != .loggedOut && viewModel.phase != .loading {
                Color.clear
            } else {
                ThemedBackground(theme: viewModel.theme)
            }

            switch viewModel.phase {
            case .loading:
                LaunchLoadingView(theme: viewModel.theme)
            case .loggedOut:
                LoginView(viewModel: viewModel)
            case .loggedIn:
                DashboardView(viewModel: viewModel)
            }
        }
        .tint(viewModel.theme.accent)
        .preferredColorScheme(viewModel.theme.preferredColorScheme)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await viewModel.refresh()
            }
        }
    }
}

private struct LaunchLoadingView: View {
    let theme: AppTheme

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.18))
                    .frame(width: 90, height: 90)
                    .scaleEffect(pulse ? 1.06 : 0.94)

                Circle()
                    .stroke(theme.accent.opacity(0.35), lineWidth: 2)
                    .frame(width: 74, height: 74)
                    .scaleEffect(pulse ? 1.18 : 0.90)
                    .opacity(pulse ? 0.0 : 1.0)

                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 33, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
            .animation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: pulse)

            ProgressView()
                .controlSize(.large)
                .tint(theme.accent)

            Text("Chargement des données…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
        .cardSurface(cornerRadius: 24)
        .onAppear {
            pulse = true
        }
    }
}

#Preview("App - Chargement") {
    AppRootView(viewModel: PreviewFixtures.makeLoadingViewModel())
}

#Preview("App - Connexion") {
    AppRootView(viewModel: PreviewFixtures.makeLoggedOutViewModel())
}

#Preview("App - Dashboard") {
    AppRootView(viewModel: PreviewFixtures.makeLoggedInViewModel())
}
