import SwiftUI
import Shared

struct GetStartedView: View {
    @EnvironmentObject var store: PolicyStore
    @AppStorage("skippedGetStarted") private var skippedGetStarted = false

    @State private var showingAddSheet = false
    @State private var selectedTemplate: ServiceTemplate?

    private let openClawInstalled = OpenClawDetection.isInstalled

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Hero ──
                VStack(spacing: 16) {
                    Spacer().frame(height: 40)

                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.72, green: 0.12, blue: 0.12),
                                         Color(red: 0.91, green: 0.22, blue: 0.22)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                        .shadow(color: Color(red: 0.91, green: 0.22, blue: 0.22).opacity(0.3), radius: 12, y: 6)

                    Text("Get Started")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text(openClawInstalled
                         ? "Add a provider, pick a model, and ClawAPI handles the rest."
                         : "Add a provider and pick the AI model you want to use.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480)

                    Spacer().frame(height: 8)
                }

                // ── Provider Grid ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose a provider")
                        .font(.headline)
                        .padding(.leading, 4)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 130, maximum: 170), spacing: 12)
                    ], spacing: 12) {
                        ForEach(ServiceCatalog.all) { template in
                            ProviderCard(
                                name: template.name,
                                domains: template.domains.first ?? "",
                                color: colorForIndex(ServiceCatalog.all.firstIndex(where: { $0.id == template.id }) ?? 0)
                            ) {
                                selectedTemplate = template
                                showingAddSheet = true
                            }
                        }

                        // Custom option
                        ProviderCard(
                            name: "Custom",
                            domains: "Any API",
                            systemIcon: "ellipsis.circle.fill",
                            color: .gray
                        ) {
                            selectedTemplate = nil
                            showingAddSheet = true
                        }
                    }
                }
                .frame(maxWidth: 640)
                .padding(.horizontal, 32)

                Spacer().frame(height: 32)

                // ── Skip ──
                Button {
                    skippedGetStarted = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Skip for now")
                        Image(systemName: "arrow.right")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingAddSheet) {
            if let template = selectedTemplate {
                AddScopeSheet(initialTemplate: template)
            } else {
                AddScopeSheet()
            }
        }
    }

    // MARK: - Color palette for cards

    private func colorForIndex(_ index: Int) -> Color {
        let palette: [Color] = [
            .blue, .green, .purple, .orange, .teal,
            .cyan, .pink, .indigo, .mint, .red,
            .yellow, .brown
        ]
        return palette[index % palette.count]
    }
}

// MARK: - Provider Card

private struct ProviderCard: View {
    let name: String
    let domains: String
    var systemIcon: String? = nil
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let icon = systemIcon {
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundStyle(color)
                        .frame(height: 32)
                } else {
                    Text(String(name.prefix(2)).uppercased())
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                        .frame(height: 32)
                }

                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(domains)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
