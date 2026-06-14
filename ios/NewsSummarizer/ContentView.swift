import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ContentView: View {
    @StateObject private var settings = SettingsStore()
    @State private var urlText = ""
    @State private var hasClipboardURL = false
    @State private var state: SummarizeState = .idle

    enum SummarizeState {
        case idle, loading
        case success(SummaryResult)
        case error(String)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    TextField("貼上新聞網址", text: $urlText)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !urlText.isEmpty {
                        Button { urlText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                if hasClipboardURL && urlText.isEmpty {
                    Button {
                        urlText = UIPasteboard.general.string
                            ?? UIPasteboard.general.url?.absoluteString
                            ?? ""
                        hasClipboardURL = false
                    } label: {
                        Label("從剪貼簿貼上網址", systemImage: "doc.on.clipboard")
                            .font(.footnote)
                    }
                }

                Button(action: summarize) {
                    Label("摘要", systemImage: "text.quote")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

                switch state {
                case .idle:
                    Spacer()
                case .loading:
                    Spacer()
                    HStack { Spacer(); ProgressView("摘要中..."); Spacer() }
                    Spacer()
                case .success(let result):
                    ScrollView {
                        SummaryView(result: result, onDismiss: { state = .idle })
                    }
                case .error(let msg):
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("摘要失敗").font(.headline)
                        Text(msg).font(.caption).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重試", action: summarize).buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("摘要新聞")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { hideKeyboard() }
                }
            }
            .onTapGesture { hideKeyboard() }
            .task { detectClipboardURL() }
        }
    }

    private var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    private func detectClipboardURL() {
        UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { result in
            if case .success(let patterns) = result, patterns.contains(.probableWebURL) {
                DispatchQueue.main.async { hasClipboardURL = true }
            }
        }
    }

    private func summarize() {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespaces)) else {
            state = .error("無效的網址")
            return
        }
        state = .loading
        Task {
            do {
                let coordinator = SummarizationCoordinator.make(settings: settings)
                let result = try await coordinator.summarize(url: url, language: settings.language)
                state = .success(result)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
