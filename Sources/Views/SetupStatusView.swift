import SwiftUI

struct SetupStatusView: View {
    @Bindable var settingsStore: SettingsStore
    @Bindable var modelManager: ModelManager
    @Bindable var setupManager: SetupManager

    let startSetup: () -> Void

    @State private var modelStates: [LocalModelOption: ModelRuntimeState] = [:]

    private var selectedModel: LocalModelDescriptor {
        modelManager.model(
            for: settingsStore.localModelOption,
            quantPreset: settingsStore.installedQuantPreset
        )
    }

    private var selectedState: ModelRuntimeState {
        if setupManager.isRunning || setupManager.hasFailure {
            return modelManager.runtimeState
        }

        return modelStates[settingsStore.localModelOption] ?? modelManager.runtimeState
    }

    private var installableAlternateModel: LocalModelOption? {
        LocalModelOption.allCases.first {
            $0 != settingsStore.localModelOption && modelStates[$0] != .ready
        }
    }

    private var refreshKey: String {
        [
            settingsStore.localModelOption.rawValue,
            setupManager.isRunning ? "running" : "idle",
            setupManager.hasFailure ? "failed" : "ok"
        ].joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if setupManager.isRunning {
                progressSection
            } else {
                modelChoiceSection
                installSection
            }
        }
        .task(id: refreshKey) {
            await refreshModelStates()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: setupManager.isRunning ? "arrow.down.circle.fill" : "sparkles.rectangle.stack")
                .font(.system(size: 24))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(cardTitle)
                    .font(.headline)

                Text(cardSummary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var modelChoiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("1. Choose a starting model")
                .font(.subheadline.weight(.semibold))

            HStack(alignment: .top, spacing: 12) {
                ForEach(LocalModelOption.allCases) { modelOption in
                    modelOptionCard(for: modelOption)
                }
            }
        }
    }

    private func modelOptionCard(for modelOption: LocalModelOption) -> some View {
        let state = modelStates[modelOption] ?? .unknown
        let isSelected = settingsStore.localModelOption == modelOption

        return Button {
            settingsStore.localModelOption = modelOption
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(modelOption.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Text(modelOption.setupBadgeTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.14))
                        )
                }

                Text(modelOption.setupSummary)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(modelOption.helperDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    statusChip(for: state)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(Color.accentColor.opacity(0.16))
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.08),
                                lineWidth: isSelected ? 1.1 : 0.8
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var installSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("2. Download and start")
                .font(.subheadline.weight(.semibold))

            Text(installSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if selectedState == .ready {
                    Label("\(selectedModel.displayName) is ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let installableAlternateModel {
                        Button("Install \(installableAlternateModel.title)") {
                            settingsStore.localModelOption = installableAlternateModel
                            setupManager.resetFailure()
                            startSetup()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button(primaryActionTitle) {
                        setupManager.resetFailure()
                        startSetup()
                    }
                    .buttonStyle(.borderedProminent)

                    if let installableAlternateModel, installableAlternateModel != settingsStore.localModelOption {
                        Button("Choose \(installableAlternateModel.title)") {
                            settingsStore.localModelOption = installableAlternateModel
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: setupManager.progressValue, total: 1)

            Text(setupManager.stepTitle)
                .font(.subheadline.weight(.semibold))

            Text(setupManager.stepDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusChip(for state: ModelRuntimeState) -> some View {
        Text(statusText(for: state))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusForeground(for: state))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(statusBackground(for: state))
            )
    }

    private var cardTitle: String {
        if setupManager.isRunning {
            return setupManager.stepTitle
        }

        if LocalModelOption.allCases.contains(where: { modelStates[$0] == .ready }) {
            return "Manage Local Models"
        }

        return "Set Up Local AI"
    }

    private var cardSummary: String {
        if setupManager.isRunning {
            return setupManager.stepDetail
        }

        if setupManager.hasFailure {
            return setupManager.summary(for: selectedState, model: selectedModel)
        }

        return "TextKit downloads one balanced local file per model, then runs fully on-device after setup."
    }

    private var installSummary: String {
        if setupManager.hasFailure {
            return setupManager.summary(for: selectedState, model: selectedModel)
        }

        switch selectedState {
        case .missingRuntime:
            return "This copy of TextKit is missing its built-in local AI runtime. Reinstall the app to continue."
        case .missingModel, .unknown:
            return "TextKit will download the balanced \(selectedModel.displayName) file once, then keep using it offline on this Mac."
        case .ready:
            return "\(selectedModel.displayName) is already installed. You can switch models here any time."
        case .running:
            return "TextKit is using \(selectedModel.displayName) locally."
        case let .failed(message):
            return message
        }
    }

    private var primaryActionTitle: String {
        if setupManager.hasFailure {
            return "Try Again"
        }

        switch selectedState {
        case .missingRuntime:
            return "Check Again"
        case .missingModel, .unknown:
            return "Download \(selectedModel.displayName)"
        case .ready:
            return "\(selectedModel.displayName) Ready"
        case .running:
            return "Working Locally"
        case .failed:
            return "Try Again"
        }
    }

    private func statusText(for state: ModelRuntimeState) -> String {
        switch state {
        case .unknown:
            return "Checking"
        case .missingRuntime:
            return "Needs runtime"
        case .missingModel:
            return "Not installed"
        case .ready:
            return "Installed"
        case .running:
            return "Working"
        case .failed:
            return "Needs attention"
        }
    }

    private func statusForeground(for state: ModelRuntimeState) -> Color {
        switch state {
        case .ready, .running:
            return Color.green.opacity(0.9)
        case .failed:
            return Color.orange.opacity(0.95)
        default:
            return Color.secondary
        }
    }

    private func statusBackground(for state: ModelRuntimeState) -> Color {
        switch state {
        case .ready, .running:
            return Color.green.opacity(0.14)
        case .failed:
            return Color.orange.opacity(0.14)
        default:
            return Color.secondary.opacity(0.12)
        }
    }

    @MainActor
    private func refreshModelStates() async {
        guard !setupManager.isRunning else { return }

        var updatedStates: [LocalModelOption: ModelRuntimeState] = [:]
        for modelOption in LocalModelOption.allCases {
            updatedStates[modelOption] = await modelManager.availability(
                for: modelOption,
                quantPreset: settingsStore.installedQuantPreset
            )
        }
        modelStates = updatedStates
    }
}
