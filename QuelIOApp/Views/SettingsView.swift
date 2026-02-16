import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftAPIURL: String

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        _draftAPIURL = State(initialValue: viewModel.apiBaseURL)
    }

    var body: some View {
        ZStack {
            ThemedBackground(theme: viewModel.theme)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    appearanceSection
                    objectiveSection
                    apiSection
                    sessionSection
                }
                .frame(maxWidth: 600)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .contentMargins(.bottom, 28)
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                HStack(spacing: 8) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                    }
                }
            }
        }
        .onChange(of: viewModel.apiBaseURL) { _, newValue in
            draftAPIURL = newValue
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            UXSectionTitle(title: "Apparence")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        viewModel.updateTheme(theme)
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 10, height: 10)

                            Text(theme.label)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            if theme == viewModel.theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(viewModel.theme.accent)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(theme == viewModel.theme ? viewModel.theme.accent.opacity(0.14) : .primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .cardSurface(cornerRadius: 18)
    }

    private var objectiveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            UXSectionTitle(title: "Objectif hebdomadaire", trailing: "\(viewModel.weeklyObjectiveMinutes / 60) h")

            Slider(value: objectiveSliderBinding, in: 1...60, step: 1)
                .tint(viewModel.theme.accent)

            HStack(spacing: 8) {
                Button {
                    viewModel.updateWeeklyObjectiveHours((viewModel.weeklyObjectiveMinutes / 60) - 1)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)

                Text("\(viewModel.weeklyObjectiveMinutes / 60) h")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                Button {
                    viewModel.updateWeeklyObjectiveHours((viewModel.weeklyObjectiveMinutes / 60) + 1)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
            }

            Text("Référence utilisée pour calculer le restant et la progression.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .cardSurface(cornerRadius: 18)
    }

    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            UXSectionTitle(title: "API Kelio")

            TextField("http://localhost:8080/", text: $draftAPIURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 8) {
                Button("Local") {
                    draftAPIURL = "http://localhost:8080/"
                    applyServerURL()
                }
                .buttonStyle(.bordered)

                Button("Appliquer") {
                    applyServerURL()
                }
                .buttonStyle(.borderedProminent)

                Spacer(minLength: 0)

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            Text("Actuel: \(viewModel.apiBaseURL)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .cardSurface(cornerRadius: 18)
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            UXSectionTitle(title: "Session")

            Button(role: .destructive) {
                viewModel.logout()
            } label: {
                HStack {
                    Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(viewModel.theme.danger.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(viewModel.theme.danger)
        }
        .padding(16)
        .cardSurface(cornerRadius: 18)
    }

    private var objectiveSliderBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.weeklyObjectiveMinutes / 60) },
            set: { viewModel.updateWeeklyObjectiveHours(Int($0.rounded())) }
        )
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

#Preview("Settings") {
    let viewModel = PreviewFixtures.makeLoggedInViewModel()
    return PreviewHost(viewModel: viewModel) {
        SettingsView(viewModel: viewModel)
    }
}
