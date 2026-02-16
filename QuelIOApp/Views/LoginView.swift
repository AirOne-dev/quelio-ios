import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AppViewModel

    @FocusState private var focusedField: Field?
    @State private var isPasswordVisible = false
    @State private var showServerSettings = false
    @State private var draftAPIURL = ""

    private enum Field {
        case username
        case password
        case server
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 24)

                logo

                VStack(spacing: 6) {
                    Text("Quel io")
                        .font(.largeTitle.weight(.bold))

                    Text("Suivi hebdo natif, pensé pour mobile")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                credentialsCard

                serverCard

                if let loginError = viewModel.loginError {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(viewModel.theme.danger)
                        Text(loginError)
                            .font(.footnote)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .cardSurface(cornerRadius: 14)
                }

                Button {
                    applyServerURL()
                    Task { await viewModel.login() }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isBusy {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(viewModel.isBusy ? "Connexion en cours…" : "Se connecter")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.loginDisabled)

                Text("Connexion sécurisée avec Kelio")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .contentMargins(.bottom, 24)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            draftAPIURL = viewModel.apiBaseURL
        }
        .onChange(of: viewModel.apiBaseURL) { _, newValue in
            if !showServerSettings {
                draftAPIURL = newValue
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }

    private var credentialsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                TextField("Nom d'utilisateur", text: $viewModel.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                Image(systemName: "key")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                Group {
                    if isPasswordVisible {
                        TextField("Mot de passe", text: $viewModel.password)
                            .textContentType(.password)
                    } else {
                        SecureField("Mot de passe", text: $viewModel.password)
                            .textContentType(.password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit {
                    applyServerURL()
                    Task { await viewModel.login() }
                }

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .cardSurface(cornerRadius: 20)
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) {
                    showServerSettings.toggle()
                }
            } label: {
                HStack {
                    Label("Serveur API", systemImage: "network")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(showServerSettings ? "Masquer" : "Modifier")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .rotationEffect(.degrees(showServerSettings ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showServerSettings {
                VStack(spacing: 10) {
                    TextField("http://localhost:8080/", text: $draftAPIURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .server)
                        .submitLabel(.done)
                        .onSubmit {
                            applyServerURL()
                            focusedField = nil
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    HStack(spacing: 8) {
                        Button("localhost") {
                            draftAPIURL = "http://localhost:8080/"
                            applyServerURL()
                        }
                        .buttonStyle(.bordered)

                        Button("127.0.0.1") {
                            draftAPIURL = "http://127.0.0.1:8080/"
                            applyServerURL()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Appliquer") {
                            applyServerURL()
                            focusedField = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Text("Actuel: \(viewModel.apiBaseURL)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .transition(.opacity)
            }
        }
        .padding(14)
        .cardSurface(cornerRadius: 18)
    }

    private var logo: some View {
        ZStack {
            Circle()
                .fill(viewModel.theme.accent.opacity(0.16))
                .frame(width: 88, height: 88)

            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(viewModel.theme.accent)
        }
    }

    private func applyServerURL() {
        let cleaned = draftAPIURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            draftAPIURL = viewModel.apiBaseURL
            return
        }

        viewModel.updateAPIBaseURL(cleaned)
        draftAPIURL = viewModel.apiBaseURL
    }
}

#Preview("Login") {
    let viewModel = PreviewFixtures.makeLoggedOutViewModel()
    return PreviewHost(viewModel: viewModel) {
        LoginView(viewModel: viewModel)
    }
}

#Preview("Login Erreur") {
    let viewModel = PreviewFixtures.makeLoggedOutViewModel(error: "Identifiants invalides")
    return PreviewHost(viewModel: viewModel) {
        LoginView(viewModel: viewModel)
    }
}
