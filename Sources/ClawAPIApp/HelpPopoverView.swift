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
                    text: "Manage your API providers. Drag to reorder — #1 is your MAIN provider. Use the ENABLED/DISABLED button to toggle providers on or off. Colored tags show what each provider is best for (coding, research, chat, etc.)."
                )
                HelpSection(
                    icon: "gauge",
                    color: .blue,
                    title: "Activity",
                    text: "See request counts, recent activity, and pending requests. Click any card to jump to the relevant section."
                )
                HelpSection(
                    icon: "list.bullet.rectangle",
                    color: .orange,
                    title: "Logs",
                    text: "Full history of every time OpenClaw accessed a credential. Filter by result or search by provider."
                )

                Divider()

                HelpSection(
                    icon: "plus.circle",
                    color: .green,
                    title: "Add Provider (+)",
                    text: "Connect a new API provider. Select a provider, paste your API key, and OpenClaw can start using it. Open Advanced Settings to set \"Best For\" tags — these tell OpenClaw which tasks each provider excels at."
                )
                HelpSection(
                    icon: "bell.badge",
                    color: .red,
                    title: "Pending Requests (bell)",
                    text: "When a provider requires manual approval, requests queue here. Approve or deny each one."
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
