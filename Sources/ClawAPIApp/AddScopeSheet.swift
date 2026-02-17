import SwiftUI
import Shared

// MARK: - Add Scope Sheet (Container)

struct AddScopeSheet: View {
    @EnvironmentObject var store: PolicyStore
    @Environment(\.dismiss) private var dismiss

    /// When provided, skip the picker and go directly to the API key entry step.
    var initialTemplate: ServiceTemplate? = nil

    // Step state
    @State private var step: AddStep = .pickService

    // Selected service (set in step 1, used in step 2)
    @State private var selectedTemplate: ServiceTemplate?
    @State private var isCustom = false

    // Fields (populated in step 2)
    @State private var customName = ""
    @State private var secret = ""
    @State private var showSecret = false
    @State private var showKeychainWarning = false
    @State private var scope = ""
    @State private var domainsText = ""
    @State private var credentialType: CredentialType = .bearerToken
    @State private var customHeaderName = ""
    @State private var approvalMode: ScopeApprovalMode = .auto
    @State private var showAdvanced = false
    @State private var selectedTags: Set<String> = []
    @State private var customTagText = ""

    // Error state
    @State private var keychainError = ""
    @State private var showKeychainError = false
    @State private var pendingPolicyWithoutSecret: ScopePolicy?

    // Success state
    @State private var addedServiceName = ""

    private enum AddStep {
        case pickService
        case enterKey
        case success
    }

    var body: some View {
        Group {
            switch step {
            case .pickService:
                ServicePickerView(
                    onSelect: { template in
                        selectTemplate(template)
                        withAnimation(.easeInOut(duration: 0.25)) { step = .enterKey }
                    },
                    onSelectCustom: {
                        selectCustom()
                        withAnimation(.easeInOut(duration: 0.25)) { step = .enterKey }
                    },
                    onCancel: { dismiss() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))

            case .enterKey:
                APIKeyEntryView(
                    selectedTemplate: selectedTemplate,
                    isCustom: isCustom,
                    customName: $customName,
                    secret: $secret,
                    showSecret: $showSecret,
                    scope: $scope,
                    domainsText: $domainsText,
                    credentialType: $credentialType,
                    customHeaderName: $customHeaderName,
                    approvalMode: $approvalMode,
                    showAdvanced: $showAdvanced,
                    selectedTags: $selectedTags,
                    customTagText: $customTagText,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) { step = .pickService }
                    },
                    onAdd: { attemptAdd() },
                    onCancel: { dismiss() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))

            case .success:
                SuccessView(serviceName: addedServiceName, isFirstProvider: isFirstProvider,
                            isLocal: !(selectedTemplate?.requiresKey ?? true))
                    .transition(.opacity)
            }
        }
        .frame(width: 520, height: step == .success ? (isFirstProvider ? 340 : 260) : 620)
        .animation(.easeInOut(duration: 0.25), value: step == .success)
        .alert("Keychain Access", isPresented: $showKeychainWarning) {
            Button("Continue") {
                addScope()
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("ClawAPI will now store your credential in the macOS Keychain.\n\nmacOS may ask for your password or Touch ID to allow this. This is a standard macOS security prompt — it ensures only you can authorize Keychain access.\n\nClick \"Allow\" or \"Always Allow\" when the system dialog appears.")
        }
        .alert("Keychain Error", isPresented: $showKeychainError) {
            Button("Try Again") {
                addScope()
            }
            Button("Add Without Secret") {
                if var policy = pendingPolicyWithoutSecret {
                    policy.hasSecret = false
                    store.addPolicy(policy)
                    addedServiceName = policy.serviceName
                    withAnimation { step = .success }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Failed to save credential to the macOS Keychain.\n\n\(keychainError)\n\nYou can try again, or add the provider without a secret (you can add the key later).")
        }
        .onAppear {
            if let template = initialTemplate {
                selectTemplate(template)
                step = .enterKey
            }
        }
    }

    // MARK: - Actions

    private func selectTemplate(_ template: ServiceTemplate) {
        selectedTemplate = template
        isCustom = false
        customName = ""

        scope = template.scope
        domainsText = template.domains.joined(separator: ", ")
        credentialType = template.credentialType
        customHeaderName = template.customHeaderName ?? ""
        approvalMode = .auto
        showAdvanced = false
        selectedTags = Set(template.suggestedTags)
        customTagText = ""
        secret = ""
        showSecret = false
    }

    private func selectCustom() {
        selectedTemplate = nil
        isCustom = true

        scope = ""
        domainsText = ""
        credentialType = .bearerToken
        customHeaderName = ""
        approvalMode = .auto
        showAdvanced = true
        selectedTags = []
        customTagText = ""
        secret = ""
        showSecret = false
    }

    private var hasSecret: Bool {
        !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True when no providers have been added yet — used to show the Keychain explanation.
    private var isFirstProvider: Bool {
        store.policies.isEmpty
    }

    private func attemptAdd() {
        if hasSecret {
            showKeychainWarning = true
        } else {
            addScope()
        }
    }

    private func addScope() {
        Task {
            // Require Touch ID / password before saving a secret to the Keychain
            if hasSecret {
                guard await KeychainService.authenticateWithBiometrics(
                    reason: "Authenticate to save API key"
                ) else { return }
            }

            await MainActor.run { addScopeAfterAuth() }
        }
    }

    private func addScopeAfterAuth() {
        let domains = domainsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let name = isCustom
            ? customName.trimmingCharacters(in: .whitespaces)
            : (selectedTemplate?.name ?? "")

        let policy = ScopePolicy(
            serviceName: name,
            scope: scope.trimmingCharacters(in: .whitespaces),
            allowedDomains: domains,
            approvalMode: approvalMode,
            hasSecret: hasSecret,
            credentialType: credentialType,
            customHeaderName: credentialType == .customHeader ? customHeaderName.trimmingCharacters(in: .whitespaces) : nil,
            preferredFor: Array(selectedTags).sorted()
        )

        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)

        if hasSecret {
            let keychain = KeychainService()
            do {
                try keychain.save(string: trimmedSecret, forScope: policy.scope)
            } catch {
                keychainError = error.localizedDescription
                pendingPolicyWithoutSecret = policy
                showKeychainError = true
                return  // Don't add the policy if Keychain save failed
            }
        }

        store.addPolicy(policy)

        // Show success, then auto-dismiss (longer delay for first provider so user reads Keychain info)
        let wasFirstProvider = isFirstProvider
        addedServiceName = name
        withAnimation { step = .success }
        DispatchQueue.main.asyncAfter(deadline: .now() + (wasFirstProvider ? 5.0 : 1.0)) {
            dismiss()
        }
    }
}

// MARK: - Step 1: Service Picker

private struct ServicePickerView: View {
    let onSelect: (ServiceTemplate) -> Void
    let onSelectCustom: () -> Void
    let onCancel: () -> Void

    @State private var searchText = ""

    private var filteredTemplates: [ServiceTemplate] {
        let q = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return ServiceCatalog.all }
        return ServiceCatalog.all.filter {
            $0.name.lowercased().contains(q) || $0.scope.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Provider")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select a provider")
                        .font(.headline)

                    TextField("Search providers...", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 110, maximum: 140), spacing: 10)
                    ], spacing: 10) {
                        ForEach(filteredTemplates) { template in
                            ServiceButton(name: template.name) {
                                onSelect(template)
                            }
                        }

                        ServiceButton(name: "Custom", systemIcon: "ellipsis.circle") {
                            onSelectCustom()
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Step 2: API Key Entry

private struct APIKeyEntryView: View {
    let selectedTemplate: ServiceTemplate?
    let isCustom: Bool
    @Binding var customName: String
    @Binding var secret: String
    @Binding var showSecret: Bool
    @Binding var scope: String
    @Binding var domainsText: String
    @Binding var credentialType: CredentialType
    @Binding var customHeaderName: String
    @Binding var approvalMode: ScopeApprovalMode
    @Binding var showAdvanced: Bool
    @Binding var selectedTags: Set<String>
    @Binding var customTagText: String
    let onBack: () -> Void
    let onAdd: () -> Void
    let onCancel: () -> Void

    private var displayName: String {
        if isCustom {
            let trimmed = customName.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "Provider" : trimmed
        }
        return selectedTemplate?.name ?? "Provider"
    }

    private var keyPlaceholder: String {
        selectedTemplate?.keyPlaceholder ?? "Paste API key or token"
    }

    private var isValid: Bool {
        if isCustom {
            return !customName.trimmingCharacters(in: .whitespaces).isEmpty
                && !scope.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack(spacing: 10) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("Add \(displayName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Service badge
                    if !isCustom, let template = selectedTemplate {
                        HStack(spacing: 10) {
                            Text(String(template.name.prefix(2)).uppercased())
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.headline)
                                Text(template.domains.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Custom name field
                    if isCustom {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Provider Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("e.g. My API Provider", text: $customName)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: customName) { _, newValue in
                                    scope = newValue
                                        .lowercased()
                                        .replacingOccurrences(of: " ", with: "-")
                                        .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }
                                }
                        }
                    }

                    // API Key (hidden for local providers that don't need one)
                    if selectedTemplate?.requiresKey ?? true {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("API Key")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                if showSecret {
                                    TextField("API Key", text: $secret, prompt: Text(keyPlaceholder))
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("API Key", text: $secret, prompt: Text(keyPlaceholder))
                                        .textFieldStyle(.roundedBorder)
                                }
                                Button {
                                    showSecret.toggle()
                                } label: {
                                    Image(systemName: showSecret ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Text("Encrypted in the macOS Keychain. OpenClaw never sees it.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "desktopcomputer")
                                .font(.title2)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Local Provider")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Runs on your machine — no API key needed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Advanced Settings
                    DisclosureGroup(isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connection ID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("Scope", text: $scope)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Allowed Domains")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("Comma-separated", text: $domainsText, prompt: Text("e.g. api.example.com"))
                                    .textFieldStyle(.roundedBorder)
                                Text("Only requests to these domains are forwarded. Others are denied.")
                                    .font(.caption2)
                                    .foregroundStyle(.quaternary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Credential Type")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("", selection: $credentialType) {
                                    Text("Bearer Token").tag(CredentialType.bearerToken)
                                    Text("Custom Header").tag(CredentialType.customHeader)
                                    Text("Cookie").tag(CredentialType.cookie)
                                    Text("Basic Auth").tag(CredentialType.basicAuth)
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()

                                if credentialType == .customHeader {
                                    TextField("Header Name", text: $customHeaderName, prompt: Text("e.g. X-API-Key"))
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Approval Mode")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("", selection: $approvalMode) {
                                    Text("Auto").tag(ScopeApprovalMode.auto)
                                    Text("Manual").tag(ScopeApprovalMode.manual)
                                    Text("Pending").tag(ScopeApprovalMode.pending)
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Best For")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                FlowLayout(spacing: 6) {
                                    ForEach(TaskType.allPredefined, id: \.self) { tag in
                                        TagToggle(tag: tag, isSelected: selectedTags.contains(tag)) {
                                            if selectedTags.contains(tag) {
                                                selectedTags.remove(tag)
                                            } else {
                                                selectedTags.insert(tag)
                                            }
                                        }
                                    }
                                    ForEach(Array(selectedTags.filter { !TaskType.allPredefined.contains($0) }), id: \.self) { tag in
                                        TagToggle(tag: tag, isSelected: true) {
                                            selectedTags.remove(tag)
                                        }
                                    }
                                }

                                HStack {
                                    TextField("Custom tag...", text: $customTagText)
                                        .textFieldStyle(.roundedBorder)
                                        .onSubmit {
                                            let trimmed = customTagText.trimmingCharacters(in: .whitespaces).lowercased()
                                            if !trimmed.isEmpty {
                                                selectedTags.insert(trimmed)
                                                customTagText = ""
                                            }
                                        }
                                    Button("Add") {
                                        let trimmed = customTagText.trimmingCharacters(in: .whitespaces).lowercased()
                                        if !trimmed.isEmpty {
                                            selectedTags.insert(trimmed)
                                            customTagText = ""
                                        }
                                    }
                                    .disabled(customTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                                }

                                Text("Tag what this provider is best at. OpenClaw uses these to pick the right provider.")
                                    .font(.caption2)
                                    .foregroundStyle(.quaternary)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("Advanced Settings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add \(displayName)") {
                    onAdd()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
    }
}

// MARK: - Step 3: Success

private struct SuccessView: View {
    let serviceName: String
    let isFirstProvider: Bool
    var isLocal: Bool = false
    @State private var animate = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(animate ? 1.0 : 0.5)
                .opacity(animate ? 1.0 : 0.0)

            Text("\(serviceName) added")
                .font(.title2)
                .fontWeight(.semibold)
                .opacity(animate ? 1.0 : 0.0)

            Text(isLocal ? "Local provider configured" : "Credentials stored in the macOS Keychain")
                .font(.callout)
                .foregroundStyle(.secondary)
                .opacity(animate ? 1.0 : 0.0)

            if isFirstProvider {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal, 40)

                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Keychain Access")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("When OpenClaw uses your credentials for the first time, macOS will show a security prompt asking for your login password. Click **\"Always Allow\"** so it doesn't ask again.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
                }
                .opacity(animate ? 1.0 : 0.0)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
}

// MARK: - Service Button

private struct ServiceButton: View {
    let name: String
    var systemIcon: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let icon = systemIcon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(height: 28)
                } else {
                    Text(String(name.prefix(2)).uppercased())
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.blue)
                        .frame(height: 28)
                }
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Color.blue.opacity(isHovered ? 0.12 : 0.06),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(isHovered ? 0.35 : 0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }
}

// MARK: - Tag Toggle Capsule

private struct TagToggle: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1),
                           in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout (wrapping horizontal layout)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
