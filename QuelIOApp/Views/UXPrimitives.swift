import SwiftUI

struct ThemedBackground: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.background,
                startPoint: .top,
                endPoint: .bottom
            )

            OrbField(theme: theme)

            LinearGradient(
                colors: [
                    theme.surfaceTint.opacity(0.45),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct OrbField: View {
    let theme: AppTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let base = min(width, height)
            let isLight = colorScheme == .light

            ZStack {
                orb(
                    color: theme.accent,
                    diameter: base * 0.84,
                    intensity: isLight ? 0.44 : 0.64
                )
                    .position(
                        x: width * 0.18,
                        y: height * 0.12
                    )

                orb(
                    color: theme.accentSecondary,
                    diameter: base * 0.76,
                    intensity: isLight ? 0.38 : 0.56
                )
                    .position(
                        x: width * 0.82,
                        y: height * 0.20
                    )

                orb(
                    color: theme.positive,
                    diameter: base * 0.62,
                    intensity: isLight ? 0.26 : 0.40
                )
                    .position(
                        x: width * 0.26,
                        y: height * 0.82
                    )

                Circle()
                    .fill(Color.white.opacity(isLight ? 0.12 : 0.07))
                    .frame(width: base * 0.56, height: base * 0.56)
                    .blur(radius: isLight ? 28 : 34)
                    .position(
                        x: width * 0.54,
                        y: height * 0.48
                    )
            }
            .frame(width: width, height: height)
            .saturation(isLight ? 1.08 : 1.04)
            .opacity(isLight ? 0.90 : 0.94)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func orb(color: Color, diameter: CGFloat, intensity: Double) -> some View {
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(intensity),
                        color.opacity(intensity * 0.52),
                        color.opacity(intensity * 0.18),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.52
                )
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: colorScheme == .light ? 34 : 42)
    }
}

struct UXSectionTitle: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatusPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct CardSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat
    var isInteractive: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let glassStyle: Glass = {
            if colorScheme == .light {
                return .regular.tint(.white.opacity(0.58)).interactive(isInteractive)
            }
            return .regular.tint(.black.opacity(0.32)).interactive(isInteractive)
        }()

        content
            .glassEffect(glassStyle, in: shape)
    }
}

private struct ToolbarSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let tintLayer = LinearGradient(
            colors: colorScheme == .light
                ? [
                    Color.white.opacity(0.52),
                    Color.white.opacity(0.34)
                ]
                : [
                    Color.white.opacity(0.08),
                    Color.black.opacity(0.18)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let strokeColor = colorScheme == .light
            ? Color.black.opacity(0.11)
            : Color.white.opacity(0.14)

        content
            .background(shape.fill(.regularMaterial))
            .overlay { shape.fill(tintLayer) }
            .overlay { shape.stroke(strokeColor, lineWidth: 1) }
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 18, isInteractive: Bool = false) -> some View {
        modifier(CardSurfaceModifier(cornerRadius: cornerRadius, isInteractive: isInteractive))
    }

    func toolbarSurface(cornerRadius: CGFloat = 999) -> some View {
        modifier(ToolbarSurfaceModifier(cornerRadius: cornerRadius))
    }
}

#Preview("UX Primitives") {
    PreviewHost(viewModel: PreviewFixtures.makeLoggedInViewModel()) {
        VStack(alignment: .leading, spacing: 14) {
            UXSectionTitle(title: "Résumé", trailing: "mis à jour")
            StatusPill(icon: "checkmark.circle.fill", text: "Connecté", color: .green)
            Text("Carte exemple")
                .padding()
                .cardSurface(cornerRadius: 16)
        }
        .padding()
    }
}

#Preview("Background Forest") {
    ThemedBackground(theme: .forest)
}

#Preview("Background Light") {
    ThemedBackground(theme: .light)
}
