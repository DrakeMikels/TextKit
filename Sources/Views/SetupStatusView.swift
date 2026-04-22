import SwiftUI

struct SetupStatusView: View {
    @Bindable var setupManager: SetupManager

    let runtimeState: ModelRuntimeState
    let model: LocalModelDescriptor
    let startSetup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: setupManager.isRunning ? "arrow.down.circle.fill" : "sparkles.rectangle.stack")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(cardTitle)
                        .font(.headline)

                    Text(setupManager.summary(for: runtimeState, model: model))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if setupManager.isRunning {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: setupManager.progressValue, total: 1)

                    Text(setupManager.stepTitle)
                        .font(.subheadline.weight(.semibold))

                    Text(setupManager.stepDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack {
                    Button(setupManager.primaryButtonTitle(for: runtimeState)) {
                        setupManager.resetFailure()
                        startSetup()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }

            Text("Selected: \(model.displayName) · \(model.quantPreset.title)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cardTitle: String {
        if setupManager.isRunning {
            return setupManager.stepTitle
        }

        switch runtimeState {
        case .missingRuntime:
            return "Set Up Local AI"
        case .missingModel:
            return "Download the Model"
        default:
            return "Local AI Setup"
        }
    }
}
