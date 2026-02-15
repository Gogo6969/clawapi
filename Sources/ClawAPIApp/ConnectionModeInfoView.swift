import SwiftUI

struct ConnectionModeInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dismissedConnectionModeInfo") private var dismissedConnectionModeInfo = false

    /// Called when the user picks "Remote (SSH)" — parent should open SettingsView
    var onChooseRemote: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 30)

            // Icon
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .padding(.bottom, 14)

            // Title
            Text("Local or Remote?")
                .font(.title2.bold())
                .padding(.bottom, 6)

            Text("ClawAPI can manage OpenClaw on this Mac or on a remote VPS via SSH.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.bottom, 24)

            // Two clickable cards
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    InfoCard(
                        icon: "desktopcomputer",
                        color: .green,
                        title: "Local",
                        description: "OpenClaw runs on this Mac. ClawAPI manages it directly."
                    )
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                    // Small delay so the sheet dismissal finishes before opening Settings
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onChooseRemote?()
                    }
                } label: {
                    InfoCard(
                        icon: "server.rack",
                        color: .blue,
                        title: "Remote (SSH)",
                        description: "OpenClaw runs on a VPS. ClawAPI connects via SSH to manage it."
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // Pointer to settings
            HStack(spacing: 6) {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
                Text("Change this anytime in Settings (gear icon in the toolbar).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            Spacer()

            Divider()

            // Footer
            HStack {
                Toggle("Don't show again", isOn: $dismissedConnectionModeInfo)
                    .toggleStyle(.checkbox)
                    .font(.callout)

                Spacer()

                Button("Got It") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 420)
    }
}

private struct InfoCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(isHovered ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(isHovered ? 0.4 : 0), lineWidth: 1.5)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
