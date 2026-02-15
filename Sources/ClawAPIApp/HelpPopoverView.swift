import SwiftUI

struct HelpPopoverView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Quick Guide", systemImage: "questionmark.circle.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HelpSection(
                    icon: "key",
                    color: .purple,
                    title: "Providers",
                    text: "Your AI providers. Use the model dropdown to switch sub-models. Drag rows to set priority — #1 is what OpenClaw uses first. Toggle ENABLED/DISABLED to control costs."
                )
                HelpSection(
                    icon: "arrow.triangle.2.circlepath",
                    color: .green,
                    title: "Sync",
                    text: "Shows what's currently synced to OpenClaw — active model, fallbacks, and provider config."
                )
                HelpSection(
                    icon: "gauge",
                    color: .blue,
                    title: "Activity",
                    text: "Request counts and recent activity. Click any card for details."
                )
                HelpSection(
                    icon: "list.bullet.rectangle",
                    color: .orange,
                    title: "Logs",
                    text: "Full history of every API request. Filter by result or search by provider."
                )
                HelpSection(
                    icon: "chart.bar",
                    color: .teal,
                    title: "Usage",
                    text: "Check your credit balance and spending for supported providers."
                )

                Divider()

                HelpSection(
                    icon: "plus.circle",
                    color: .green,
                    title: "Add Provider (+)",
                    text: "Connect a new provider. Pick from 15+ AI services or add a custom one."
                )
                HelpSection(
                    icon: "bell.badge",
                    color: .red,
                    title: "Pending Requests",
                    text: "When a provider requires manual approval, requests queue here."
                )
                HelpSection(
                    icon: "gearshape",
                    color: .gray,
                    title: "Settings (Gear)",
                    text: "Switch between Local and Remote (SSH) mode. Manage OpenClaw on this Mac or on a VPS server."
                )
            }
        }
        .padding()
        .frame(width: 360)
    }
}

// MARK: - Help Section

private struct HelpSection: View {
    let icon: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
