import SwiftUI

enum ShareState {
    case loading
    case success(SummaryResult)
    case error(String)
    case unconfigured
}

struct ShareRootView: View {
    let extensionContext: NSExtensionContext?
    @State private var state: ShareState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                LoadingView()
            case .success(let result):
                ScrollView {
                    SummaryView(result: result, onDismiss: dismiss)
                }
            case .error(let message):
                ErrorView(message: message, onRetry: startSummarization, onDismiss: dismiss)
            case .unconfigured:
                UnconfiguredView(onDismiss: dismiss)
            }
        }
        .frame(minHeight: 200)
        .task { startSummarization() }
    }

    private func startSummarization() {
        Task {
            state = .loading
            let settings = SettingsStore()
            guard settings.isConfigured else {
                state = .unconfigured
                return
            }
            do {
                let url = try await extractURL()
                let coordinator = SummarizationCoordinator.make(settings: settings)
                let result = try await coordinator.summarize(url: url, language: settings.language)
                state = .success(result)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func extractURL() async throws -> URL {
        guard let context = extensionContext else { throw CoordinatorError.noURL }
        for item in (context.inputItems as? [NSExtensionItem]) ?? [] {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    let loaded = try await provider.loadItem(forTypeIdentifier: "public.url", options: nil)
                    if let url = loaded as? URL { return url }
                }
                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    let loaded = try await provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil)
                    if let text = loaded as? String,
                       let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        return url
                    }
                }
            }
        }
        throw CoordinatorError.noURL
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

// MARK: - Supporting views

private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("摘要失敗")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("重試", action: onRetry).buttonStyle(.bordered)
                Button("關閉", action: onDismiss).buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}

private struct UnconfiguredView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("請先開啟 NewsSummarizer App 進行設定")
                .font(.body)
                .multilineTextAlignment(.center)
            Button("關閉", action: onDismiss).buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
