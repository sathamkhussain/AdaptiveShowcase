import SwiftUI
import AdaptiveShowcase

@main
struct ShowcaseDemoApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                StudioDashboard()
                    .tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }
                StudioPage(title: "Projects", symbol: "folder", message: "Every idea has a home.")
                    .tabItem { Label("Projects", systemImage: "folder") }
                StudioPage(title: "Activity", symbol: "chart.bar", message: "Small steps. Meaningful progress.")
                    .tabItem { Label("Activity", systemImage: "chart.bar") }
                StudioPage(title: "Profile", symbol: "person.crop.circle", message: "Make this space your own.")
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
                .tint(Color(red: 0.08, green: 0.48, blue: 0.46))
                .preferredColorScheme(.light)
        }
    }
}

private struct StudioPage: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 48))
            Text(title).font(.largeTitle.bold())
            Text(message).font(.subheadline)
        }
        .foregroundStyle(Color(red: 0.07, green: 0.19, blue: 0.29))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.94, green: 0.96, blue: 0.97).ignoresSafeArea())
    }
}

private struct StudioDashboard: View {
    @State private var showingGuide = false
    private let ink = Color(red: 0.07, green: 0.19, blue: 0.29)
    private let teal = Color(red: 0.08, green: 0.48, blue: 0.46)

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > 600
            VStack(alignment: .leading, spacing: wide ? 24 : 18) {
                header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Make room for great ideas.")
                        .font(.system(size: wide ? 34 : 27, weight: .bold, design: .rounded))
                    Text("Your projects, thoughtfully organized.")
                        .font(.subheadline)
                        .foregroundStyle(ink.opacity(0.6))
                }
                focusCard
                    .showcaseTarget("focus")
                HStack(spacing: 12) {
                    metric("12", label: "In progress", symbol: "square.stack.3d.up.fill")
                    metric("04", label: "This week", symbol: "checkmark.seal.fill")
                }
                if wide {
                    HStack(spacing: 16) {
                        project("Brand exploration", category: "DESIGN SYSTEM", symbol: "paintpalette.fill", tint: teal)
                            .showcaseTarget("project")
                        project("A better everyday", category: "PRODUCT STRATEGY", symbol: "sparkles", tint: .indigo)
                    }
                } else {
                    project("Brand exploration", category: "DESIGN SYSTEM", symbol: "paintpalette.fill", tint: teal)
                        .showcaseTarget("project")
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(ink)
            .padding(wide ? 28 : 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.94, green: 0.96, blue: 0.97))
        }
        .showcase(isPresented: $showingGuide, steps: [
            ShowcaseStep(target: "focus", title: "A little focus. A big difference.",
                         message: "Keep your next great idea in sight. Pick up where you left off, with everything you need in one place.",
                         nextTitle: "Got it",
                         backgroundColor: UIColor(red: 0.04, green: 0.25, blue: 0.29, alpha: 1)),
            ShowcaseStep(target: "project", title: "Every idea has a home.",
                         message: "Open a project and bring your best work together.",
                         nextTitle: "Next",
                         backgroundColor: UIColor(red: 0.04, green: 0.25, blue: 0.29, alpha: 1)),
            ShowcaseStep(tabIndex: 1, title: "Your projects, one tap away.",
                         message: "Use the Projects tab to explore your ideas and pick up where you left off.",
                         nextTitle: "Done",
                         backgroundColor: UIColor(red: 0.04, green: 0.25, blue: 0.29, alpha: 1))
        ])
        .task {
            if ProcessInfo.processInfo.arguments.contains("--show-guide") {
                try? await Task.sleep(nanoseconds: 700_000_000)
                showingGuide = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.title2)
                .foregroundStyle(teal)
            Text("FORM / STUDIO")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .tracking(2)
            Spacer()
            Button { showingGuide = true } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.white, in: Circle())
            }
            .accessibilityLabel("Show the guide")
        }
    }

    private var focusCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR NEXT CHAPTER")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.75))
                Text("Ideas into impact.")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text("Continue your creative journey")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 6) {
                    Text("Open workspace")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 44))
                .rotationEffect(.degrees(-10))
                .foregroundStyle(Color(red: 0.68, green: 0.92, blue: 0.83))
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [teal, Color(red: 0.07, green: 0.30, blue: 0.37)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private func metric(_ value: String, label: String, symbol: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: 26, weight: .bold, design: .rounded))
                Text(label).font(.caption).foregroundStyle(ink.opacity(0.6))
            }
            Spacer()
            Image(systemName: symbol).foregroundStyle(teal.opacity(0.7))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func project(_ title: String, category: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(category).font(.system(size: 9, weight: .bold)).tracking(1.4)
                    .foregroundStyle(ink.opacity(0.45))
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").foregroundStyle(ink.opacity(0.4))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

}
